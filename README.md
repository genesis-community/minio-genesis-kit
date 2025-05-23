Minio Genesis Kit
=================

The Minio Genesis kit gives you the ability to deploy Minio, a high performance
distributed object storage server (S3 alternative). 

For more information about Minio, visit their [Git Repo on
GitHub](https://github.com/minio/minio) or read their [Docs on Minio.io](https://docs.minio.io/)

Quick Start
-----------

To use it, you don't even need to clone this repository! Just run
the following (using Genesis v2.7.10 or later):

```
# create a minio-deployments repo using the latest version of the minio kit
genesis init --kit minio

# create a minio-deployments repo using v1.0.0 of the minio kit
genesis init --kit minio/1.0.0

# create a my-minio-configs repo using the latest version of the minio kit
genesis init --kit minio -d my-minio-configs
```

Once created, refer to the deployment repository README for information on
provisioning and deploying new environments.

For detailed setup instructions, see the [Getting Started Guide](docs/getting-started.md).

Features
-------

### SSL Certificates
* `self-signed-certs` - Genesis generates self-signed certificates for you.
  CA certificate is stored at `$GENESIS_VAULT_PREFIX/ssl/ca:certificate`
* `provided-cert` - Use your own SSL certificate/key pair from Vault:
  - Certificate: `$GENESIS_VAULT_PREFIX/ssl/server:certificate`
  - Private Key: `$GENESIS_VAULT_PREFIX/ssl/server:key`

### High Availability
* `distributed` - Run Minio in a distributed cluster for:
  - Increased storage capacity
  - Protection against downtime
  - Data redundancy and corruption protection
  - Requires `num_minio_nodes` parameter (4-32, even numbers only)

For detailed feature documentation, see the [Features Guide](docs/features.md).


Parameters
----------

### Required Parameters
* `external_domain` - The external domain for accessing Minio (e.g., `minio.example.com`)

### Infrastructure Configuration
* `disk_type` - The `persistent_disk_type` for object storage (default: `minio`)
* `vm_type` - The `vm_type` for Minio instances (default: `default`)
* `network` - The `network` for deployment (default: `minio`)
* `stemcell_os` - The OS stemcell to deploy (default: `ubuntu-bionic`)
* `stemcell_version` - The stemcell version (default: `latest`)
* `availability_zones` - Override default availability zones for instance groups

### Minio Configuration
* `port` - The HTTPS port for Minio (default: `443`)
* `num_minio_nodes` - Number of nodes in distributed mode:
  - Default: `1` (single node), `4` (distributed mode)
  - Must be 4-32 for distributed mode
  - Must be an even number

For a complete parameter reference, see the [Configuration Guide](docs/configuration.md).

Cloud Config
------------

The Minio Genesis Kit requires:

1. **Persistent Disk Type** named `minio`:
   - Minimum size: 2GB (Minio recommendation)
   - Size based on your storage needs
   ```yaml
   disk_types:
   - disk_size: 10240  # 10GB example
     name: minio
   ```

2. **Network** named `minio`:
   - Single node: At least 1 static IP
   - Distributed mode: At least `num_minio_nodes` static IPs

3. **VM Type** named `default` (or custom via `vm_type` parameter)

Addons
------

* `visit` (alias: `open`, `o`) - Open Minio web console and display credentials (macOS only)
* `s3` - Run s3 CLI commands with proper environment configuration
* `download-s3` (alias: `ds`) - Download the s3 CLI tool with options:
  - `-p <platform>` - Specify platform (darwin/linux)
  - `--sync` - Update existing s3 binary in PATH
  - Custom download path

Documentation
-------------

* [Getting Started Guide](docs/getting-started.md) - Quick deployment walkthrough
* [Configuration Reference](docs/configuration.md) - All parameters explained
* [Features Documentation](docs/features.md) - Detailed feature descriptions
* [Operations Guide](docs/operations.md) - Day-to-day management
* [Troubleshooting](docs/troubleshooting.md) - Common issues and solutions
* [Security Best Practices](docs/security.md) - Secure deployment guidelines
