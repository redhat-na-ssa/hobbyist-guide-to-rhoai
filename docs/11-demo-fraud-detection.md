# 11. Demo - Fraud Detection

<p align="center">
<a href="/README.md">Home</a>
</p>

In this tutorial, you learn how to incorporate data science and artificial intelligence and machine learning (AI/ML) into an OpenShift development workflow.

You will use an example fraud detection model to complete the following tasks:

- Explore a pre-trained fraud detection model by using a Jupyter notebook.
- Deploy the model by using OpenShift AI model serving.
- Refine and train the model by using automated pipelines.

[More Info](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/2.10/html/openshift_ai_tutorial_-_fraud_detection_example)

## Steps

- [ ] Create workbench
- [ ] Clone in repo
- [ ] Train model
- [ ] Store model
- [ ] Deploy the model on a single-model server
- [ ] Deploy the model on a multi-model server
- [ ] Configure Token authorization w/ service account
- [ ] Test the inference API via Terminal
- [ ] Build training with Elyra
  - Launch Elyra pipeline editor
  - Configure pipeline properties for the nodes
  - Drag the objects on the Elyra canvas
  - Configure the Node Properties for File Dependencies
  - Configure the data connection for the Node using Kubernetes Secrets
  - Execute the DAG from the pipeline editor
  - Inspect the Run Details
  - [ ] Schedule the pipeline to run once
  - [ ] Schedule the pipeline to run on a schedule
- [ ] Build training with kfp SDK
  - [ ] Import Pipeline coded with kfp SDK
