# Notes - OVERVIEW



Overview of the features in Red Hat OpenShift dependencies.

|Component            |Purpose     |Dependency   |Resources          |Description      |
|---------------------|------------|-------------|-------------------|-----------------|
|operator             |management  |S3 Store     |2-worker 8CPU 32GiB |Deploys and maintains the components for RHOAI       |
|dashboard            |management  |             |                   |Admin and user primary interface   |
|workbenches          |train       |             |                   |                 |
|datasciencepipelines |train       |S3 Store     |                   |                 |
|distributed workloads|train       |             |1.6 vCPU and 2 GiB |                 |
|                     |            |dashboard    |                   |See above |
|                     |            |datasciencepipelines    |                   |See above |
|                     |            |CodeFlare    |                   |Secures deployed Ray clusters and grants access to their URLs |
|                     |            |CodeFlare SDK|                   |controls the remote distributed compute jobs and infrastructure for any Python-based env|
|                     |            |Kuberay      |                   |KubeRay manages remote Ray clusters on OCP for running distributed workloads|
|                     |            |Kueue        |                   |Manages quotas, queuing and how distributed workloads consume them |
|                     |            |Multi-Cluster App Dispatcher (MCAD)|                   |a K8s controller to manage batch jobs in a single or multi-cluster environment |
|                     |            |Instascale   |                   |works with MCAD to get aggregated resources available in the K8s cluster without creating pending pods. Uses machinesets to launch instances on cloud provider |
|modelmeshserving     |inference   |S3 Store     |                   |                 |
|kserve               |inference   |             |4 CPUs and 16 GB   |orchestrates model serving for all types of models|
|                     |            |ServiceMesh  |4 CPUs and 16 GB   |networking layer that manages traffic flows and enforces access policies                 |
|                     |            |Serverless   |4 CPUs and 16 GB   |allows for serverless deployments of models|
|                     |            |Authorino    |                   |enable token authorization for models|

1. Central Dashboard for Development and Operations for Admin and Users
1. Curated Workbench Images (incl CUDA, PyTorch, Tensorflow, code-server)
    1. Ability to add Custom Images
    1. Ability to leverage accelerators (such as NVIDIA GPU)
1. Data Science Pipelines (including Elyra notebook interface) (Kubeflow pipelines)
1. Model Serving using ModelMesh and Kserve.
    1. Ability to use Serverless and Event Driven Applications as wells as configure secure gateways (Knative, OpenSSL)
    1. Ability to manage traffic flow and enforce access policies
    1. When you have installed KServe, you can use the OpenShift AI dashboard to deploy models using pre-installed or custom model-serving runtimes:  
      1. TGIS Standalone ServingRuntime for KServe: A runtime for serving TGI-enabled models
      1. Caikit-TGIS ServingRuntime for KServe: A composite runtime for serving models in the Caikit format
      1. Caikit Standalone ServingRuntime for KServe: A runtime for serving models in the Caikit embeddings format for embeddings tasks
      1. OpenVINO Model Server: A scalable, high-performance runtime for serving models that are optimized for Intel architectures
      1. vLLM ServingRuntime for KServe: A high-throughput and memory-efficient inference and serving runtime for large language models
    1. Ability to use other runtimes for serving (TGIS, Caikit-TGIS, OpenVino)
    1. Ability to enable token authorization for models that you deploy on the platform, which ensures that only authorized parties can make inference requests to the models (Authorino)
1. Model Monitoring
1. Distributed workloads (CodeFlare Operator, CodeFlare SDK, KubeRay, Kueue)
    1. You can run distributed workloads from data science pipelines, from Jupyter notebooks, or from Microsoft Visual Studio Code files.
    1. Ability to deploy Ray clusters with mTLS default
    1. Ability to control the remote distributed compute jobs and infrastructure
    1. Ability to manage remote Ray clusters on OpenShift
    1. Ability to run distributed workloads from data science pipelines, from Jupyter notebooks, or from Microsoft Visual Studio Code files.

## Default Operations

RHOAI creates 4x OCP Projects

1. `redhat-ods-operator` project contains the Red Hat OpenShift AI Operator.
1. `redhat-ods-applications` project installs the dashboard and other required components of OpenShift AI.
1. `redhat-ods-monitoring` project contains services for monitoring.
1. `rhods-notebooks` project is where notebook environments are deployed by default.

> Do not install independent software vendor (ISV) applications in namespaces associated with OpenShift AI.

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
