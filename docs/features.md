# Minio Genesis Kit Features

This document provides detailed information about the features available in the Minio Genesis Kit.

## Table of Contents

- [SSL Certificate Management](#ssl-certificate-management)
  - [Self-Signed Certificates](#self-signed-certificates)
  - [Provided Certificates](#provided-certificates)
- [Distributed Mode](#distributed-mode)
  - [Architecture](#architecture)
  - [Benefits](#benefits)
  - [Configuration](#configuration)
  - [Best Practices](#best-practices)
- [Smoke Tests](#smoke-tests)
- [Addons](#addons)
  - [Visit/Open Addon](#visitopen-addon)
  - [S3 CLI Addon](#s3-cli-addon)
  - [Download S3 Addon](#download-s3-addon)

## SSL Certificate Management

Minio in this Genesis Kit always runs with HTTPS enabled. You have two options for SSL certificates:

### Self-Signed Certificates

The `self-signed-certs` feature is perfect for development and testing environments where you don't need publicly trusted certificates.

**How it works:**
1. Genesis generates a Certificate Authority (CA)
2. Creates a server certificate signed by this CA
3. Stores everything securely in Vault
4. Configures Minio to use these certificates

**Configuration:**
```yaml
kit:
  features:
    - self-signed-certs
```

**Generated Certificates:**
- **CA Certificate**: Used to sign the server certificate
  - Vault path: `$GENESIS_VAULT_PREFIX/ssl/ca:certificate`
  - Valid for: 10 years
  - Can be distributed to clients to trust the server

- **Server Certificate**: Used by Minio for HTTPS
  - Vault path: `$GENESIS_VAULT_PREFIX/ssl/server:certificate`
  - Valid for: 1 year
  - Includes SANs for:
    - External domain (from `params.external_domain`)
    - Internal BOSH DNS names
    - IP addresses of instances

**Client Configuration:**
When using self-signed certificates, clients need to either:
1. Skip certificate verification (development only)
2. Trust the CA certificate

Example for trusting the CA:
```bash
# Extract CA certificate
genesis do dev vault get ssl/ca:certificate > minio-ca.crt

# Add to system trust store (macOS)
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain minio-ca.crt

# Add to system trust store (Ubuntu)
sudo cp minio-ca.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

### Provided Certificates

The `provided-cert` feature allows you to use your own SSL certificates, typically from a public CA like Let's Encrypt or a corporate CA.

**Prerequisites:**
Before deployment, store your certificates in Vault:
```bash
# Store certificate and key
safe set secret/dev/minio/ssl/server \
  certificate@server.crt \
  key@server.key
```

**Configuration:**
```yaml
kit:
  features:
    - provided-cert
```

**Certificate Requirements:**
- Must be valid for your `external_domain`
- Private key must be unencrypted
- Certificate chain should be complete
- RSA 2048-bit or stronger recommended

**Certificate Rotation:**
To update certificates:
1. Store new certificates in Vault
2. Redeploy Minio:
   ```bash
   genesis deploy dev
   ```
3. No downtime required - Minio reloads certificates

## Distributed Mode

Distributed mode transforms Minio from a single server into a highly available, scalable storage cluster.

### Architecture

In distributed mode, Minio uses erasure coding to spread data across multiple nodes:

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Minio Node │     │  Minio Node │     │  Minio Node │     │  Minio Node │
│      #1     │────▶│      #2     │────▶│      #3     │────▶│      #4     │
│             │◀────│             │◀────│             │◀────│             │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
       │                   │                   │                   │
       ▼                   ▼                   ▼                   ▼
  ┌─────────┐        ┌─────────┐        ┌─────────┐        ┌─────────┐
  │  Disk 1 │        │  Disk 2 │        │  Disk 3 │        │  Disk 4 │
  └─────────┘        └─────────┘        └─────────┘        └─────────┘
```

### Benefits

1. **High Availability**
   - Continues operating if nodes fail
   - Automatic failover
   - No single point of failure

2. **Data Durability**
   - Erasure coding protects against data loss
   - Can tolerate N/2 node failures (N = total nodes)
   - Automatic healing of corrupted data

3. **Scalability**
   - Aggregate bandwidth of all nodes
   - Total storage = sum of all node storage
   - Linear performance scaling

4. **Load Distribution**
   - Requests distributed across all nodes
   - Parallel processing of large objects
   - Better resource utilization

### Configuration

**Basic Setup:**
```yaml
kit:
  features:
    - distributed
    - self-signed-certs  # or provided-cert

params:
  num_minio_nodes: 4  # Minimum for distributed mode
```

**Advanced Configuration:**
```yaml
params:
  num_minio_nodes: 8  # More nodes for better performance
  availability_zones: [z1, z2, z3]  # Spread across AZs
  vm_type: large  # Bigger VMs for better performance
  disk_type: fast-ssd  # Fast storage for better IOPS
```

**Node Count Guidelines:**
- **4 nodes**: Minimum, tolerates 1 node failure
- **8 nodes**: Good balance, tolerates 3 node failures
- **16 nodes**: High performance, tolerates 7 node failures
- **32 nodes**: Maximum supported

### Best Practices

1. **Even Number of Nodes**
   - Required by Minio for optimal erasure coding
   - Valid: 4, 6, 8, 10, 12, 14, 16... up to 32

2. **Consistent Hardware**
   - All nodes should have same CPU/RAM (vm_type)
   - All nodes must have same disk size
   - Network bandwidth should be consistent

3. **Network Considerations**
   - Low latency between nodes is critical
   - 10Gbps+ network recommended for production
   - Keep nodes in same region/datacenter

4. **Availability Zones**
   - Distribute nodes across AZs for better fault tolerance
   - Ensure network latency between AZs is acceptable

5. **Monitoring**
   - Monitor all nodes individually
   - Watch for disk usage imbalances
   - Track network latency between nodes

## Smoke Tests

The kit includes automated smoke tests that run after deployment to verify basic functionality.

**What's Tested:**
1. Minio service is accessible
2. Authentication works correctly
3. Basic S3 operations (create bucket, put object, get object)
4. SSL/TLS configuration is correct

**Running Tests Manually:**
```bash
bosh -d dev-minio run-errand smoke-tests
```

**Test Output:**
```
Creating test bucket...
Uploading test object...
Downloading test object...
Verifying object integrity...
Cleaning up test resources...
All tests passed!
```

**Customizing Tests:**
Currently, tests are not customizable. They use the deployed instance's credentials and endpoint.

## Addons

Addons provide convenient tools for interacting with your Minio deployment.

### Visit/Open Addon

**Aliases:** `visit`, `open`, `o`

Opens the Minio web console in your default browser (macOS only).

**Usage:**
```bash
genesis do dev -- visit
genesis do dev -- open
genesis do dev -- o
```

**What it does:**
1. Retrieves access credentials from Vault
2. Displays credentials in terminal
3. Opens browser to `https://<external_domain>:<port>`

**Example Output:**
```
Minio Web Console: https://minio.example.com
Access Key: AKIAIOSFODNN7EXAMPLE
Secret Key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

Opening in default browser...
```

**Limitations:**
- macOS only (uses `open` command)
- Requires default browser to be configured

### S3 CLI Addon

**Command:** `s3`

Runs the s3 CLI tool with proper environment configuration for your Minio instance.

**Usage:**
```bash
# List buckets
genesis do dev -- s3 ls

# Create bucket
genesis do dev -- s3 make-bucket my-bucket

# Upload file
genesis do dev -- s3 put myfile.txt /my-bucket/myfile.txt

# Download file
genesis do dev -- s3 get /my-bucket/myfile.txt downloaded.txt

# Delete object
genesis do dev -- s3 rm /my-bucket/myfile.txt

# Sync directory
genesis do dev -- s3 sync ./local-dir /my-bucket/remote-dir/
```

**Environment Variables Set:**
- `S3_HOST`: Your Minio endpoint
- `S3_AKID`: Access key from Vault
- `S3_KEY`: Secret key from Vault
- `S3_USE_PATH`: Always 'yes' for Minio
- `S3_INSECURE`: '1' if using self-signed certificates

**Advanced Usage:**
```bash
# Use with pipes
tar czf - mydir/ | genesis do dev -- s3 stream /my-bucket/backup.tar.gz

# Batch operations
genesis do dev -- s3 ls /my-bucket/ | grep ".log$" | while read file; do
  genesis do dev -- s3 rm "$file"
done
```

### Download S3 Addon

**Command:** `download-s3`
**Alias:** `ds`

Downloads the s3 CLI tool for use outside of Genesis.

**Basic Usage:**
```bash
# Download to current directory
genesis do dev -- download-s3

# Download to specific location
genesis do dev -- download-s3 ~/bin/s3

# Update existing installation
genesis do dev -- download-s3 --sync
```

**Options:**
- `-p, --platform <platform>`: Force platform (darwin or linux)
- `--sync`: Update existing s3 binary found in PATH
- `<path>`: Download location (default: current directory)

**Platform Detection:**
The addon automatically detects your platform:
- macOS: Downloads Darwin binary
- Linux: Downloads Linux binary
- Others: Requires manual platform specification

**Examples:**
```bash
# Download for Linux when on macOS (for copying to server)
genesis do dev -- download-s3 -p linux s3-linux

# Update system-wide installation
sudo genesis do dev -- download-s3 --sync

# Download to custom location and make executable
genesis do dev -- download-s3 ~/bin/s3
chmod +x ~/bin/s3
```

**Post-Download Configuration:**
After downloading, configure the s3 tool:
```bash
# Get credentials
genesis info dev

# Configure s3 tool
export S3_HOST=https://minio.example.com
export S3_AKID=AKIAIOSFODNN7EXAMPLE
export S3_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
export S3_USE_PATH=yes

# For self-signed certificates
export S3_INSECURE=1
```

## Feature Interactions

### SSL + Distributed Mode

When combining SSL features with distributed mode:
- All nodes use the same certificate
- Certificate must be valid for the external domain
- Internal node communication uses the same certificates

### Best Feature Combinations

**Development Environment:**
```yaml
kit:
  features:
    - self-signed-certs
    # No distributed - save resources
```

**Production Single Node:**
```yaml
kit:
  features:
    - provided-cert
    # No distributed - simpler operations
```

**Production HA:**
```yaml
kit:
  features:
    - provided-cert
    - distributed
```

**Test/Staging HA:**
```yaml
kit:
  features:
    - self-signed-certs
    - distributed
```

## Feature Comparison

| Feature | Development | Production | HA Required | Certificate Source |
|---------|-------------|------------|-------------|-------------------|
| self-signed-certs | ✓ Recommended | ✗ Not recommended | ✗ | Generated |
| provided-cert | ✓ Possible | ✓ Recommended | ✗ | User-provided |
| distributed | ✗ Overkill | ✓ Recommended | ✓ | N/A |

## Future Features

The following features are being considered for future releases:

1. **Monitoring Integration**
   - Prometheus metrics export
   - Grafana dashboard templates
   - Alert rule templates

2. **Backup Integration**
   - Automated backup scheduling
   - Integration with backup solutions
   - Point-in-time recovery

3. **Advanced Security**
   - IAM policy support
   - Bucket policies
   - Encryption at rest

4. **Multi-Region Support**
   - Cross-region replication
   - Geo-distributed deployments
   - Region-aware routing

Stay tuned to the [GitHub repository](https://github.com/genesis-community/minio-genesis-kit) for updates!