# 8. Administrative Configurations for RHOAI / Data Science Pipelines

<p align="center">
<a href="/docs/07-install-rhoai-operator.md">Prev</a>
&nbsp;&nbsp;&nbsp;
<a href="/docs/09-configure-distributed-workloads.md">Next</a>
</p>

### Objectives

- Ensure that OpenShift AI workload-related dependencies are configured
- Ensure that the OpenShift AI cluster is prepared for data scientist personas to operate on it

### Rationale

- OpenShift AI is not an all-inclusive platform in and of itself that has everything you need to get moving without configuration
- Some organizations may prefer to perform additional customization of their cluster before onboarding data science users

### Takeaways

- Installing OpenShift AI is not the last step in preparing for data science users

## 8.1 Ensure you have an Accelerator Profile

### Objectives

- Ensure that OpenShift AI workloads are able to consume the GPUs in your cluster

### Rationale

- RHOAI may or may not automatically detect your GPUs. The order you configure these components in matters.

### Takeaways

- How RHOAI detects GPUs
- How GPUs are configured for easy consumption in the RHOAI web UI
- [More Info](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/2.13/html/working_with_accelerators/overview-of-accelerators_accelerators)

## Steps

- [ ] Ensure that you have an Accelerator Profile for your Nvidia GPU

      oc get acceleratorprofile -n redhat-ods-applications migrated-gpu -ojsonpath='{range .spec.tolerations[*]}{.key}{"\n"}{end}'

> Expected output
>
> `nvidia.com/gpu`

- [ ] Verify the `taints` key set in your Node / MachineSets match the tolerations key set in your `Accelerator Profile`.

      oc get node -l nvidia.com/gpu.machine -ojsonpath='{range .items[0].spec.taints[*]}{.key}{"\n"}{end}'

> Expected output
>
> `nvidia.com/gpu`

> [!NOTE]
> If the taint keys do not match, you can either edit the AcceleratorProfile or, if no AcceleratorProfile was present at all you can trigger regeneration by the RHOAI Console. See the steps [here](/docs/info-regenerate-accelerator-profiles.md) for the procedure to do this.

## 8.2 Increasing your non-GPU compute capacity

### Objectives

- Ensure that you have enough resources to run the prerequisite infrastructure to support overall RHOAI workloads

### Rationale

- The cluster configuration up to this point is likely going to be insufficient to run additional workloads like the OpenShift AI Data Science Pipelines server and its database, and an object storage provider to support various use cases

### Takeaways

- Some of the workloads that we deploy in the following sections may require more CPU than your cluster has available on non-GPU nodes, if you followed the recommendations in the prerequisites
- Scaling your non-GPU MachineSets will enable these workloads to schedule properly

## Steps

- [ ] Verify that you have a non-GPU Worker MachineSet configured. This MachineSet may have zero desired replicas, if you followed the cluster provisioning guidance.

      oc get machineset -n openshift-machine-api

> Expected output
>
> `NAME                                        DESIRED   CURRENT   READY   AVAILABLE   AGE`\
> `cluster-xxxxx-xxxxx-gpu-worker-us-east-2a   2         2         2       2           3h52m`\
> `cluster-xxxxx-xxxxx-worker-us-east-2a       0         0                             5h24m`

- [ ] Either copy the name of the non-GPU MachineSet you want to scale, or run the following command if you have the tooling available

      machineset=$(oc get machineset -n openshift-machine-api -ojson | jq -r '.items[] | select(.metadata.name | contains("gpu") | not) | .metadata.name' | head -1)

- [ ] Scale the MachineSet with the following command, or scale it in the web console

      oc scale machineset --replicas=1 -n openshift-machine-api $machineset

> Example output
>
> `machineset.machine.openshift.io/cluster-5mgxv-42f4t-worker-us-east-2b scaled`

## 8.3 Add a custom serving runtime

### Objectives

- Enable using the Model Serving functionality with OpenShift AI using runtimes other than those that are supported by Red Hat directly as components of RHOAI

### Rationale

- Many users of OpenShift AI will require serving functionality or optimizations beyond those we provide and support.

### Takeaways

- OpenShift AI has out-of-the-box serving runtimes that are fully supported by Red Hat, but the model serving frameworks are useful well beyond those supported runtimes
- Serving runtimes may contain optimizations for hardware or model frameworks that are useful to leverage, even if they're not explicitly supported by Red Hat
- GitOps-based processes can define approved serving runtimes for data scientist or MLOps users to self-service

