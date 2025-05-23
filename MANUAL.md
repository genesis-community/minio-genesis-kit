# Minio Genesis Kit Manual

The **Minio Genesis Kit** deploys a Minio cloud object storage server, providing
high-performance, S3-compatible object storage for your infrastructure. Minio is
fully compatible with Amazon S3 APIs, making it an ideal choice for private cloud
storage solutions.

**Requirements:**
- Genesis v2.7.10 or later
- BOSH Director
- Vault for secret storage
- Cloud Config with appropriate resources

## Features

### SSL Certificates

#### `self-signed-certs`
Genesis automatically generates self-signed certificates for your Minio deployment.
- Certificates are stored in Vault at:
  - CA Certificate: `$GENESIS_VAULT_PREFIX/ssl/ca:certificate`
  - Server Certificate: `$GENESIS_VAULT_PREFIX/ssl/server:certificate`
  - Server Private Key: `$GENESIS_VAULT_PREFIX/ssl/server:key`
- Sets `S3_INSECURE=1` environment variable for s3 addon

#### `provided-cert`
Use your own SSL certificate and private key.
- Must be pre-stored in Vault at:
  - Certificate: `$GENESIS_VAULT_PREFIX/ssl/server:certificate`
  - Private Key: `$GENESIS_VAULT_PREFIX/ssl/server:key`

### High Availability

#### `distributed`
Deploy Minio in distributed mode for high availability and increased storage.
- Benefits:
  - Data redundancy across multiple nodes
  - Protection against hardware failures
  - Increased storage capacity
  - Better read/write performance
- Requirements:
  - `num_minio_nodes` must be set (4-32, even numbers only)
  - Sufficient IPs in network allocation
  - Consistent disk sizes across all nodes

## Parameters

### Required Parameters

#### `external_domain`
- **Type:** String
- **Required:** Yes
- **Description:** The external domain name for accessing Minio
- **Example:** `minio.example.com`

### Infrastructure Configuration

#### `disk_type`
- **Type:** String
- **Default:** `minio`
- **Description:** The persistent disk type from cloud config for object storage
- **Recommendation:** Minimum 2GB, size based on storage needs

#### `vm_type`
- **Type:** String
- **Default:** `default`
- **Description:** The VM type from cloud config for Minio instances
- **Recommendation:** At least 1 CPU, 2GB RAM for production

#### `network`
- **Type:** String
- **Default:** `minio`
- **Description:** The network from cloud config for deployment
- **Requirements:** Static IPs required (1 for single node, N for distributed)

#### `stemcell_os`
- **Type:** String
- **Default:** `ubuntu-bionic`
- **Description:** The operating system for deployment
- **Options:** `ubuntu-bionic`, `ubuntu-jammy`

#### `stemcell_version`
- **Type:** String
- **Default:** `latest`
- **Description:** The stemcell version to use
- **Example:** `621.125` or `latest`

#### `availability_zones`
- **Type:** Array
- **Default:** Cloud Config default
- **Description:** Override availability zones for instance placement
- **Example:** `[z1, z2, z3]`

### Minio Configuration

#### `port`
- **Type:** Integer
- **Default:** `443`
- **Description:** The HTTPS port for Minio service
- **Note:** Minio always uses HTTPS in this kit

#### `num_minio_nodes`
- **Type:** Integer
- **Default:** `1` (single node), `4` (distributed mode)
- **Description:** Number of Minio nodes in the cluster
- **Constraints:**
  - Single node: Must be `1`
  - Distributed: Must be 4-32 and even number
  - Common values: 4, 8, 16
## Cloud Config Requirements

### Disk Types
Define a persistent disk type named `minio`:
```yaml
disk_types:
- name: minio
  disk_size: 10240  # 10GB - adjust based on needs
  # Optional cloud-specific properties:
  cloud_properties:
    type: pd-ssd  # GCP example
    # type: gp3   # AWS example
```

**Sizing Guidelines:**
- Minimum: 2GB (Minio recommendation)
- Development: 10-50GB
- Production: 100GB+ depending on data volume
- Distributed mode: All nodes must have same disk size

