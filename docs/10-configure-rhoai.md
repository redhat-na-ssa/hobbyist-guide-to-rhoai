# 10. Administrative Configurations for RHOAI

### 10.1 Ensure you have an Accelerator Profile

[Enabling GPU support in RHOAI](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/2.10/html/Install_and_unInstall_openshift_ai_self-managed/enabling-gpu-support_install)

### Steps

- [ ] Ensure that you have an Accelerator Profile for your Nvidia GPU

```sh
oc get acceleratorprofile -n redhat-ods-applications migrated-gpu -oyaml
```

- [ ] Verify the `taints` key set in your Node / MachineSets match the tolerations key set in your `Accelerator Profile`.

```sh
oc get node -l nvidia.com/gpu.machine -ojsonpath='{range .items[0].spec.taints[*]}{.key}{"\n"}{end}'
```

> [!NOTE]
> If the taint keys do not match, you can either edit the AcceleratorProfile or, if no AcceleratorProfile was present at all you can trigger redection by the RHOAI Console. See the steps [here](/docs/info-regenerate-accelerator-profiles.md) for the procedure to do this.

### 10.2 Increasing your non-GPU compute capacity

Some of the workloads that we deploy in the following sections may require more CPU than your cluster has available on non-GPU nodes, if you followed the recommendations in the prerequisites. Scaling your non-GPU MachineSets will enable these workloads to schedule properly

### Steps

- [ ] Verify that you have a non-GPU Worker MachineSet configured. This MachineSet may have zero desired replicas, if you followed the cluster provisioning guidance.

```sh
oc get machineset -n openshift-machine-api
```

```sh
# expected output
NAME                                        DESIRED   CURRENT   READY   AVAILABLE   AGE
cluster-qcrdx-dkqx2-gpu-worker-us-east-2a   2         2         2       2           3h52m
cluster-qcrdx-dkqx2-worker-us-east-2a       0         0                             5h24m
```

- [ ] Either copy the name of the non-GPU MachineSet you want to scale, or run the following command if you have the tooling available

```sh
machineset=$(oc get machineset -n openshift-machine-api -ojson | jq -r '.items[] | select(.metadata.name | contains("gpu") | not) | .metadata.name' | head -1)
```

- [ ] Scale the MachineSet with the following command, or scale it in the web console

```sh
oc scale machineset --replicas=1 -n openshift-machine-api $machineset
```

### 10.3 Add serving runtime

### Steps

- From RHOAI, Settings > Serving runtimes > Click Add Serving Runtime.

  **Option 1 (manual)**:

  - Select `Multi-model serving`
  - Select `Start from scratch`
  - Review, Copy and Paste in the content from `configs/10/rhoai-add-serving-runtime.yaml`
  - Add and confirm the runtime can be selected in a Data Science Project

  **Option 2**:

  - ```sh
    oc apply -f configs/10/rhoai-add-serving-runtime-template.yaml -n redhat-ods-applications
    ```

  - Add and confirm the runtime can be selected in a Data Science Project

#### User Management

- Data scientists
- Administrators

### 10.4 Configuring Data Science Pipelines

##### Configure External DB

When a pipeline server is configured for a Data Science Project, a local database using MariaDB is automatically configured for the pipelines. This database is local to the project and not intended for reuse.

Instead, the best practice is to configure an external SQL database for the pipeline server. Let's configure an external database for pipelines.

Create a new project for the database

```sh
oc new-project database
```

Create database

> [!NOTE]
> The pipeline server's metadata service uses a client that _cannot_ handle the default `caching_sha2_password` authentication method in MySQL 8+. You must enable the older `mysql_native_password` authentication method in the MySQL server.

> [!NOTE]
> Also note that MySQL v9 will not work with Data Science Pipelines because the `mysql_native_password` authentication method has been fully deprecated and removed. See this [blog post](https://blogs.oracle.com/mysql/post/mysql-90-its-time-to-abandon-the-weak-authentication-method) for more details.

```sh
MYSQL_USER=user
MYSQL_PASSWORD=user123
MYSQL_DATABASE=pipelines
oc new-app -i mysql:8.0-el9 -e MYSQL_DEFAULT_AUTHENTICATION_PLUGIN=mysql_native_password -e MYSQL_DATABASE=$MYSQL_DATABASE -e MYSQL_USER=$MYSQL_USER -e MYSQL_PASSWORD=$MYSQL_PASSWORD
```

Wait for the database to install

```sh
oc wait --for=jsonpath='{.status.replicas}'=1 deploy mysql -n database
```

Object storage is also needed for pipelines. Create a project and set env vars.

```sh
oc new-project minio
MINIO_ROOT_USER=rootuser
MINIO_ROOT_PASSWORD=rootuser123
```

Install MinIO helm chart

```sh
helm repo add minio https://charts.min.io/
```

Deploy MinIO storage in its own namespace with a bucket for pipelines

```sh
helm install minio --namespace minio --create-namespace --set replicas=1 --set persistence.enabled=false --set mode=standalone --set rootUser=$MINIO_ROOT_USER,rootPassword=$MINIO_ROOT_PASSWORD --set 'buckets[0].name=pipeline-artifacts,buckets[0].policy=none,buckets[0].purge=false' minio/minio
```

Create data science projects

```sh
oc new-project pipeline-test
oc label ns pipeline-test opendatahub.io/dashboard=true
```

Create required secrets for pipeline server

```sh
oc create secret generic dbpassword --from-literal=dbpassword=$MYSQL_PASSWORD -n pipeline-test
oc create secret generic dspa-secret --from-literal=AWS_ACCESS_KEY_ID=$MINIO_ROOT_USER --from-literal=AWS_SECRET_ACCESS_KEY=$MINIO_ROOT_PASSWORD -n pipeline-test
```

Create the pipeline server

> [!NOTE]
> The sample MySQL deployment does not have SSL configured so we need to add a `customExtraParams` field to disable the tls check. For a production MySQL deployment, you can remove this parameter to enable the tls check.

```sh
oc apply -f configs/10/rhoa-test-pipeline-server.yaml
```

The pipeline server was configured with an example pipeline using the parameter `enableSamplePipeline`.

Navigate to RHOAI dashboard -> Data Science Pipelines -> Project `pipeline-test`

You should see the `iris-training` pipeline and be able to execute a pipeline run.

### Review Backing up data

Refer to [A Guide to High Availability / Disaster Recovery for Applications on OpenShift](https://www.redhat.com/en/blog/a-guide-to-high-availability/disaster-recovery-for-applications-on-openshift)

#### Control plane backup and restore operations

You must [back up etcd](https://docs.openshift.com/container-platform/4.15/backup_and_restore/control_plane_backup_and_restore/backing-up-etcd.html#backup-etcd) data before shutting down a cluster; etcd is the key-value store for RHOCP, which persists the state of all resource objects.

#### Application backup and restore operations

The OpenShift API for Data Protection (OADP) product safeguards customer applications on RHOCP. It offers comprehensive disaster recovery protection, covering RHOCP applications, application-related cluster resources, persistent volumes, and internal images. OADP is also capable of backing up both containerized applications and virtual machines (VMs).

However, OADP does not serve as a disaster recovery solution for [etcd](https://docs.openshift.com/container-platform/4.15/backup_and_restore/control_plane_backup_and_restore/backing-up-etcd.html#backup-etcd) or OpenShift Operators.

## Automation key (Catch up)

- From this repository's root directory, run below command

  - ```sh
    ./scripts/setup.sh -s 10
    ```