## Steps

**Option 1 (manual)**:

- From RHOAI, Settings > Serving runtimes > Click Add Serving Runtime.
- Select `Multi-model serving`
- Select `Start from scratch`
- Review, Copy and Paste in the content from `configs/08/other/rhoai-add-serving-runtime.yaml`
- Add and confirm the runtime can be selected in a Data Science Project

**Option 2**:

    oc apply -f configs/08/rhoai-add-serving-runtime-template.yaml -n redhat-ods-applications

> Expected output
>
> `template.template.openshift.io/triton created`

## Validation

- Open the OpenShift AI dashboard
- Navigate to a Data Science Project (such as `sandbox`)
- Navigate to the `Models` tab of the project
- Deploy a model server using the `Multi-model serving platform` by clicking the `Add model server` button
- Grab the pulldown for `Serving runtime` and confirm that `Nvidia Triton Model Server` is visible from the options

## 8.4 Configuring Data Science Pipelines

### Objectives

- Configure an external database for use with Data Science Pipelines
- Configure Object Storage in support of Data Science Pipelines (which we will reuse for other things that require it)

### Rationale

- Best practice for Data Science Pipelines is to use an external high-availability database. Our example here is to demonstrate, using a non-HA database, how that might be accomplished
- Data Science Pipelines uses object storage to pass information between stages

### Takeaways

- Not all RHOAI systems inherit high availability from the cluster automatically
- Object Storage should be considered a basic requirement of most RHOAI use cases
- Amazon S3, OpenShift Data Foundations' Multi-Cloud Object Gateway or Ceph Rados Gateway, and partner solutions such as MinIO or Dell's PowerScale (formerly Isilon) solutions all present S3-compatible APIs suitable for use with OpenShift AI

## Steps

- [ ] Create a new project for the database

      oc project database || oc new-project database

> Expected output
>
> `Now using project "database" on server "https://api.cluster-5mgxv.5mgxv.sandbox3005.opentlc.com:6443".`

- [ ] Create the database instance

> [!NOTE]
> The pipeline server's metadata service uses a client that _cannot_ handle the default `caching_sha2_password` authentication method in MySQL 8+. You must enable the older `mysql_native_password` authentication method in the MySQL server.

