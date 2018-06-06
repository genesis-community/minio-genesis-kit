# Vault Genesis Kit Manual

The **Vault Genesis Kit** deploys a Minio cloud object storage server. Minio is
compatible with Amazon S3 APIs.


# Base Parameters

## General Infrastructure Configuration
* `minio_disk_type` (default: `minio`) - The `persistent_disk_type` that Minio
  should use for object storage.
* `minio_vm_type` (default: `default`) - The `vm_type` that Minio should be
  deployed on.
* `stemcell_os` (default: `ubuntu-trusty`) - The operating system stemcell you
  want to deploy on.
* `stemcell_version` (default: `latest`) - The specific version of the stemcell
  you want to deploy on.

## Minio Related Configuration
* `port` (default: `9000`) -  the port for Minio to listen on

## Cloud Config
he Minio Genesis Kit expects a defined `persistent_disk_type` named `minio`.
The size for this varies depending on your needs, but Minio themselves recommend
a minimum of 2GB. Here's an example definition to place in your cloud config:
```
disk_types:
- disk_size: 2048
  name: minio
```

# Available Addons
`visit` (macOS only) - Visit the Minio server page, and print the necessary
login credentials.