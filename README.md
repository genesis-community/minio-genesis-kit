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

Learn More
----------
For more in-depth documentation, check out the [manual][1].


[1]: MANUAL.md