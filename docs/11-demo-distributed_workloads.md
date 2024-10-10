# Demo - Distributed Workloads

### Objectives

- Demo to showcase distributed workloads on OpenShift AI

### Rationale

- Distributed workloads enable data scientists to use multiple cluster nodes in parallel for faster and more efficient data processing and model training.
- The CodeFlare framework simplifies task orchestration and monitoring, and offers seamless integration for automated resource scaling and optimal node utilization with advanced GPU support.
  [More Info](https://access.redhat.com/documentation/en-us/red_hat_openshift_ai_self-managed/2.10/html/working_with_distributed_workloads/running-distributed-workloads_distributed-workloads)

### Takeaways

- Best practice routing to the internal service versus the external route
- Notebook #1 and the concept of Ray and Kueue
  - Running and pod on CPU and job on 3 pods on GPUs
- Notebook #2 "batch" job
- Notebook #2 "interactive" job

## Prerequisites

- Cluster setup steps 0 - 10 are completed (Refer [Here](/README.md) for details)

## Steps

- [ ] Run the following command:

```sh
oc adm policy add-role-to-group edit system:serviceaccounts:sandbox -n sandbox
```

- [ ] Access the RHOAI Dashboard
- [ ] Access the `sandbox` project
- [ ] Create a workbench using the `Standard Data Science` notebook and set the following environment variables as Secrets (see [instructions](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/2.13/html/working_on_data_science_projects/using-project-workbenches_projects#creating-a-project-workbench_projects) if needed):
  1. `ACCESS_KEY` = `rootuser`
  1. `SECRET_KEY` = `rootuser123`
  1. `ENDPOINT_URL` = `http://minio.minio:9000`

> [!NOTE]
> TODO: Add a Gif for this

- [ ] In the JupyterLab interface, click "Git" > "Clone a Repository"
- [ ] In the "Clone a repo" dialog, enter `https://github.com/redhat-na-ssa/codeflare-sdk`
- [ ] In the JupyterLab interface, in the left navigation pane, double-click the `codeflare-sdk` folder.
- [ ] Double-click the `demo-notebooks` folder.
- [ ] Double-click the `guided-demos` folder.
- [ ] Execute the notebooks in order:
  1. `0_basic_ray.ipynb`
  1. `1_cluster_job_client.ipynb`

> Note: To run `2_basic_interactive.ipynb`, follow below additional steps

- [ ] Create project and set environment variables

```sh
oc new-project minio
MINIO_ROOT_USER=rootuser
MINIO_ROOT_PASSWORD=rootuser123
```

- [ ] Install MinIO helm chart

```sh
helm repo add minio https://charts.min.io/
```

- [ ] Deploy MinIO storage in its own namespace with a bucket for distributed workloads

```sh
helm install minio --namespace minio --set replicas=1 --set persistence.enabled=false --set mode=standalone --set rootUser=$MINIO_ROOT_USER,rootPassword=$MINIO_ROOT_PASSWORD --set 'buckets[0].name=distributed-demo,buckets[0].policy=none,buckets[0].purge=false' minio/minio
```

> [!NOTE]
> You may have to pip install the codeflare_sdk if not provided with the Notebook Image.
> `!pip install codeflare_sdk -q`
