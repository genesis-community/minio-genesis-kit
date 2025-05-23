# Minio Security Best Practices

This guide covers security considerations and best practices for deploying and operating Minio with the Genesis Kit.

## Table of Contents

- [Network Security](#network-security)
- [SSL/TLS Configuration](#ssltls-configuration)
- [Access Control](#access-control)
- [Secrets Management](#secrets-management)
- [Audit and Compliance](#audit-and-compliance)
- [Data Protection](#data-protection)
- [Security Hardening](#security-hardening)
- [Incident Response](#incident-response)

## Network Security

### Network Isolation

**1. Use dedicated networks:**
```yaml
# Cloud config
networks:
- name: minio
  type: manual
  subnets:
  - range: 10.0.100.0/24  # Isolated subnet
    static: [10.0.100.10-10.0.100.50]
    cloud_properties:
      security_groups: [minio-sg]  # Restricted security group
```

**2. Security group configuration (AWS example):**
```bash
# Minio access (restrict source IPs)
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxxx \
  --protocol tcp \
  --port 443 \
  --source-group sg-app-servers  # Only from application servers

# Internal communication (distributed mode)
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxxx \
  --protocol tcp \
  --port 9000 \
  --source-group sg-xxxxxx  # Only from same security group
```

### Firewall Rules

**Minimal required ports:**
- **443 (HTTPS)**: Client access (configurable via `port` parameter)
- **9000**: Internal node communication (distributed mode only)
- **22**: SSH for BOSH management (restrict to BOSH Director)

**iptables example:**
```bash
# Allow HTTPS from specific subnet
iptables -A INPUT -p tcp --dport 443 -s 10.0.0.0/16 -j ACCEPT

# Allow internal Minio communication
iptables -A INPUT -p tcp --dport 9000 -s 10.0.100.0/24 -j ACCEPT

# Default deny
iptables -P INPUT DROP
```

### Load Balancer Security

**When using a load balancer:**
1. Terminate TLS at Minio (end-to-end encryption)
2. Use health checks that don't expose sensitive data
3. Implement rate limiting
4. Enable access logs

**Example HAProxy configuration:**
```
frontend minio_frontend
    bind *:443 ssl crt /etc/ssl/certs/minio.pem
    mode http
    option httplog
    rate-limit sessions 100
    default_backend minio_backend

backend minio_backend
    mode http
    balance leastconn
    option httpchk GET /minio/health/live
    server minio1 10.0.100.10:443 check ssl verify none
    server minio2 10.0.100.11:443 check ssl verify none
```

## SSL/TLS Configuration

### Certificate Security

**1. Use strong certificates:**
- Minimum RSA 2048-bit (4096-bit recommended)
- Use SHA-256 signature algorithm
- Include all required SANs

**2. Certificate validation:**
```bash
# Check certificate strength
genesis do dev vault get ssl/server:certificate | \
  openssl x509 -noout -text | grep "Public-Key"

# Verify certificate chain
genesis do dev vault get ssl/server:certificate | \
  openssl x509 -noout -text
```

### TLS Configuration

The Genesis Kit configures Minio with secure TLS settings:
- TLS 1.2 minimum
- Strong cipher suites only
- Perfect Forward Secrecy (PFS)

**Verify TLS configuration:**
```bash
# Check supported TLS versions
nmap --script ssl-enum-ciphers -p 443 minio.example.com

# Test with SSL Labs (for public endpoints)
# https://www.ssllabs.com/ssltest/
```

### Certificate Pinning

For high-security environments, implement certificate pinning in clients:

```python
# Python example
import ssl
import hashlib

def get_cert_fingerprint(hostname, port=443):
    cert = ssl.get_server_certificate((hostname, port))
    der_cert = ssl.PEM_cert_to_DER_cert(cert)
    return hashlib.sha256(der_cert).hexdigest()

# Pin the certificate
expected_fingerprint = "aa:bb:cc:dd:..."
actual_fingerprint = get_cert_fingerprint("minio.example.com")

if actual_fingerprint != expected_fingerprint:
    raise Exception("Certificate fingerprint mismatch!")
```

## Access Control

### Credential Management

**1. Strong access keys:**
```bash
# Generate cryptographically secure credentials
ACCESS_KEY=$(openssl rand -hex 20 | tr '[:lower:]' '[:upper:]')
SECRET_KEY=$(openssl rand -base64 40)
```

**2. Regular rotation:**
```bash
# Implement automated rotation
cat > /etc/cron.d/minio-rotate <<EOF
0 0 1 * * root /usr/local/bin/rotate-minio-creds.sh prod
EOF
```

**3. Separate credentials per application:**
Instead of sharing one set of credentials, consider:
- Deploy multiple Minio instances for different applications
- Use a proxy layer that implements additional access control

### Bucket Policies

While the Genesis Kit doesn't directly support bucket policies, you can implement access control at the application level:

```python
# Application-level access control
class MinioAccessControl:
    def __init__(self, minio_client):
        self.client = minio_client
        self.allowed_buckets = {
            'app1': ['bucket-app1', 'shared-bucket'],
            'app2': ['bucket-app2', 'shared-bucket'],
        }
    
    def get_object(self, app_id, bucket, object_name):
        if bucket not in self.allowed_buckets.get(app_id, []):
            raise PermissionError(f"App {app_id} cannot access {bucket}")
        return self.client.get_object(bucket, object_name)
```

### Network-Level Access Control

Implement IP-based restrictions:

```yaml
# In your infrastructure
resource "aws_security_group_rule" "minio_access" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["10.0.0.0/8"]  # Internal networks only
  security_group_id = aws_security_group.minio.id
}
```

## Secrets Management

### Vault Integration

The Genesis Kit stores all secrets in Vault. Follow these best practices:

**1. Vault access control:**
```bash
# Create specific policies for Minio
vault policy write minio-policy - <<EOF
path "secret/data/prod/minio/*" {
  capabilities = ["read"]
}
EOF

# Create token with limited access
vault token create -policy=minio-policy -ttl=1h
```

**2. Audit Vault access:**
```bash
# Enable audit logging
vault audit enable file file_path=/var/log/vault-audit.log

# Monitor access to Minio secrets
grep "minio" /var/log/vault-audit.log
```

### Credential Storage

**Never store credentials in:**
- Source code
- Configuration files
- Environment files
- Container images

**Always store credentials in:**
- Vault (preferred)
- Hardware Security Modules (HSM)
- Cloud provider secret managers (as backup)

### Secret Rotation Procedures

```bash
#!/bin/bash
# secure-rotation.sh

set -euo pipefail

DEPLOYMENT=$1
OLD_ACCESS_KEY=$(safe get secret/$DEPLOYMENT/minio/access_token:accesskey)

# Generate new credentials
NEW_ACCESS_KEY=$(openssl rand -hex 20 | tr '[:lower:]' '[:upper:]')
NEW_SECRET_KEY=$(openssl rand -base64 40)

# Update in Vault
safe set secret/$DEPLOYMENT/minio/access_token \
  accesskey=$NEW_ACCESS_KEY \
  secretkey=$NEW_SECRET_KEY \
  old_accesskey=$OLD_ACCESS_KEY \
  rotation_date=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Deploy with new credentials
genesis deploy $DEPLOYMENT

# Notify applications of rotation
# ... application-specific notification ...

# After grace period, remove old credentials
sleep 3600  # 1 hour grace period
safe set secret/$DEPLOYMENT/minio/access_token \
  accesskey=$NEW_ACCESS_KEY \
  secretkey=$NEW_SECRET_KEY \
  rotation_date=$(date -u +%Y-%m-%dT%H:%M:%SZ)
```

## Audit and Compliance

### Access Logging

**Enable comprehensive logging:**
```bash
# View Minio access logs
bosh -d prod-minio ssh minio/0
tail -f /var/vcap/sys/log/minio/minio.log | grep -E "GET|PUT|DELETE"
```

**Parse logs for audit trails:**
```python
# parse-minio-logs.py
import re
import json
from datetime import datetime

log_pattern = re.compile(
    r'(?P<timestamp>[\d\-T:\.Z]+).*'
    r'(?P<method>GET|PUT|DELETE|HEAD|POST)\s+'
    r'(?P<path>/[^\s]*)\s+'
    r'(?P<status>\d+)\s+'
    r'(?P<ip>\d+\.\d+\.\d+\.\d+)'
)

def parse_log_line(line):
    match = log_pattern.search(line)
    if match:
        return {
            'timestamp': match.group('timestamp'),
            'method': match.group('method'),
            'path': match.group('path'),
            'status': match.group('status'),
            'source_ip': match.group('ip')
        }
    return None

# Process logs
with open('minio.log', 'r') as f:
    for line in f:
        entry = parse_log_line(line)
        if entry:
            print(json.dumps(entry))
```

### Compliance Considerations

**GDPR Compliance:**
1. Implement data retention policies
2. Provide data deletion capabilities
3. Maintain audit logs of access
4. Encrypt data at rest (cloud provider level)

**HIPAA Compliance:**
1. Use end-to-end encryption
2. Implement access logging
3. Regular security assessments
4. Business Associate Agreements (BAAs) with cloud providers

**PCI DSS Compliance:**
1. Network segmentation
2. Strong access controls
3. Regular security updates
4. Encryption in transit and at rest

### Security Scanning

**Regular vulnerability scanning:**
```bash
# Scan for open ports
nmap -sV -p- minio.example.com

# Check for SSL/TLS vulnerabilities
testssl.sh minio.example.com

# Scan for web vulnerabilities
nikto -h https://minio.example.com
```

## Data Protection

### Encryption at Rest

While Minio Genesis Kit doesn't directly implement encryption at rest, use cloud provider features:

**AWS:**
```yaml
# In cloud config
disk_types:
- name: minio
  disk_size: 10240
  cloud_properties:
    type: gp3
    encrypted: true
    kms_key_id: arn:aws:kms:region:account:key/xxx
```

**GCP:**
```yaml
disk_types:
- name: minio
  disk_size: 10240
  cloud_properties:
    type: pd-ssd
    encryption_key: projects/PROJECT/locations/LOCATION/keyRings/RING/cryptoKeys/KEY
```

### Encryption in Transit

Always enforced by the Genesis Kit through HTTPS.

**Verify encryption:**
```bash
# Check TLS connection
openssl s_client -connect minio.example.com:443 -tls1_2

# Verify cipher suite
openssl s_client -connect minio.example.com:443 2>/dev/null | grep "Cipher"
```

### Data Classification

Implement bucket naming conventions:
```
/public-data/        # Public information
/internal-data/      # Internal use only
/confidential-data/  # Sensitive information
/restricted-data/    # Highly sensitive
```

## Security Hardening

### OS-Level Hardening

The Genesis Kit uses stemcells with basic hardening. Additional steps:

```bash
# Apply via BOSH SSH
bosh -d prod-minio ssh minio/0

# Disable unnecessary services
sudo systemctl disable bluetooth
sudo systemctl disable cups

# Kernel hardening
echo "kernel.randomize_va_space=2" | sudo tee -a /etc/sysctl.conf
echo "kernel.exec-shield=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# File system hardening
echo "tmpfs /tmp tmpfs defaults,noexec,nosuid 0 0" | sudo tee -a /etc/fstab
```

### Application Security Headers

When using Minio behind a reverse proxy, add security headers:

```nginx
# Nginx example
location / {
    proxy_pass https://minio-backend;
    
    # Security headers
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header Content-Security-Policy "default-src 'self'" always;
}
```

### Resource Limits

Prevent DoS attacks:

```yaml
# In cloud provider config
vm_types:
- name: minio-limited
  cloud_properties:
    instance_type: t3.medium
    # AWS example - limit network performance
    network_performance: moderate
```

## Incident Response

### Preparation

**1. Document contacts:**
```yaml
# incident-contacts.yml
security_team:
  email: security@example.com
  phone: +1-555-0123
  escalation: security-manager@example.com

operations_team:
  email: ops@example.com
  pager: +1-555-0456
```

**2. Prepare runbooks:**
- Credential compromise response
- Data breach procedures
- DDoS mitigation steps
- Service degradation response

### Detection

**Set up alerts for:**
```bash
# Unusual access patterns
grep "403\|401" /var/vcap/sys/log/minio/minio.log | wc -l

# Failed authentication attempts
grep "Invalid access key" /var/vcap/sys/log/minio/minio.log

# Unusual data transfer
# (Monitor network traffic volume)
```

### Response Procedures

**Credential compromise:**
```bash
#!/bin/bash
# incident-response.sh

DEPLOYMENT=$1
INCIDENT_ID=$(date +%Y%m%d-%H%M%S)

echo "=== Incident Response Started: $INCIDENT_ID ==="

# 1. Rotate credentials immediately
./secure-rotation.sh $DEPLOYMENT

# 2. Capture current state
genesis info $DEPLOYMENT > incident-$INCIDENT_ID-info.txt
bosh -d $DEPLOYMENT-minio logs --dir=incident-$INCIDENT_ID-logs

# 3. Check for unauthorized access
grep -E "GET|PUT|DELETE" incident-$INCIDENT_ID-logs/*/minio/minio.log > \
  incident-$INCIDENT_ID-access.log

# 4. Notify stakeholders
mail -s "Security Incident: Minio $DEPLOYMENT" security@example.com < \
  incident-$INCIDENT_ID-info.txt

echo "=== Incident Response Completed: $INCIDENT_ID ==="
```

### Post-Incident

**1. Analysis:**
- Review all access logs
- Identify attack vectors
- Assess data exposure

**2. Remediation:**
- Patch vulnerabilities
- Update security policies
- Improve monitoring

**3. Documentation:**
- Incident report
- Lessons learned
- Process improvements

## Security Checklist

Use this checklist for security reviews:

- [ ] **Network Security**
  - [ ] Minio on isolated network
  - [ ] Firewall rules configured
  - [ ] Security groups restricted
  - [ ] No public IP addresses

- [ ] **SSL/TLS**
  - [ ] Valid certificates installed
  - [ ] Strong cipher suites only
  - [ ] Certificate expiry monitoring
  - [ ] TLS 1.2 minimum

- [ ] **Access Control**
  - [ ] Strong credentials generated
  - [ ] Regular rotation scheduled
  - [ ] Access logs enabled
  - [ ] Minimal access principles

- [ ] **Secrets Management**
  - [ ] All secrets in Vault
  - [ ] Vault access restricted
  - [ ] Audit logging enabled
  - [ ] No hardcoded secrets

- [ ] **Monitoring**
  - [ ] Access logs collected
  - [ ] Security alerts configured
  - [ ] Anomaly detection active
  - [ ] Regular reviews scheduled

- [ ] **Compliance**
  - [ ] Data classification implemented
  - [ ] Retention policies defined
  - [ ] Audit trails maintained
  - [ ] Compliance scans scheduled

- [ ] **Incident Response**
  - [ ] Response plan documented
  - [ ] Contact list current
  - [ ] Runbooks prepared
  - [ ] Regular drills conducted