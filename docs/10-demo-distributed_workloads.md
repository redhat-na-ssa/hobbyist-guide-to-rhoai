# 10. Demo - Distributed Workloads

### Objectives

- Demo to showcase distributed workloads on OpenShift AI

### Rationale

- Distributed workloads enable data scientists to use multiple cluster nodes in parallel for faster and more efficient data processing and model training.
- The CodeFlare framework simplifies task orchestration and monitoring, and offers seamless integration for automated resource scaling and optimal node utilization with advanced GPU support.
  [More Info](https://access.redhat.com/documentation/en-us/red_hat_openshift_ai_self-managed/2.10/html/working_with_distributed_workloads/running-distributed-workloads_distributed-workloads)

### Takeaways

- Distributed Workloads functionalities of RHOAI enable use of many resources and large amounts of chunked work
- Multi-tenancy and smart resource utilization is built into the multi-stage scheduler design
- Distributed workloads can be interacted with by submitting jobs, including through the Kubernetes API, or by interactively working within Python code
- S3-compatible object storage facilitates synchronizing work across multiple workers and should be expected to be available for these use cases

## Prerequisites

- Cluster setup steps 0 - 9 are completed

## 10.1 Configuring the demo workbench

## Steps

- [ ] Run the following command to enable in-cluster authentication for workbench ServiceAccounts:

      oc adm policy add-role-to-group edit system:serviceaccounts:sandbox -n sandbox

> Expected output
>
> `Warning: Group 'system:serviceaccounts:sandbox' not found`\
> `clusterrole.rbac.authorization.k8s.io/edit added: "system:serviceaccounts:sandbox"`

- [ ] Access the RHOAI Dashboard by clicking the grid of 9 squares in the top right of the OpenShift Console and Selecting `Red Hat OpenShift AI`
- [ ] Access the `sandbox` project - it may be on the second page, requiring you to use the page selectors at the bottom of the page
- [ ] Navigate to the `Workbenches` tab at the top of the project interface
- [ ] Create a workbench using the blue `Create workbench` button in the top right with the following settings
  - [ ] You may type any name you like
  - [ ] Select the `Standard Data Science` Notebook image, and ensure that the `Version selection` field (which auto-populates after selecting the image) says `2024.1`
  - [ ] Leave `Container size` set to `Small` as we will be using minimal resources for Jupyter and letting Ray consume the bulk of our resources
  - [ ] Leave `Accelerator` unset, reading `Select...` as we will be using Ray to manage our workload accelerators
  - [ ] Leave the `Cluster storage` section with its defaults of `20 Gi` of storage, named similarly to your workbench instance
  - [ ] Check the box to use a `Data connection`, leave the radio button set to `Create new data connection`, and use the following options to align with the MinIO configuration we set up in section `8: Administrative Configurations for RHOAI` If you deviated from those values, set them appropriately here
    1. `Name` = `minio`
    1. `Access key` = `rootuser`
    1. `Secret Key` = `rootuser123`
    1. `Endpoint` = `http://minio.minio.svc:9000`
    1. Leave the remaining fields blank

> [!NOTE]
> TODO: Add a gif for this

- [ ] When your workbench shows `Running` in the `Status` column, the `Open` hyperlink should be clickable. Click it, log in, and approve the requested permissions.
- [ ] In the JupyterLab interface, click the `Git` log in the left navigation bar (it's the third one down, below the square-in-circle icon) and select `Clone a Repository`
- [ ] In the "Clone a repo" dialog, enter the following URI:

      https://github.com/redhat-na-ssa/codeflare-sdk

- [ ] In the JupyterLab interface, in the left navigation pane, double-click the `codeflare-sdk` folder.
- [ ] Double-click the `demo-notebooks` folder.
- [ ] Double-click the `guided-demos` folder.
- [ ] Double-click the first notebook, `0_basic_ray.ipynb`, in order to open it in the editor.
- [ ] Execute the cells of the notebook. You can either click into the first cell to select it, then press `Shift + Enter` to execute the cell and select the next cell (allowing you to run the cells one at a time), or click the Fast Forward (⏩) button at the top of the notebook interface and follow the cells down.
  - This notebook shows that you can create a Ray cluster on top of OpenShift, and allows you to understand the basics of how the CodeFlare SDK interacts with KubeRay

> [!NOTE]
> The `[*]` indicator to the left of a cell means it's waiting to start or complete execution. The indicator will change to a number, like `[5]` on `cluster.status()` in this notebook if you used the ⏩ button and came back to read this note, when it has completed execution. The numbers indicate the order that the cell was executed in Python.

## 10.2 Running the distributed workloads demos

> [!IMPORTANT]
> In the cluster_job_client workbench, if your RayCluster does not come ready and hangs on the cell that says `cluster.wait_ready()` on the last line, you can check the pods in your Sandbox namespace to see if they are stuck in a `Pending` state due to an untolerated taint. If it does, you'll need to restart the Kueue controller in the `redhat-ods-applications` namespace by deleting the pod. For more information about this behavior, see [this docs link](https://kueue.sigs.k8s.io/docs/tasks/run/rayclusters/#before-you-begin).

- [ ] If you're running 1_cluster_job_client and you're in the above situation, run the following to confirm that your RayCluster isn't hung up

      oc get pod -n sandbox -l ray.io/is-ray-node -ojsonpath='{range .items[0].status.conditions[*]}{.message}{"\n"}{end}' 2>/dev/null | grep 'untolerated'

  - [ ] If, and only if, the above returns a line showing that the GPU taint was untolerated, should you bounce the Kueue pod using the following command (no copy block to prevent mistakes!)
    - `oc delete pod -n redhat-ods-applications -l app.opendatahub.io/kueue`

## Steps

- [ ] Run the following notebooks, reading the notes and text as you go, and understanding the code blocks as they are executed alongside their output. If you have questions, your presenter should be able to help.

1. `1_cluster_job_client.ipynb`
   - This notebook shows you how Ray can be used for more interesting distributed work on OpenShift. A cluster is defined in basic Python code, and when it's ready a job is submitted to the cluster. That job builds a simple neural network using the MNIST Fashion data set to identify the type of clothing depicted in a picture (e.g. purse, jacket, etc.). It may take a few minutes to complete, as it is an actual distributed ML training interaction.
1. `2_basic_interactive.ipynb`
   - This notebook is designed to show you how interaction with a Ray job can live entirely inside of Python code, rather than Python submissions to the Ray cluster job queue via the SDK. Although the notebook is structured to instantiate the cluster, confirm it's running, and then bring it down before beginning the interactive session, any Python code that defines the cluster could be used to interactively submit Python code to the cluster from a Notebook, other IDE, or even an interactive local Python session. Note that when you execute this notebook, the Data Connection that you associated with the workbench is consumed to construct the `minio_storage_path` variable used for shared cluster checkpoint storage later on, with a new bucket created to enable it. While the cell with `ray.get(train_fn.remote())` is running, before executing `cluster.down()`, you should be able to interact with the Ray dashboard linked in the notebook on either the `cluster.details()` cell output or the one that specifically outputs the `cluster_dashboard_uri`. The `Actors` tab of the Ray dashboard contains information from the `RayTrainWorker` instances that you're interacting with remotely, including their logs.
   - The aggregated logs from your interactive run will appear in the cell output for which you ran `ray.init`, not the `ray.get` call that is blocking waiting on your remote Ray function definition. You'll probably have a better experience working with the Ray dashboard in the `Actors` tab than trying to use Jupyter notebooks, as the logs for each Ray cluster worker are mixed together.
1. `3_interactive_tune.ipynb`
   - This notebook demonstrates several interesting topics for working with Ray in OpenShift AI. The first is our interactive session, like the last one, that operates in real time against the Ray cluster. The second is the use of a gradient boosting framework, XGBoost, for hyperparameter tuning (that is, manipulating the variables that are provided to a training framework to identify the variables on the model training functions that are the most ideal for training a machine learning model with our dataset, within a parameter space). The third is the use of Kueue and Ray for two-stage scheduling. Our RayCluster needed all resources to be available at the Kubernetes API level before it would schedule and become ready. Once our RayCluster had reserved a subset of our cluster's resources (configured via the `ResourceFlavor`, `ClusterQueue`, and `LocalQueue` we created in step 9), we configured our Ray `Tuner` to run three separate trials of the same training job with 3 workers each for multiple samples each. Ray's second stage of scheduling worked to enable us to fit these many runs together in batches of three, with up to two trials running simultaneously, onto a Ray cluster with 4 worker GPUs total.
   - This tuning job doesn't issue a lot of logs in the Ray dashboard while it's in process. You can expect the output in the notebook, once again below the cell were `ray.init` was called, after the trials get to saving their checkpoints.