### Networks
Define a network named `minio` with static IPs:
```yaml
networks:
- name: minio
  type: manual
  subnets:
  - range: 10.0.1.0/24
    gateway: 10.0.1.1
    az: z1
    static: [10.0.1.10-10.0.1.50]
    cloud_properties:
      name: minio-subnet
```

**IP Requirements:**
- Single node: 1 static IP
- Distributed mode: At least `num_minio_nodes` static IPs
- Test instances: 1 additional IP for smoke tests

### VM Types
Ensure appropriate VM types are defined:
```yaml
vm_types:
- name: default
  cloud_properties:
    instance_type: t3.small     # AWS
    # machine_type: n1-standard-1  # GCP
    # vm_size: Standard_B2s        # Azure
```

**Sizing Recommendations:**
- CPU: 1-2 cores minimum, 4+ for production
- RAM: 2GB minimum, 8GB+ for production
- Network: 1Gbps+ for distributed mode

## Available Addons

### `visit` (aliases: `open`, `o`)
**macOS only** - Opens the Minio web console in your default browser.
- Displays access credentials before opening
- URL format: `https://<external_domain>:<port>`
- Credentials retrieved from Vault

**Usage:**
```bash
genesis do <env> -- visit
genesis do <env> -- open
genesis do <env> -- o
```

### `s3`
Run s3 CLI commands with proper environment configuration.
- Sets required environment variables:
  - `S3_HOST`: Minio endpoint
  - `S3_AKID`: Access key ID
  - `S3_KEY`: Secret access key
  - `S3_USE_PATH`: Set to 'yes'
  - `S3_INSECURE`: Set to '1' for self-signed certs
- Passes all arguments to the s3 command

**Usage:**
```bash
genesis do <env> -- s3 ls
genesis do <env> -- s3 put myfile.txt /bucket/path/
genesis do <env> -- s3 get /bucket/file.txt localfile.txt
```

### `download-s3` (alias: `ds`)
Download the [s3 CLI tool](https://github.com/jhunt/s3) for interacting with Minio.

**Options:**
- `-p <platform>` - Specify platform (darwin or linux, auto-detected by default)
- `--sync` - Update existing s3 binary in PATH
- `[path]` - Custom download location (default: current directory)

**Usage:**
```bash
# Download to current directory
genesis do <env> -- download-s3

# Download to specific location
genesis do <env> -- download-s3 ~/bin/s3

# Update existing installation
genesis do <env> -- download-s3 --sync

# Specify platform
genesis do <env> -- download-s3 -p linux
```

## Vault Integration

### Paths and Secrets

The kit stores various secrets in Vault:

#### Access Credentials
- **Path:** `$GENESIS_VAULT_PREFIX/access_token`
- **Keys:**
  - `accesskey`: Minio access key ID
  - `secretkey`: Minio secret access key

#### SSL Certificates
- **Self-signed:**
  - CA: `$GENESIS_VAULT_PREFIX/ssl/ca:certificate`
  - Server: `$GENESIS_VAULT_PREFIX/ssl/server:certificate,key`
- **Provided:**
  - Server: `$GENESIS_VAULT_PREFIX/ssl/server:certificate,key`

## Exodus Data

After deployment, the following data is available via `genesis info`:

- **url**: The HTTPS URL for accessing Minio
- **access_key**: The access key ID for S3 operations
- **secret_key**: The secret access key for S3 operations
- **bucket_name**: Default bucket name (if configured)
- **dist**: Boolean indicating if distributed mode is enabled
- **self-signed**: Boolean indicating if using self-signed certificates

**Example:**
```bash
genesis info <env>
# Outputs:
# url: https://minio.example.com
# access_key: AKIAIOSFODNN7EXAMPLE
# secret_key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
# dist: true
# self-signed: false
```

## Post-Deployment

After successful deployment:

1. **Smoke Tests**: Automatically run to verify basic functionality
2. **Access Credentials**: Stored in Vault and available via exodus
3. **Web Console**: Accessible at `https://<external_domain>:<port>`
4. **S3 Endpoint**: Ready for S3-compatible operations

### Verification Commands
```bash
# Check deployment status
genesis info <env>

# Access web console
genesis do <env> -- visit

# Test S3 connectivity
genesis do <env> -- s3 ls
```
