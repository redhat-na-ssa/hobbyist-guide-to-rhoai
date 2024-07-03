# Notes

This is checklist of the technical steps needed to complete the installation and configuration of Red Hat OpenShift 2.9 and it's dependencies for use.

## Installing the Red Hat OpenShift AI "RHOAI" Operator

- [ ] (Optional) Install the Web Terminal Operator
  - [ ] 
- [ ] Installing the Red Hat OpenShift AI Operator
  - [ ] Adding administrative users for OpenShift Container Platform (~8 min)
  - [ ] Installing the Red Hat OpenShift AI Operator by using the CLI (~3min)
  - [ ] Installing and managing Red Hat OpenShift AI components (~1min)
  - [ ] Adding a CA bundle (~5min)
  - [ ] Installing KServe dependencies (~3min)
    - [ ] Creating a Knative Serving instance
    - [ ] Creating secure gateways for Knative Serving (~4min)
  - [ ] Manually adding an authorization provider (~4min)
    - [ ] Configuring an OpenShift Service Mesh instance to use Authorino (~6min)
    - [ ] Configuring authorization for KServe (~3min)
  - [ ] Enabling GPU support in OpenShift AI
    - [ ] Adding a GPU node to an existing OpenShift Container Platform cluster (~12min)
    - [ ] Deploying the Node Feature Discovery Operator (~12-30min)
    - [ ] Installing the NVIDIA GPU Operator (~10min)
    - [ ] (Optional) Running a sample GPU Application (~1min)
    - [ ] Enabling the GPU Monitoring Dashboard (3min)
    - [ ] Installing the NVIDIA GPU administration dashboard (~5min)
    - [ ] Configuring GPUs with time slicing (~3min)
    - [ ] Configure Taints and Tolerations (~3min)
    - [ ] (Optional) Configuring the cluster autoscaler
  - [ ] Configuring distributed workloads
    - [ ] Configuring quota management for distributed workloads (~5min)
    - [ ] (Optional) Configuring the CodeFlare Operator (~5min)

## Administrative Configurations for RHOAI

- [ ] Review RHOAI Dashboard Settings
  - [ ] Notebook Images
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