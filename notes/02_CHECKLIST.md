# Notes

This is checklist of the technical steps needed to complete the installation and configuration of Red Hat OpenShift and it's dependencies for use.

- [ ] Install the `Red Hat OpenShift AI Operator (RHOAI)`
  - [ ] Access the cluster via your client CLI
  - [ ] Add administrative users
  - [ ] (Optional) Install the `Web Terminal Operator`
  - [ ] Install RHOAI Dependencies
    - [ ] Install `RHOAI KServe` dependencies
      - [ ] Install `Red Hat OpenShift Service Mesh Operator`
      - [ ] Install `Red Hat OpenShift Serverless Operator`
      - [ ] Install `Red Hat Authorino Operator`
  - [ ] Install the `RHOAI Operator` by using the CLI
    - [ ] Install and managing Red Hat OpenShift AI components
  - [ ] Adding a CA bundle
  - [ ] (Optional) Configure the OpenShift AI Operator logger
  - [ ] Enabling GPU support for OpenShift AI
    - [ ] Adding a GPU node to an existing RHOCP
    - [ ] Deploying the `Red Hat Node Feature Discovery (NFD) Operator`
    - [ ] Install the `NVIDIA GPU Operator`
      - [ ] GPU Node Role Label
    - [ ] (Optional) Running a sample GPU Application
    - [ ] Enabling the GPU Monitoring Dashboard
    - [ ] Install the NVIDIA GPU administration dashboard
      - [ ] Viewing the GPU Dashboard
    - [ ] GPU sharing methods
    - [ ] Configure NVIDIA GPUs with time slicing
    - [ ] Configure Taints and Tolerations
    - [ ] (Optional) Configure the cluster autoscaler
  - [ ] Configure distributed workloads
    - [ ] Configure quota management for `RHOAI Distributed Workloads`
      - [ ] Create an empty Kueue resource flavor
      - [ ] Create a cluster queue to manage the empty Kueue resource flavor
      - [ ] Create a local queue that points to your cluster queue
    - [ ] (Optional) Configure the CodeFlare Operator (~5min)
  - [ ] Administrative Configurations for RHOAI
    - [ ]  Review RHOAI Dashboard Settings
      - [ ] Notebook Images
      - [ ] Accelerator Profiles
      - [ ] Add a new Accelerator Profile
      - [ ] Serving Runtimes
        - [ ] Add serving runtime
      - [ ] User Management
    - [ ]  Review Backing up data
      - [ ] Control plane backup and restore operations
      - [ ] Application backup and restore operations
  - [ ] Answer key

## Administrative Configurations for RHOAI

- [ ] Review RHOAI Dashboard Settings
  - [ ] Notebook Images
  - [ ] Custom Images
  - [ ] Cluster Settings
    - [ ] Model Serving Platforms
    - [ ] PVC Size
    - [ ] Stop Idle Notebooks
    - [ ] Usage Data Collection
    - [ ] Notebook Pod Toleration
  - [ ] Accelerator Profiles
    - [ ] Add a new Accelerator Profile (~3min)
  - [ ] Serving Runtimes
    - [ ] Add a new Serving Runtimes
  - [ ] User Management
    - [ ] Configure User and Admin groups
- [ ] Review Backing up data
  - [ ] Control plane backup and restore operations
  - [ ] Application backup and restore operations

## Tutorials

- [ ] Demonstrate Fraud Detection Dem
  - [ ] Create workbench
  - [ ] Clone in repo
  - [ ] Train model
  - [ ] Store model
  - [ ] Deploy the model on a single-model server
  - [ ] Deploy the model on a multi-model server
  - [ ] Configure Token authorization w/ service account
  - [ ] Test the inference API via Terminal
  - [ ] Build training with Elyra
    - [ ] Schedule the pipeline to run once
    - [ ] Schedule the pipeline to run on a schedule
  - [ ] Build training with kfp SDK
    - [ ] Import Pipeline coded with kfp SDK
- [ ] Demonstrate Distributed Workloads Demo
  - [ ] Access the RHOAI Dashboard
  - [ ] Create a workbench
  - [ ] Clone in the codeflare-sdk github repo
  - [ ] Navigate to the guided-demos
  - [ ] Update the notebook import, auth, cluster values
  - [ ] Access the RayCluster Dashboard
  - [ ] complete the `0_basic_ray.ipynb`
  - [ ] complete the `1_cluster_job_client.ipynb`
  - [ ] complete the `2_basic_interactive.ipynb`
