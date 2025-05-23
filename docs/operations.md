# Minio Operations Guide

This guide covers day-to-day operational tasks for managing Minio deployments with the Genesis Kit.

## Table of Contents

- [Health Monitoring](#health-monitoring)
- [Backup and Recovery](#backup-and-recovery)
- [Scaling Operations](#scaling-operations)
- [Certificate Management](#certificate-management)
- [Access Key Rotation](#access-key-rotation)
- [Storage Management](#storage-management)
- [Performance Tuning](#performance-tuning)
- [Maintenance Operations](#maintenance-operations)
- [Disaster Recovery](#disaster-recovery)

## Health Monitoring

### Basic Health Checks

**Check deployment status:**
```bash
# Overall deployment health
bosh -d dev-minio vms --vitals

# Detailed instance information
bosh -d dev-minio instances --details
```

**Monitor Minio process:**
```bash
# Check if Minio is running
bosh -d dev-minio ssh minio/0 'sudo monit summary'

# View Minio logs
bosh -d dev-minio ssh minio/0 'tail -f /var/vcap/sys/log/minio/minio.log'
```

**Test S3 connectivity:**
```bash
# Quick connectivity test
genesis do dev -- s3 ls

# Create test object
echo "health check" | genesis do dev -- s3 stream /health-check-bucket/test.txt

# Retrieve test object
genesis do dev -- s3 cat /health-check-bucket/test.txt
```

### Automated Monitoring

**Set up monitoring endpoints:**
```bash
# Minio provides Prometheus metrics
curl -k https://minio.example.com/minio/prometheus/metrics

# Health endpoint
curl -k https://minio.example.com/minio/health/live
curl -k https://minio.example.com/minio/health/ready
```

**Example Prometheus scrape config:**
```yaml
- job_name: 'minio'
  scrape_interval: 30s
  static_configs:
  - targets: ['minio.example.com:443']
  scheme: https
  tls_config:
    insecure_skip_verify: true  # For self-signed certs
```

**Key metrics to monitor:**
- `minio_disk_usage_percent` - Disk utilization
- `minio_network_received_bytes_total` - Network traffic
- `minio_s3_requests_total` - Request counts
- `minio_inter_node_latency` - Node communication latency (distributed mode)

### Alerting Rules

**Critical alerts:**
```yaml
# Disk space critical
- alert: MinioDiskSpaceCritical
  expr: minio_disk_usage_percent > 90
  for: 5m
  
# Node down (distributed mode)
- alert: MinioNodeDown
  expr: up{job="minio"} == 0
  for: 1m

# High error rate
- alert: MinioHighErrorRate
  expr: rate(minio_s3_requests_errors_total[5m]) > 0.05
  for: 5m
```

## Backup and Recovery

### Data Backup Strategies

**1. S3 Sync Method:**
```bash
# Sync to another S3-compatible storage
genesis do dev -- s3 sync / s3://backup-destination/

# Sync specific bucket
genesis do dev -- s3 sync /production-data/ s3://backup-destination/production-data/
```

**2. Snapshot Method (Cloud Provider):**
```bash
# AWS EBS Snapshot example
aws ec2 create-snapshot --volume-id vol-xxxxx --description "Minio backup $(date +%Y%m%d)"

# GCP Persistent Disk Snapshot
gcloud compute disks snapshot minio-disk --zone=us-east1-b
```

**3. Streaming Backup:**
```bash
# Stream bucket to tar archive
genesis do dev -- s3 sync /important-bucket/ - | \
  tar czf minio-backup-$(date +%Y%m%d).tar.gz -

# Backup with metadata
genesis do dev -- s3 ls -r / > bucket-inventory.txt
```

### Recovery Procedures

**Restore from S3 sync:**
```bash
# Restore entire bucket
genesis do dev -- s3 sync s3://backup-source/bucket/ /bucket/

# Restore with specific date
genesis do dev -- s3 sync s3://backup-source/bucket/ /bucket/ \
  --if-modified-before "2024-01-01"
```

**Restore from snapshot:**
```bash
# Stop Minio
bosh -d dev-minio stop

# Restore disk from snapshot (cloud-specific)
# AWS example:
aws ec2 create-volume --snapshot-id snap-xxxxx

# Update BOSH with new disk
bosh -d dev-minio cck
# Select option to use new disk

# Start Minio
bosh -d dev-minio start
```

### Backup Automation

Create a backup script:
```bash
#!/bin/bash
# minio-backup.sh

DEPLOYMENT="prod-minio"
BACKUP_BUCKET="s3://backup-destination"
DATE=$(date +%Y%m%d-%H%M%S)

# Backup data
genesis do $DEPLOYMENT -- s3 sync / $BACKUP_BUCKET/minio-backup-$DATE/

# Backup metadata
genesis info $DEPLOYMENT > minio-metadata-$DATE.txt

# Clean old backups (keep 30 days)
genesis do $DEPLOYMENT -- s3 ls $BACKUP_BUCKET/ | \
  grep "minio-backup-" | \
  sort -r | \
  tail -n +31 | \
  xargs -I {} genesis do $DEPLOYMENT -- s3 rm -r $BACKUP_BUCKET/{}
```

## Scaling Operations

### Vertical Scaling (Bigger VMs)

**1. Update VM type:**
```yaml
# In your environment file
params:
  vm_type: xlarge  # Was: large
```

**2. Apply changes:**
```bash
# This will recreate VMs with new size
genesis deploy dev
```

### Horizontal Scaling (Distributed Mode)

**Adding nodes to existing distributed deployment:**

**WARNING:** Minio doesn't support dynamically adding nodes to an existing cluster. You must:

1. **Plan capacity from the start**
2. **Migrate data if scaling is needed**

**Migration approach:**
```bash
# 1. Set up new cluster with more nodes
genesis new prod-scaled
# Configure with more nodes

# 2. Deploy new cluster
genesis deploy prod-scaled

# 3. Migrate data
genesis do prod -- s3 mirror / $(genesis do prod-scaled -- s3 endpoint)/

# 4. Update applications to use new endpoint
# 5. Decommission old cluster
```

### Storage Scaling

**Increase disk size:**
```yaml
# Update cloud config
disk_types:
- name: minio
  disk_size: 20480  # Was: 10240
```

**Apply changes:**
```bash
# Update cloud config
bosh update-cloud-config cloud-config.yml

# Recreate VMs with larger disks
bosh -d dev-minio recreate
```

**Note:** Data is preserved during disk resize operations.

## Certificate Management

### Certificate Renewal

**For self-signed certificates:**
```bash
# Force regeneration
genesis deploy dev --recreate

# Certificates are automatically regenerated
```

**For provided certificates:**
```bash
# 1. Obtain new certificate
# 2. Update in Vault
safe set secret/dev/minio/ssl/server \
  certificate@new-cert.pem \
  key@new-key.pem

# 3. Deploy to apply
genesis deploy dev

# 4. Verify new certificate
echo | openssl s_client -connect minio.example.com:443 2>/dev/null | \
  openssl x509 -noout -dates
```

### Certificate Monitoring

**Check expiration:**
```bash
# From Vault
genesis do dev vault get ssl/server:certificate | \
  openssl x509 -noout -enddate

# From running service
echo | openssl s_client -connect minio.example.com:443 2>/dev/null | \
  openssl x509 -noout -enddate
```

**Automated monitoring script:**
```bash
#!/bin/bash
# check-cert-expiry.sh

ENDPOINT="minio.example.com:443"
DAYS_WARNING=30

expiry=$(echo | openssl s_client -connect $ENDPOINT 2>/dev/null | \
  openssl x509 -noout -enddate | cut -d= -f2)

expiry_epoch=$(date -d "$expiry" +%s)
current_epoch=$(date +%s)
days_left=$(( ($expiry_epoch - $current_epoch) / 86400 ))

if [ $days_left -lt $DAYS_WARNING ]; then
  echo "WARNING: Certificate expires in $days_left days"
  exit 1
fi

echo "Certificate valid for $days_left more days"
```

## Access Key Rotation

### Manual Rotation

**1. Generate new credentials:**
```bash
# Generate random access key and secret
ACCESS_KEY=$(openssl rand -hex 20 | tr '[:lower:]' '[:upper:]')
SECRET_KEY=$(openssl rand -base64 32)

# Store in Vault
safe set secret/dev/minio/access_token \
  accesskey=$ACCESS_KEY \
  secretkey=$SECRET_KEY
```

**2. Deploy with new credentials:**
```bash
genesis deploy dev
```

**3. Update applications with new credentials**

### Automated Rotation

Create rotation script:
```bash
#!/bin/bash
# rotate-minio-creds.sh

DEPLOYMENT=$1
VAULT_PATH="secret/$DEPLOYMENT/minio/access_token"

# Generate new credentials
ACCESS_KEY=$(openssl rand -hex 20 | tr '[:lower:]' '[:upper:]')
SECRET_KEY=$(openssl rand -base64 32)

# Backup old credentials
safe get $VAULT_PATH > backup-creds-$(date +%Y%m%d).txt

# Set new credentials
safe set $VAULT_PATH \
  accesskey=$ACCESS_KEY \
  secretkey=$SECRET_KEY

# Deploy
genesis deploy $DEPLOYMENT

echo "New credentials:"
echo "Access Key: $ACCESS_KEY"
echo "Secret Key: $SECRET_KEY"
```

## Storage Management

### Disk Usage Monitoring

**Check current usage:**
```bash
# All nodes
for i in $(seq 0 $(($(genesis do dev -- s3 admin info | grep -c minio) - 1))); do
  echo "=== Node minio/$i ==="
  bosh -d dev-minio ssh minio/$i 'df -h /var/vcap/store'
done

# Summary via Minio
genesis do dev -- s3 admin info
```

### Data Lifecycle Management

**Implement retention policies:**
```bash
# Delete objects older than 90 days
genesis do dev -- s3 ls -r /archive-bucket/ | \
  awk '{if ($1 < "'$(date -d '90 days ago' '+%Y-%m-%d')'") print $4}' | \
  xargs -I {} genesis do dev -- s3 rm /archive-bucket/{}
```

**Bucket quota management:**
```bash
# Set bucket quota (not directly supported, implement via monitoring)
# Monitor bucket size
genesis do dev -- s3 du /limited-bucket/

# Alert when approaching limit
BUCKET_SIZE=$(genesis do dev -- s3 du /limited-bucket/ | awk '{print $1}')
LIMIT=$((100 * 1024 * 1024 * 1024)) # 100GB in bytes

if [ $BUCKET_SIZE -gt $LIMIT ]; then
  echo "ALERT: Bucket size exceeded limit"
fi
```

### Healing Operations

**For distributed deployments:**
```bash
# Check for data inconsistencies
genesis do dev -- s3 admin heal --dry-run /

# Perform healing
genesis do dev -- s3 admin heal /

# Monitor healing progress
genesis do dev -- s3 admin heal / --status
```

## Performance Tuning

### Network Optimization

**1. Verify network performance:**
```bash
# Test between nodes (distributed mode)
bosh -d dev-minio ssh minio/0
iperf3 -s

# From another node
bosh -d dev-minio ssh minio/1
iperf3 -c <minio/0-ip>
```

**2. Optimize network settings:**
```yaml
# In cloud config, ensure proper network type
networks:
- name: minio
  cloud_properties:
    network: 10gbit-network  # Cloud-specific
```

### Disk Performance

**Test disk performance:**
```bash
# Sequential write test
bosh -d dev-minio ssh minio/0
dd if=/dev/zero of=/var/vcap/store/test bs=1G count=1 oflag=direct

# Random I/O test
fio --name=randrw --ioengine=libaio --iodepth=1 --rw=randrw \
    --bs=4k --direct=1 --size=1G --numjobs=4 --runtime=60 \
    --filename=/var/vcap/store/test
```

### Minio Configuration Tuning

Currently, the Genesis Kit doesn't expose Minio tuning parameters directly. For advanced tuning, you would need to modify the kit.

## Maintenance Operations

### Rolling Updates

**For distributed deployments:**
```bash
# Update one node at a time
bosh -d dev-minio deploy --max-in-flight=1

# Monitor during update
watch bosh -d dev-minio vms
```

### VM Recreation

**Recreate specific instance:**
```bash
# Recreate single node
bosh -d dev-minio recreate minio/0

# Recreate all nodes
bosh -d dev-minio recreate
```

### Stemcell Updates

**1. Upload new stemcell:**
```bash
bosh upload-stemcell https://bosh.io/d/stemcells/bosh-aws-xen-hvm-ubuntu-bionic-go_agent
```

**2. Update environment file:**
```yaml
params:
  stemcell_version: "621.125"  # Specific version
```

**3. Deploy:**
```bash
genesis deploy dev
```

## Disaster Recovery

### Complete Recovery Procedure

**Scenario: Complete data center loss**

**1. Prepare new infrastructure:**
```bash
# Set up new BOSH director
# Configure cloud config
# Set up Vault
```

**2. Restore Vault data:**
```bash
# Restore from Vault backup
# Or manually recreate certificates and credentials
```

**3. Deploy fresh Minio:**
```bash
genesis new prod-dr
# Copy configuration from backup
genesis deploy prod-dr
```

**4. Restore data:**
```bash
# From backup location
genesis do prod-dr -- s3 sync s3://backup-location/ /
```

**5. Verify and test:**
```bash
# Run smoke tests
bosh -d prod-dr-minio run-errand smoke-tests

# Verify critical data
genesis do prod-dr -- s3 ls /critical-bucket/
```

### Partial Failure Recovery

**Single node failure (distributed mode):**
```bash
# Minio continues operating
# Fix underlying infrastructure issue
# Recreate failed node
bosh -d dev-minio recreate minio/2

# Healing happens automatically
# Monitor healing progress
genesis do dev -- s3 admin heal / --status
```

**Corrupted data recovery:**
```bash
# For distributed mode, healing fixes corruption
genesis do dev -- s3 admin heal /

# For single node, restore from backup
genesis do dev -- s3 sync s3://backup/bucket/ /bucket/
```

## Operational Best Practices

1. **Regular Backups**
   - Automate daily backups
   - Test restoration procedures monthly
   - Keep backups in different region/provider

2. **Monitoring**
   - Set up comprehensive monitoring
   - Alert on disk space, errors, performance
   - Track trends for capacity planning

3. **Security**
   - Rotate credentials regularly
   - Monitor access logs
   - Keep certificates up to date

4. **Documentation**
   - Document your specific configuration
   - Maintain runbooks for common procedures
   - Keep contact information current

5. **Testing**
   - Regular disaster recovery drills
   - Test scaling procedures in non-production
   - Verify backup integrity

6. **Change Management**
   - Plan maintenance windows
   - Test changes in non-production first
   - Have rollback procedures ready