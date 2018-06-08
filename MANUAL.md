# Vault Genesis Kit Manual

The **Vault Genesis Kit** deploys a Minio cloud object storage server. Minio is
compatible with Amazon S3 APIs.


# Base Parameters

## General Infrastructure Configuration
* `minio_disk_type` - The `persistent_disk_type` that Minio
  should use for object storage.  (default: `minio`)
* `vm_type`- The `vm_type` that Minio should be
  deployed on. (default: `default`) 
* `network` - The `network` that Minio should be
  deployed on. (default: `minio`)
* `stemcell_os` - The operating system stemcell you
  want to deploy on. (default: `ubuntu-trusty`)
* `stemcell_version` - The specific version of the stemcell
  you want to deploy on. (default: `latest`)

## Minio Related Configuration
* `port` -  the port for Nginx to listen on (default: `443`)

## Cloud Config
The Minio Genesis Kit expects a defined `persistent_disk_type` named `minio`.
The size for this varies depending on your needs, but Minio themselves recommend
a minimum of 2GB. Here's an example definition to place in your cloud config:
```
disk_types:
- disk_size: 2048
  name: minio
```

The Minio Genesis Kit also expected a defined `network` named `minio` with at
least 2 static IPs. 

# Available Addons
`visit` (macOS only) - Visit the Minio server page, and print the necessary
login credentials.