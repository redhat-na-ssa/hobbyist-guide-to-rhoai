# Notes - OVERVIEW

Overview of the features in Red Hat OpenShift dependencies.

| Component               | Sub-components | Training | Serving | Description                                                           |
| ----------------------- | -------------- | -------- | ------- | --------------------------------------------------------------------- |
| RHOAI Operator          |                | x        | x       | Deploys and maintains the components for RHOAI                        |
| `dashboard`             |                | x        | x       | Admin and user primary interface                                      |
| `workbenches`           |                | x        |         | Notebooks images (i.e. Jupyter, code-server, RStudio)                 |
| `datasciencepipelines`  |                | x        |         | Schedulable multi-step ML workflow execution graph                    |
| `distributed-workloads` |                | x        |         | Scalable ML library for distributed training and fine-tuning          |
|                         | CodeFlare      | x        |         | Secures deployed Ray clusters and grants access to their URLs         |
|                         | CodeFlare SDK  | x        |         | Python interface for batch resource requesting, job submission, etc.  |
|                         | Kuberay        | x        |         | Manages remote Ray clusters on K8s for running distributed workloads  |
|                         | Kueue          | x        |         | Manages quotas, queuing and how distributed workloads consume them    |
|                         | MCAD           | x        |         | K8s controller to manage batch jobs in a single / multi-cluster env   |
|                         | Instascale     | x        |         | works with MCAD to launch instances on cloud provider                 |
| `modelmeshserving`      |                |          | x       | model serving routing layer w/Triton, Seldon, OpenVINO, torchserve... |
| `kserve`                |                |          | x       | serverless inference w/Triton, HuggingFace, PyTorch, TF, LightGBM...  |
|                         | `servicemesh`  |          | x       | provides observability, traffic mgmt, and security for inference      |
|                         | `knative`      |          | x       | provides Autoscaling including Scale to Zero for inference            |
|                         | `Authorino`    |          | x       | provides token authorization for model inference APIs                 |

[Supported Configurations](https://access.redhat.com/articles/rhoai-supported-configs)

## Cluster Worker Node Size

| Qty | vCPU | Memory | Qty | GPU Arch  | Notes                                                                                     |
| --- | ---- | ------ | --- | --------- | ----------------------------------------------------------------------------------------- |
| 3   | 4    | 16     | 0   | --------- | not enough resources                                                                      |
| 2   | 8    | 32     | 0   | --------- | minimum required to install all the components                                            |
| 4   | 4    | 16     | 0   | --------- | minimum required to install all the components                                            |
| 1   | 16   | 64     | 0   | --------- | minimum required to install all the components                                            |
| 5   | 4    | 16     | 0   | --------- | minimum required to create a data science project with a `small` workbench container size |
| 1   | 16   | 64     | 0   | --------- | minimum required to create a data science project with a `small` workbench container size |
| 6   | 4    | 16     | 0   | --------- | minimum required to run the distributed workloads demo `0_basic_ray.ipynb`                |
| 6   | 4    | 16     | 1   | nvidia t4 | minimum required to run the distributed workloads demo `1_cluster_job_client.ipynb`       |
| 1   | 16   | 64     | 2   | nvidia t4 | minimum required to run the distributed workloads demo `2_basic_interactive.ipynb`        |
| 1   | 16   | 64     | 2   | nvidia t4 | minimum required to run the distributed workloads demo `2_basic_interactive.ipynb`        |
