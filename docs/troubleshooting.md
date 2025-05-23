# Minio Genesis Kit Troubleshooting Guide

This guide helps you diagnose and resolve common issues with Minio deployments using the Genesis Kit.

## Table of Contents

- [Deployment Issues](#deployment-issues)
- [Certificate Problems](#certificate-problems)
- [Network and Connectivity](#network-and-connectivity)
- [Storage Issues](#storage-issues)
- [Performance Problems](#performance-problems)
- [Access and Authentication](#access-and-authentication)
- [Distributed Mode Issues](#distributed-mode-issues)
- [Debugging Tools](#debugging-tools)

## Deployment Issues

### Deployment Fails with "No Valid Stemcell"

**Symptoms:**
```
Error: Failed to find stemcells:
  - Stemcell 'ubuntu-bionic/latest' doesn't exist
```

**Solutions:**
1. Upload the required stemcell:
   ```bash
   bosh upload-stemcell --sha1 $SHA1 \
     https://bosh.io/d/stemcells/bosh-aws-xen-hvm-ubuntu-bionic-go_agent
   ```

2. Check available stemcells:
   ```bash
   bosh stemcells
   ```

3. Use a specific version in your environment file:
   ```yaml
   params:
     stemcell_version: "621.125"
   ```

### Cloud Config Missing Required Resources

**Symptoms:**
```
Error: Can't find disk type 'minio'
Error: Can't find network 'minio'
```

**Solutions:**
1. Verify cloud config:
   ```bash
   bosh cloud-config
   ```

2. Update cloud config with required resources:
   ```yaml
   disk_types:
   - name: minio
     disk_size: 10240
   
   networks:
   - name: minio
     type: manual
     subnets:
     - static: [10.0.1.10-10.0.1.20]
   ```

3. Apply the cloud config:
   ```bash
   bosh update-cloud-config cloud-config.yml
   ```

### Genesis Version Too Old

**Symptoms:**
```
Error: This kit requires Genesis v2.7.10 or later
```

**Solution:**
Update Genesis to the latest version:
```bash
# macOS with Homebrew
brew upgrade genesis

# Linux
curl -fsSL https://github.com/genesis-community/genesis/releases/latest/download/genesis-linux-amd64 -o genesis
chmod +x genesis
sudo mv genesis /usr/local/bin/
```

## Certificate Problems

### SSL Certificate Verification Failed

**Symptoms:**
- Browser shows "Your connection is not private"
- S3 clients report certificate errors
- `curl` fails with SSL error

**Solutions for Self-Signed Certificates:**
1. For browsers, add security exception
2. For S3 CLI, the kit automatically sets `S3_INSECURE=1`
3. For applications, configure to skip verification (development only):
   ```python
   # Python boto3 example
   s3 = boto3.client('s3',
       endpoint_url='https://minio.example.com',
       verify=False)  # Development only!
   ```

**Solutions for Production:**
1. Use the `provided-cert` feature with real certificates
2. Store certificates in Vault before deployment:
   ```bash
   safe set secret/dev/minio/ssl/server \
     certificate@cert.pem \
     key@key.pem
   ```

### Certificate Domain Mismatch

**Symptoms:**
```
x509: certificate is valid for minio.old-domain.com, not minio.new-domain.com
```

**Solution:**
1. Update `external_domain` parameter
2. Redeploy to regenerate certificates:
   ```bash
   genesis deploy dev --recreate
   ```

### Certificate Expired

**Symptoms:**
```
x509: certificate has expired or is not yet valid
```

**Solutions:**
1. For self-signed: Redeploy to regenerate
2. For provided: Update certificates in Vault:
   ```bash
   safe set secret/dev/minio/ssl/server \
     certificate@new-cert.pem \
     key@new-key.pem
   genesis deploy dev
   ```

## Network and Connectivity

### Cannot Access Minio Web Console

**Symptoms:**
- Browser timeout when accessing Minio URL
- `genesis do dev -- visit` opens browser but page doesn't load

**Diagnostics:**
```bash
# Check if Minio is running
bosh -d dev-minio vms

# Check network connectivity
curl -k https://minio.example.com

# Check DNS resolution
nslookup minio.example.com
```

**Solutions:**
1. Verify DNS points to correct IP:
   ```bash
   bosh -d dev-minio vms --column=Instance --column=IPs
   ```

2. Check firewall rules allow port 443 (or custom port)

3. Verify load balancer configuration if using one

4. Check security groups in cloud provider

### Static IP Allocation Failures

**Symptoms:**
```
Error: Failed to reserve IP '10.0.1.10' for instance 'minio/0': already in use
```

**Solutions:**
1. Check IP usage:
   ```bash
   bosh -d dev-minio ips
   ```

2. Expand static IP range in cloud config

3. Clean up orphaned deployments:
   ```bash
   bosh deployments
   bosh -d orphaned-deployment delete-deployment
   ```

## Storage Issues

### Disk Full Errors

**Symptoms:**
- Minio returns "Storage Backend Error"
- Logs show "no space left on device"
- Write operations fail

**Diagnostics:**
```bash
# Check disk usage
bosh -d dev-minio ssh minio/0 'df -h /var/vcap/store'

# Check Minio logs
bosh -d dev-minio ssh minio/0 'tail -f /var/vcap/sys/log/minio/minio.log'
```

**Solutions:**
1. Increase disk size in cloud config
2. Recreate VMs with larger disks:
   ```bash
   bosh -d dev-minio recreate
   ```
3. Clean up old data if appropriate

### Persistent Disk Attachment Issues

**Symptoms:**
```
Error: Persistent disk is not attached to instance minio/0
```

**Solutions:**
1. Check persistent disk configuration:
   ```bash
   bosh -d dev-minio instances --details
   ```

2. Reattach disk:
   ```bash
   bosh -d dev-minio cck
   # Choose option to reattach disk
   ```

## Performance Problems

### Slow Upload/Download Speeds

**Diagnostics:**
```bash
# Test network bandwidth
bosh -d dev-minio ssh minio/0
iperf3 -s  # On one node
iperf3 -c <other-node-ip>  # On another

# Check system resources
bosh -d dev-minio ssh minio/0 'top'
```

**Solutions:**
1. Check VM sizing - upgrade to larger VM type
2. Verify network bandwidth between nodes
3. Check disk IOPS limits
4. For distributed mode, ensure all nodes are healthy

### High CPU Usage

**Symptoms:**
- Minio process consuming 100% CPU
- Slow response times

**Solutions:**
1. Check for ongoing healing operations:
   ```bash
   genesis do dev -- s3 admin info
   ```

2. Increase VM resources:
   ```yaml
   params:
     vm_type: xlarge
   ```

3. Review access patterns - consider caching layer

## Access and Authentication

### Cannot Login to Web Console

**Symptoms:**
- "Invalid credentials" error
- Access denied errors

**Solutions:**
1. Retrieve correct credentials:
   ```bash
   genesis info dev
   # Or directly from Vault:
   safe get secret/dev/minio/access_token
   ```

2. For macOS, use the visit addon:
   ```bash
   genesis do dev -- visit
   ```

### S3 Access Key Not Working

**Symptoms:**
```
The AWS Access Key Id you provided does not exist in our records
```

**Solutions:**
1. Verify credentials:
   ```bash
   genesis do dev -- s3 ls
   # This sets up environment correctly
   ```

2. Check credential format - no extra spaces or newlines

3. Ensure using correct endpoint URL

## Distributed Mode Issues

### Node Count Validation Errors

**Symptoms:**
```
Error: num_minio_nodes must be between 4 and 32, and even
```

**Solution:**
Correct the node count:
```yaml
params:
  num_minio_nodes: 8  # Must be 4-32, even number
```

### Nodes Not Forming Cluster

**Symptoms:**
- Nodes running but not communicating
- Data not replicated across nodes

**Diagnostics:**
```bash
# Check all nodes are running
bosh -d dev-minio vms

# Check Minio cluster status
genesis do dev -- s3 admin info
```

**Solutions:**
1. Ensure all nodes can communicate on port 9000
2. Check internal DNS resolution between nodes
3. Verify all nodes started with same configuration
4. Recreate deployment if nodes are out of sync:
   ```bash
   genesis deploy dev --recreate
   ```

### Uneven Data Distribution

**Symptoms:**
- Some nodes have significantly more data
- Performance degradation on specific nodes

**Solutions:**
1. Check disk usage across nodes:
   ```bash
   for i in {0..3}; do
     echo "Node minio/$i:"
     bosh -d dev-minio ssh minio/$i 'df -h /var/vcap/store'
   done
   ```

2. Run healing operation:
   ```bash
   genesis do dev -- s3 admin heal -r /
   ```

## Debugging Tools

### Enable Debug Logging

Add to your environment file:
```yaml
params:
  minio_debug: true
```

Then redeploy and check logs:
```bash
genesis deploy dev
bosh -d dev-minio ssh minio/0
tail -f /var/vcap/sys/log/minio/minio.log
```

### Check Component Health

```bash
# Overall deployment health
bosh -d dev-minio instances --vitals

# Individual instance health
bosh -d dev-minio ssh minio/0 'sudo monit summary'

# Minio process details
bosh -d dev-minio ssh minio/0 'ps aux | grep minio'
```

### Access Minio Metrics

```bash
# If metrics are enabled
curl -k https://minio.example.com/minio/prometheus/metrics
```

### Common Log Locations

- Minio logs: `/var/vcap/sys/log/minio/minio.log`
- System logs: `/var/log/messages` or `/var/log/syslog`
- BOSH agent logs: `/var/vcap/bosh/log/`

### Emergency Recovery

If Minio is completely broken:

1. **Backup data** (if possible):
   ```bash
   bosh -d dev-minio ssh minio/0
   tar -czf /tmp/minio-backup.tar.gz /var/vcap/store/minio/
   ```

2. **Save state**:
   ```bash
   genesis info dev > minio-credentials.txt
   bosh -d dev-minio manifest > minio-manifest.yml
   ```

3. **Recreate deployment**:
   ```bash
   bosh -d dev-minio delete-deployment
   genesis deploy dev
   ```

4. **Restore data** (if needed) - requires careful planning

## Getting Help

If you're still experiencing issues:

1. Collect diagnostic information:
   ```bash
   genesis info dev > diagnostics.txt
   bosh -d dev-minio instances --details >> diagnostics.txt
   bosh -d dev-minio logs >> diagnostics.txt
   ```

2. Check the Genesis community resources:
   - [Genesis Documentation](https://genesis.community)
   - [GitHub Issues](https://github.com/genesis-community/minio-genesis-kit/issues)

3. Provide:
   - Genesis version (`genesis version`)
   - Kit version (from environment file)
   - Error messages and logs
   - Steps to reproduce the issue