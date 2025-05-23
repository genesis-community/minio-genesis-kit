# Minio Genesis Kit Configuration Reference

This document provides a complete reference for all configuration parameters available in the Minio Genesis Kit.

## Table of Contents

- [Required Parameters](#required-parameters)
- [Infrastructure Parameters](#infrastructure-parameters)
- [Minio Parameters](#minio-parameters)
- [Feature Flags](#feature-flags)
- [Environment Variables](#environment-variables)
- [Vault Paths](#vault-paths)
- [Exodus Data](#exodus-data)

## Required Parameters

### external_domain

- **Type:** String
- **Required:** Yes
- **Default:** None
- **Description:** The external domain name used to access your Minio instance
- **Example:** `minio.example.com`
- **Notes:** 
  - Must be a valid domain name
  - Used for SSL certificate generation
  - Should resolve to the Minio instance IP(s)

## Infrastructure Parameters

### vm_type

- **Type:** String
- **Required:** No
- **Default:** `default`
- **Description:** The VM type from your cloud config to use for Minio instances
- **Example:** `small`, `medium`, `large`
- **Recommendations:**
  - Development: 1 CPU, 2GB RAM
  - Production: 4+ CPU, 8GB+ RAM
  - Distributed: Consistent across all nodes

### disk_type

- **Type:** String
- **Required:** No
- **Default:** `minio`
- **Description:** The persistent disk type from your cloud config for object storage
- **Example:** `minio`, `minio-ssd`, `large-storage`
- **Sizing Guidelines:**
  - Minimum: 2GB (Minio requirement)
  - Development: 10-50GB
  - Production: 100GB-10TB based on needs
  - Distributed: All nodes must have same size

### network

- **Type:** String
- **Required:** No
- **Default:** `minio`
- **Description:** The network from your cloud config for deployment
- **Example:** `minio`, `private`, `dmz`
- **Requirements:**
  - Must have static IP allocation
  - Single node: 1 static IP minimum
  - Distributed: `num_minio_nodes` static IPs minimum
  - Additional IP for smoke tests

### stemcell_os

- **Type:** String
- **Required:** No
- **Default:** `ubuntu-bionic`
- **Description:** The operating system for the deployment stemcell
- **Options:**
  - `ubuntu-bionic` (recommended)
  - `ubuntu-jammy`
  - `ubuntu-trusty` (deprecated)
- **Notes:** Ensure your BOSH Director has the appropriate stemcell uploaded

### stemcell_version

- **Type:** String
- **Required:** No
- **Default:** `latest`
- **Description:** The specific stemcell version to use
- **Examples:**
  - `latest` (recommended for development)
  - `621.125` (specific version for production)
- **Notes:** Using specific versions ensures consistency across deployments

### availability_zones

- **Type:** Array of Strings
- **Required:** No
- **Default:** Uses cloud config defaults
- **Description:** Override the availability zones for instance placement
- **Example:** `[z1, z2, z3]`
- **Use Cases:**
  - Distribute nodes across AZs in distributed mode
  - Target specific infrastructure
  - Meet compliance requirements

## Minio Parameters

### port

- **Type:** Integer
- **Required:** No
- **Default:** `443`
- **Description:** The HTTPS port for the Minio service
- **Example:** `443`, `9000`, `8443`
- **Notes:**
  - Always uses HTTPS (TLS/SSL)
  - Common alternatives: 9000 (Minio default), 8443
  - Ensure firewall rules allow this port

### num_minio_nodes

- **Type:** Integer
- **Required:** Only when using `distributed` feature
- **Default:** 
  - `1` (single node mode)
  - `4` (when distributed feature is enabled)
- **Description:** Number of Minio server instances in the cluster
- **Constraints:**
  - Single mode: Must be `1`
  - Distributed mode: 4-32, must be even number
- **Common Values:**
  - `4` - Minimum for distributed mode
  - `8` - Good balance of redundancy and resources
  - `16` - High availability for large deployments
- **Considerations:**
  - More nodes = better fault tolerance
  - More nodes = more network traffic
  - All nodes need same disk size

## Feature Flags

Features are enabled in your environment file under `kit.features`:

```yaml
kit:
  features:
    - self-signed-certs
    - distributed
```

### self-signed-certs

- **Description:** Genesis generates self-signed SSL certificates
- **Use Case:** Development and testing environments
- **Behavior:**
  - Generates CA certificate
  - Creates server certificate signed by CA
  - Stores in Vault
  - Sets `S3_INSECURE=1` for s3 addon
- **Mutually Exclusive With:** `provided-cert`

### provided-cert

- **Description:** Use pre-existing SSL certificates from Vault
- **Use Case:** Production environments with real certificates
- **Requirements:**
  - Certificate at: `$GENESIS_VAULT_PREFIX/ssl/server:certificate`
  - Private key at: `$GENESIS_VAULT_PREFIX/ssl/server:key`
- **Mutually Exclusive With:** `self-signed-certs`

### distributed

- **Description:** Enable distributed mode for high availability
- **Use Case:** Production environments requiring HA
- **Requirements:**
  - `num_minio_nodes` parameter must be set
  - Sufficient static IPs in network
- **Benefits:**
  - Data redundancy
  - Fault tolerance
  - Increased storage capacity
  - Better performance

## Environment Variables

These environment variables are set by various addons:

### S3_HOST
- **Set By:** `s3` addon
- **Value:** Minio endpoint URL
- **Example:** `https://minio.example.com:443`

### S3_AKID
- **Set By:** `s3` addon
- **Value:** Access Key ID from Vault
- **Example:** `AKIAIOSFODNN7EXAMPLE`

### S3_KEY
- **Set By:** `s3` addon
- **Value:** Secret Access Key from Vault
- **Example:** `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY`

### S3_USE_PATH
- **Set By:** `s3` addon
- **Value:** `yes`
- **Purpose:** Use path-style URLs instead of virtual-hosted-style

### S3_INSECURE
- **Set By:** `s3` addon (when using self-signed certificates)
- **Value:** `1`
- **Purpose:** Skip SSL certificate verification

## Vault Paths

The kit uses these Vault paths (where `$PREFIX` is `$GENESIS_VAULT_PREFIX`):

### Access Credentials
- **Path:** `$PREFIX/access_token`
- **Keys:**
  - `accesskey`: Minio access key ID
  - `secretkey`: Minio secret access key

### SSL Certificates (Self-Signed)
- **CA Certificate:** `$PREFIX/ssl/ca:certificate`
- **Server Certificate:** `$PREFIX/ssl/server:certificate`
- **Server Private Key:** `$PREFIX/ssl/server:key`

### SSL Certificates (Provided)
- **Server Certificate:** `$PREFIX/ssl/server:certificate`
- **Server Private Key:** `$PREFIX/ssl/server:key`

## Exodus Data

After deployment, the following data is available via `genesis info`:

### url
- **Type:** String
- **Description:** The HTTPS URL for accessing Minio
- **Example:** `https://minio.example.com`

### access_key
- **Type:** String
- **Description:** The access key ID for S3 operations
- **Example:** `AKIAIOSFODNN7EXAMPLE`

### secret_key
- **Type:** String
- **Description:** The secret access key for S3 operations
- **Example:** `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY`

### dist
- **Type:** Boolean
- **Description:** Whether distributed mode is enabled
- **Values:** `true` or `false`

### self-signed
- **Type:** Boolean
- **Description:** Whether using self-signed certificates
- **Values:** `true` or `false`

## Example Configurations

### Minimal Development Environment

```yaml
---
kit:
  name: minio
  features:
    - self-signed-certs

params:
  external_domain: minio.dev.local
```

### Production Single Node

```yaml
---
kit:
  name: minio
  features:
    - provided-cert

params:
  external_domain: minio.prod.example.com
  vm_type: large
  disk_type: minio-ssd-1tb
  stemcell_version: 621.125
```

### Production Distributed Mode

```yaml
---
kit:
  name: minio
  features:
    - provided-cert
    - distributed

params:
  external_domain: minio.prod.example.com
  num_minio_nodes: 8
  vm_type: xlarge
  disk_type: minio-ssd-2tb
  availability_zones: [z1, z2, z3]
  stemcell_version: 621.125
```

### Custom Network and Port

```yaml
---
kit:
  name: minio
  features:
    - self-signed-certs

params:
  external_domain: minio.internal.corp
  network: dmz
  port: 9000
  vm_type: medium
```

## Best Practices

1. **Always specify `external_domain`** - It's required and critical for proper operation

2. **Use specific stemcell versions in production** - Ensures consistency across deployments

3. **Size disks appropriately** - Consider growth and backup requirements

4. **Use distributed mode for production** - Provides redundancy and better performance

5. **Secure your certificates** - Use provided-cert feature with real certificates in production

6. **Plan your network allocation** - Ensure enough static IPs for current and future needs

7. **Monitor disk usage** - Minio doesn't handle full disks gracefully

8. **Keep node counts reasonable** - More isn't always better; consider network overhead

9. **Document your configuration** - Especially custom parameters and reasons for choices