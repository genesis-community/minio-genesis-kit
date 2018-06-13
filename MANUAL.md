# Minio Genesis Kit Manual

The **Minio Genesis Kit** deploys a Minio cloud object storage server. Minio is
compatible with Amazon S3 APIs.

## Features

### SSL Certificates
* `self-signed-certs` If you wish to have Genesis generate self-signed certs for
you.
* `provided-cert` If you have SSL cert/key to provide.

### HA
* `distributed` If you desire to have Minio run in a distributed cluster, increasing
  your storage as well as protecting against downtime and data rot. Requires the `num_minio_nodes` parameter set

## Params

### General Infrastructure Configuration
* `disk_type` - The `persistent_disk_type` that Minio
  should use for object storage.  (default: `minio`)
* `vm_type`- The `vm_type` that Minio should be
  deployed on. (default: `default`) 
* `network` - The `network` that Minio should be
  deployed on. (default: `minio`)
* `stemcell_os` - The operating system stemcell you
  want to deploy on. (default: `ubuntu-trusty`)
* `stemcell_version` - The specific version of the stemcell
  you want to deploy on. (default: `latest`)

### Minio Related Configuration
* `port` -  The port for Nginx to listen on (default: `443`)
* `num_minio_nodes` - The amount of desired Minio nodes in a
  cluster. (default: `1`, `4` for distributed clusters). If
  Minio deployment is distributed, value must be greater than
  4, less than 32, and evenly divisible by 2.
## Cloud Config
The Minio Genesis Kit expects a defined `persistent_disk_type` named `minio`.
The size for this varies depending on your needs, but Minio themselves recommend
a minimum of 2GB. Here's an example definition to place in your cloud config:
```
disk_types:
- disk_size: 2048
  name: minio
```

The Minio Genesis Kit also expected a defined `network` named `minio` with at least
1 IP, or `num_minio_nodes` IPs.

# Available Addons
* `visit` (macOS only) - Visit the Minio server page, and print the necessary
  login credentials.
* `target` - Set the environment variables necessary to target the Minio instance
  with `s3`
* `download-s3` - Download [James Hunt's S3 CLI tool](https://github.com/jhunt/s3)
  for interacting with this Minio instance.
