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

There are no configurable features!

Params
------

### General Infrastructure Configuration
* `minio_disk_type` (default: `minio`) - The `persistent_disk_type` that Minio
  should use for object storage.
* `minio_vm_type` (default: `default`) - The `vm_type` that Minio should be
  deployed on.
* `stemcell_os` (default: `ubuntu-trusty`) - The operating system stemcell you
  want to deploy on.
* `stemcell_version` (default: `latest`) - The specific version of the stemcell
  you want to deploy on.

### Minio Related Configuration
* `port` (default: `9000`) -  the port for Minio to listen on

Cloud Config
------------

The Minio Genesis Kit expects a defined `persistent_disk_type` named `minio`.
The size for this varies depending on your needs, but Minio themselves recommend
a minimum of 2GB.
