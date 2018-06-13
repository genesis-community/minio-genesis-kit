Minio Genesis Kit
=================

The Minio Genesis kit gives you the ability to deploy Minio, a high performance
distributed object storage server (S3 alternative). 

For more information about Mnio, visit their [Git Repo on
GitHub](https://github.com/minio/minio) or read their [Docs on Minio.io](https://docs.minio.io/)

Quick Start
-----------

To use it, you don't even need to clone this repository! Just run
the following (using Genesis v2):

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

Features
-------

### SSL Certificates
* `self-signed-certs` If you wish to have Genesis generate self-signed certs for
you.
* `provided-cert` If you have SSL cert/key to provide.


### HA
* `distributed` If you desire to have Minio run in a distributed cluster, increasing
  your storage as well as protecting against downtime and data rot. Requires the `num_minio_nodes` parameter set


Params
------

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

Cloud Config
------------

The Minio Genesis Kit expects a defined `persistent_disk_type` named `minio`.
The size for this varies depending on your needs, but Minio themselves recommend
a minimum of 2GB.

The Minio Genesis Kit also expects a defined `network` named `minio` with 2
static IPs allocated.
