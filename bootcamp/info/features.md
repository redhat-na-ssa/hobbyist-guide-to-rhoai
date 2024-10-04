# Notes - OVERVIEW

Overview of the features in Red Hat OpenShift dependencies.

|       Component        | Sub-components | Training  |  Serving  |             Description         |
|------------------------|----------------|-----------|-----------|---------------------------------|
| RHOAI Operator         |                |     x     |     x     |Deploys and maintains the components for RHOAI|
| `dashboard`            |                |     x     |     x     |Admin and user primary interface |
| `workbenches`          |                |     x     |           |Notebooks images (i.e. Jupyter, code-server, RStudio)|
| `datasciencepipelines` |                |     x     |           |Schedulable multi-step ML workflow execution graph|
| `distributed-workloads`|                |     x     |           |Scalable ML library for distributed training and fine-tuning|
|                        |   CodeFlare    |     x     |           |Secures deployed Ray clusters and grants access to their URLs|
|                        |   CodeFlare SDK|     x     |           |Python interface for batch resource requesting, job submission, etc.|
|                        |   Kuberay      |     x     |           |Manages remote Ray clusters on K8s for running distributed workloads|
|                        |   Kueue        |     x     |           |Manages quotas, queuing and how distributed workloads consume them|
|                        |   MCAD         |     x     |           |K8s controller to manage batch jobs in a single / multi-cluster env|
|                        |   Instascale   |     x     |           |works with MCAD to launch instances on cloud provider|
|   `modelmeshserving`   |                |           |     x     |model serving routing layer w/Triton, Seldon, OpenVINO, torchserve...|
|   `kserve`             |                |           |     x     |serverless inference w/Triton, HuggingFace, PyTorch, TF, LightGBM...|
|                        |  `servicemesh` |           |     x     |provides observability, traffic mgmt, and security for inference|
|                        |    `knative`   |           |     x     |provides Autoscaling including Scale to Zero for inference|
|                        |   `Authorino`  |           |     x     |provides token authorization for model inference APIs|

[Supported Configurations](https://access.redhat.com/articles/rhoai-supported-configs)

## Tips

- Red Hat recommends that you install only one instance of RHOCP (or ODH) on your cluster.
- Your cluster must have at least 2 worker nodes with at least 8 CPUs and 32 GiB RAM available for OpenShift AI to use when you install the Operator.
- A default `storageclass` that can be dynamically provisioned must be configured.
- Access to the cluster as a user with the `cluster-admin` role; the `kubeadmin` user is not allowed.
- `Open Data Hub` must not be installed on the cluster
- **Data Science Pipelines (DSP) 2.0**  
  - contains an installation of Argo Workflows.
  - OpenShift AI does not support direct customer usage of this installation of Argo Workflows.
    Before installing OpenShift AI, ensure that your cluster does not have an existing installation of Argo Workflows that is not installed by DSP.
  - If there is an existing installation of Argo Workflows that is not installed by DSP on your cluster, data science pipelines will be disabled after you install OpenShift AI.
  - store your pipeline artifacts in an S3-compatible object storage bucket so that you do not consume local storage.
- **KServe**
  - you must also install Operators for Red Hat OpenShift Serverless and Red Hat OpenShift Service Mesh and perform additional configuration.
  - If you want to add an authorization provider for the single-model serving platform, you must install the Red Hat - Authorino Operator
- **Object Storage**
  - Object storage is required for the following components:
    - Single- or multi-model serving platforms, to deploy stored models.
    - Data science pipelines, to store artifacts, logs, and intermediate results.
  - Object storage can be used by the following components:
    - Workbenches, to access large datasets.
    - Distributed workloads, to pull input data from and push results to.
    - Code executed inside a pipeline. For example, to store the resulting model in object storage.

## Source repositories

Required images come from the following domains:

1. cdn.redhat.com
1. subscription.rhn.redhat.com
1. registry.access.redhat.com
1. registry.redhat.io
1. quay.io

For CUDA-based images, the following domains must be accessible:

1. ngc.download.nvidia.cn
1. developer.download.nvidia.com

## Cluster Worker Node Size

|Qty|vCPU|Memory|Qty|GPU Arch |Notes|
|---|----|------|---|---------|-----|
| 3 | 4  | 16   | 0 |---------|not enough resources|
| 2 | 8  | 32   | 0 |---------|minimum required to install all the components|
| 4 | 4  | 16   | 0 |---------|minimum required to install all the components|
| 1 | 16 | 64   | 0 |---------|minimum required to install all the components|
| 5 | 4  | 16   | 0 |---------|minimum required to create a data science project with a `small` workbench container size|
| 1 | 16 | 64   | 0 |---------|minimum required to create a data science project with a `small` workbench container size|
| 6 | 4  | 16   | 0 |---------|minimum required to run the distributed workloads demo `0_basic_ray.ipynb`|
| 6 | 4  | 16   | 1 |nvidia t4|minimum required to run the distributed workloads demo `1_cluster_job_client.ipynb`|
| 1 | 16 | 64   | 2 |nvidia t4|minimum required to run the distributed workloads demo `2_basic_interactive.ipynb`|
| 1 | 16 | 64   | 2 |nvidia t4|minimum required to run the distributed workloads demo `2_basic_interactive.ipynb`|
