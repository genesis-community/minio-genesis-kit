# Getting Started with Minio Genesis Kit

This guide will walk you through deploying your first Minio instance using the Genesis framework.

## Prerequisites

Before you begin, ensure you have:

1. **Genesis CLI** v2.7.10 or later installed
   ```bash
   genesis version
   ```

2. **BOSH Director** deployed and accessible
   ```bash
   bosh env
   ```

3. **Vault** deployed and initialized
   ```bash
   safe target
   ```

4. **Cloud Config** with required resources (see below)

## Step 1: Initialize Your Deployment Repository

Create a new deployment repository for managing your Minio environments:

```bash
# Create a new repository with the latest Minio kit
genesis init --kit minio

# Or specify a specific version
genesis init --kit minio/1.0.0

# Navigate to the repository
cd minio-deployments
```

## Step 2: Prepare Cloud Config

Ensure your BOSH Director has the required cloud config resources:

```yaml
# cloud-config.yml
disk_types:
- name: minio
  disk_size: 10240  # 10GB for development

vm_types:
- name: default
  cloud_properties:
    instance_type: t3.small     # AWS example
    # machine_type: n1-standard-1  # GCP example

networks:
- name: minio
  type: manual
  subnets:
  - range: 10.0.1.0/24
    gateway: 10.0.1.1
    static: [10.0.1.10-10.0.1.20]
    az: z1
```

Upload the cloud config:
```bash
bosh update-cloud-config cloud-config.yml
```

## Step 3: Create Your First Environment

Create a new Minio environment:

```bash
genesis new dev
```

This creates a `dev.yml` file in your repository.

## Step 4: Configure Your Environment

Edit `dev.yml` to set required parameters:

```yaml
---
kit:
  name: minio
  version: latest
  features:
    - self-signed-certs  # For development

genesis:
  env: dev

params:
  external_domain: minio.dev.example.com
  
  # Optional: Override defaults
  # vm_type: large
  # disk_type: minio-large
  # port: 9000
```

### Configuration Options

#### For Single Node (Default)
No additional configuration needed. This is suitable for:
- Development environments
- Testing and proof of concepts
- Low-traffic applications

#### For Distributed Mode (High Availability)
Add the distributed feature and configure nodes:

```yaml
kit:
  features:
    - self-signed-certs
    - distributed

params:
  external_domain: minio.prod.example.com
  num_minio_nodes: 4  # Must be 4-32, even number
```

## Step 5: Deploy Minio

Deploy your Minio instance:

```bash
# Check what will be deployed
genesis manifest dev

# Deploy
genesis deploy dev
```

The deployment process will:
1. Generate required secrets in Vault
2. Create SSL certificates (if using self-signed)
3. Deploy Minio instances
4. Run smoke tests to verify functionality

## Step 6: Access Your Minio Instance

### Get Access Credentials

```bash
genesis info dev

# Output:
# url: https://minio.dev.example.com
# access_key: AKIAIOSFODNN7EXAMPLE
# secret_key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

### Access Web Console

For macOS users:
```bash
genesis do dev -- visit
```

For other systems, manually browse to the URL shown by `genesis info`.

### Test S3 Connectivity

Download the S3 CLI tool:
```bash
genesis do dev -- download-s3
```

Test basic operations:
```bash
# List buckets (none initially)
genesis do dev -- s3 ls

# Create a bucket
genesis do dev -- s3 make-bucket my-first-bucket

# Upload a file
echo "Hello Minio!" > test.txt
genesis do dev -- s3 put test.txt /my-first-bucket/test.txt

# List bucket contents
genesis do dev -- s3 ls /my-first-bucket/

# Download the file
genesis do dev -- s3 get /my-first-bucket/test.txt downloaded.txt
```

## Next Steps

Now that you have a working Minio deployment:

1. **Configure Applications**: Use the S3 endpoint and credentials in your applications
2. **Set Up Monitoring**: Configure monitoring for your Minio instances
3. **Plan for Production**: Review the [Security Guide](security.md) and [Operations Guide](operations.md)
4. **Scale Out**: Consider [distributed mode](features.md#distributed-mode) for production

## Common Issues

### Certificate Warnings
When using self-signed certificates, you'll see SSL warnings. This is expected in development. For production, use provided certificates.

### Cannot Access Web Console
Ensure:
- The external_domain resolves to your Minio instance
- Port 443 (or your configured port) is accessible
- No firewall rules blocking access

### Deployment Fails
Check:
- Cloud config has required resources
- Network has enough static IPs
- Vault is accessible and authenticated

For more troubleshooting tips, see the [Troubleshooting Guide](troubleshooting.md).