> [!WARNING]
> MySQL v9+ will not work with Data Science Pipelines because the `mysql_native_password` authentication method has been fully deprecated and removed. See this [blog post](https://blogs.oracle.com/mysql/post/mysql-90-its-time-to-abandon-the-weak-authentication-method) for more details.

    MYSQL_USER=user
    MYSQL_PASSWORD=user123
    MYSQL_DATABASE=pipelines

    oc new-app mysql \
      -i mysql:8.0-el9 \
      -e MYSQL_DEFAULT_AUTHENTICATION_PLUGIN=mysql_native_password \
      -e MYSQL_DATABASE=$MYSQL_DATABASE \
      -e MYSQL_USER=$MYSQL_USER \
      -e MYSQL_PASSWORD=$MYSQL_PASSWORD

> Expected output
>
> `--> Found image cd3719d (3 weeks old) in image stream "openshift/mysql" under tag "8.0-el9" for "mysql:8.0-el9"`
>
> `    MySQL 8.0`\
> `    ---------`\
> `    MySQL is a multi-user, multi-threaded SQL database server. The container image provides a containerized packaging of the MySQL mysqld daemon and client application. The mysqld server daemon accepts connections from clients and provides access to content from MySQL databases on behalf of the clients.`
>
> `    Tags: database, mysql, mysql80, mysql-80`
>
> `--> Found image 8fcde26 (7 days old) in image stream "openshift/mysql" under tag "8.0-el8" for "mysql"`
>
> `    MySQL 8.0`\
> `    ---------`\
> `    MySQL is a multi-user, multi-threaded SQL database server. The container image provides a containerized packaging of the MySQL mysqld daemon and client application. The mysqld server daemon accepts connections from clients and provides access to content from MySQL databases on behalf of the clients.`
>
> `    Tags: database, mysql, mysql80, mysql-80`
>
> `--> Creating resources ...`\
> `    deployment.apps "mysql" created`\
> `    deployment.apps "mysql-1" created`\
> `    service "mysql" created`\
> `    service "mysql-1" created`\
> `--> Success`\
> `    Application is not exposed. You can expose services to the outside world by executing one or more of the commands below:`\
> `     'oc expose service/mysql'`\
> `     'oc expose service/mysql-1'`\
> `    Run 'oc status' to view your app.`

- [ ] Wait for the database to install

      oc wait --for=jsonpath='{.status.replicas}'=1 deploy mysql -n database

> Expected output
>
> `deployment.apps/mysql condition met`

- [ ] Create a project for MinIO and set env vars.

      oc new-project minio
      MINIO_ROOT_USER=rootuser
      MINIO_ROOT_PASSWORD=rootuser123

> Expected output
>
> `Now using project "minio" on server "https://api.cluster-5mgxv.5mgxv.sandbox3005.opentlc.com:6443".`
>
> `You can add applications to this project with the 'new-app' command. For example, try:`
>
> `    oc new-app rails-postgresql-example`
>
> `to build a new example application in Ruby. Or use kubectl to deploy a simple Kubernetes application:`
>
> `    kubectl create deployment hello-node --image=registry.k8s.io/e2e-test-images/agnhost:2.43 -- /agnhost serve-hostname`

- [ ] Configure the MinIO Helm repository

      helm repo add minio https://charts.min.io/

> Expected output
>
> `"minio" has been added to your repositories`
>
> Or, potentially
>
> `"minio" already exists with the same configuration, skipping`

- [ ] Deploy MinIO via the Helm chart in its own namespace with a bucket for pipelines

      helm install minio \
        --namespace minio \
        --create-namespace \
        --set replicas=1 \
        --set persistence.enabled=false \
        --set mode=standalone \
        --set rootUser=$MINIO_ROOT_USER,rootPassword=$MINIO_ROOT_PASSWORD \
        --set 'buckets[0].name=pipeline-artifacts,buckets[0].policy=none,buckets[0].purge=false' \
        minio/minio

> Expected output
>
> `NAME: minio`\
> `LAST DEPLOYED: Fri Oct 11 15:23:20 2024`\
> `NAMESPACE: minio`\
> `STATUS: deployed`\
> `...`

- [ ] Create data science projects for use with these pipelines

      oc new-project pipeline-test
      oc label ns pipeline-test opendatahub.io/dashboard=true

> Expected output
>
> `Now using project "pipeline-test" on server "https://api.cluster-5mgxv.5mgxv.sandbox3005.opentlc.com:6443".`
>
> `You can add applications to this project with the 'new-app' command. For example, try:`
>
> `    oc new-app rails-postgresql-example`
>
> `to build a new example application in Ruby. Or use kubectl to deploy a simple Kubernetes application:`
>
> `    kubectl create deployment hello-node --image=registry.k8s.io/e2e-test-images/agnhost:2.43 -- /agnhost serve-hostname`

- [ ] Create required secrets for pipeline server

      oc create secret generic dbpassword --from-literal=dbpassword=$MYSQL_PASSWORD -n pipeline-test
      oc create secret generic dspa-secret --from-literal=AWS_ACCESS_KEY_ID=$MINIO_ROOT_USER --from-literal=AWS_SECRET_ACCESS_KEY=$MINIO_ROOT_PASSWORD -n pipeline-test

> Expected output
>
> `secret/dbpassword created`\
> `secret/dspa-secret created`

- [ ] Create the pipeline server

> [!NOTE]
> The sample MySQL deployment does not have SSL configured so we need to add a `customExtraParams` field to disable the TLS check. For a production MySQL deployment, you can remove this parameter to enable the TLS check.

    oc apply -f configs/08/rhoai-test-pipeline-server.yaml

> Expected output
>
> `datasciencepipelinesapplication.datasciencepipelinesapplications.opendatahub.io/dspa created`

> [!NOTE]
> The pipeline server was configured with an example pipeline using the parameter `enableSamplePipeline`.

## Validation

Navigate to RHOAI dashboard -> Data Science Pipelines -> Project `pipeline-test`

You should see the `iris-training` pipeline and be able to execute a pipeline run. Use the three dots menu on the right side of the pipeline to instantiate the run.

## Validation

![](/assets/08-validation.gif)

## Automation key (Catch up)

- [ ] From this repository's root directory, run below command

```sh
./scripts/setup.sh -s 8
```

<p align="center">
<a href="/docs/07-install-rhoai-operator.md">Prev</a>
&nbsp;&nbsp;&nbsp;
<a href="/docs/09-configure-distributed-workloads.md">Next</a>
</p>
