# Notes

This is checklist of the technical steps needed to complete the installation of Red Hat OpenShift 2.9

## Installing the Red Hat OpenShift AI "RHOAI" Operator

- [ ] Adding administrative users
- [ ] Installing the Red Hat OpenShift AI Operator by using the CLI
- [ ] Installing and managing Red Hat OpenShift AI components
- [ ] Adding a Certificate Authority bundle
- [ ] Installing KServe dependencies
  - [ ] Red Hat OpenShift Service Mesh
  - [ ] Red Hat Serverless Operator
  - [ ] Red Hat Authorino Operator
- [ ] Enabling GPU support in OpenShift AI
  - [ ] Adding a GPU node to an existing OpenShift Container Platform cluster
    - [ ] Node Feature Discovery Operator
    - [ ] NVIDIA GPU Operator
    - [ ] (Optional) Running a sample GPU Application
    - [ ] NVIDIA DCGM Exporter Dashboard
    - [ ] Configuring GPUs with time slicing
    - [ ] Configure Taints and Tolerations
    - [ ] (Optional) Configuring the cluster autoscaler
  - [ ] Configuring distributed workloads
    - [ ] Verify necessary pods are running
    - [ ] Configure quota management for distributed workloads
    - [ ] Review the CodeFlare operator configurations

## Administrative Configurations for RHOAI

- [ ] Create, push and import a custom notebook image
- [ ] Configure Cluster Settings
  - [ ] Model Serving Platforms
  - [ ] PVC Size
  - [ ] Stop Idle Notebooks
  - [ ] Usage Data Collection
  - [ ] Notebook Pod Toleration
- [ ] Add an Accelerator Profile
  - [ ] Delete the migration-gpu-status ConfigMap
  - [ ] Restart the dashboard replicaset
  - [ ] Check the acceleratorprofiles
- [ ] Add a new Serving Runtimes
- [ ] Configure User and Admin groups

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
  