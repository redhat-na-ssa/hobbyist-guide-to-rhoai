## Running distributed data science workloads from notebooks

[source](https://access.redhat.com/documentation/en-us/red_hat_openshift_ai_self-managed/2.10/html/working_with_distributed_workloads/running-distributed-workloads_distributed-workloads)

### Prerequisite

* You created a project called `sandbox` following [this section](https://github.com/redhat-na-ssa/hobbyist-guide-to-rhoai/blob/sa-bootcamp/notes/03_CHECKLIST_PROCEDURE.md#optional-running-a-sample-gpu-application).

* You created a resource flavor, cluster queue, and a local queue in project `sandbox` following [this section](https://github.com/redhat-na-ssa/hobbyist-guide-to-rhoai/blob/sa-bootcamp/notes/03_CHECKLIST_PROCEDURE.md#configure-quota-management-for-distributed-workloads).

### Permissions

Allow service accounts in the sandbox project to edit resources.

```sh
oc adm policy add-role-to-group edit system:serviceaccounts:sandbox -n sandbox
```

### Create shared storage


### Launch notebooks

1. Access the RHOAI Dashboard
1. Access the `sandbox` project
1. Create a workebench using the `Standard Data Science` notebook
1. In the JupyterLab interface, click Git > Clone a Repository
1. In the "Clone a repo" dialog, enter `https://github.com/redhat-na-ssa/codeflare-sdk`
1. In the JupyterLab interface, in the left navigation pane, double-click codeflare-sdk.
1. Double-click demo-notebooks.
1. Double-click guided-demos.
1. Execute the notebooks in order
1. `0_basic_ray.ipynb`
1. `1_cluster_job_client.ipynb`
1. `2_basic_interactive.ipynb`
