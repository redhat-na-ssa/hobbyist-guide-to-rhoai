# 10. Administrative Configurations for RHOAI

### 10.1 Add a new Accelerator Profile

[Enabling GPU support in RHOAI](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/2.10/html/Install_and_unInstall_openshift_ai_self-managed/enabling-gpu-support_install)

### Steps

- Go to RHOAI dashboard and check the **Settings > Accelerator profiles** - There should be none listed.

- Check the current configmap

  - ```sh
      oc get cm migration-gpu-status -n redhat-ods-applications -o yaml
    ```

    ```sh
    # expected output
    apiVersion: v1
    data:
    migratedCompleted: "true"
    kind: ConfigMap
    metadata:
      name: migration-gpu-status
      namespace: redhat-ods-applications
    ...
    ```

- Delete the migration-gpu-status ConfigMap

  - ```sh
      oc delete cm migration-gpu-status -n redhat-ods-applications
    ```

    ```sh
    # expected output
    configmap "migration-gpu-status" deleted
    ```

- Restart the dashboard replicaset

  - ```sh
      oc rollout restart deployment rhods-dashboard -n redhat-ods-applications
    ```

    ```sh
    # expected output
    deployment.apps/rhods-dashboard restarted
    ```

- Wait until the Status column indicates that all pods in the rollout have fully restarted

  - ```sh
      oc get pods -n redhat-ods-applications | egrep rhods-dashboard
    ```

    ```sh
    # expected output
    rhods-dashboard-69b9bc879d-k6gzb                                  2/2     Running   6                25h
    rhods-dashboard-7b67c58d9b-4xzr7                                  2/2     Running   0                67s
    rhods-dashboard-7b67c58d9b-chgln                                  2/2     Running   0                67s
    rhods-dashboard-7b67c58d9b-dk8sx                                  0/2     Running   0                7s
    rhods-dashboard-7b67c58d9b-tsngh                                  2/2     Running   0                67s
    rhods-dashboard-7b67c58d9b-x5v89                                  0/2     Running   0                7s
    ```

- Refresh the RHOAI dashboard and check the **Settings > Accelerator profiles** - There should be `NVIDIA GPU` enabled.

- Check the acceleratorprofiles

  - ```sh
      oc get acceleratorprofile -n redhat-ods-applications
    ```

    ```sh
    # expected output
    NAME           AGE
    migrated-gpu   83s
    ```

- Review the acceleratorprofile configuration

  - ```sh
      oc describe acceleratorprofile -n redhat-ods-applications
    ```

    ```sh
    # expected output
    Name:         migrated-gpu
    Namespace:    redhat-ods-applications
    Labels:       <none>
    Annotations:  <none>
    API Version:  dashboard.opendatahub.io/v1
    Kind:         AcceleratorProfile
    Metadata:
    Creation Timestamp:  2024-07-17T19:28:24Z
    Generation:          1
    Resource Version:    609012
    UID:                 8f64a27f-6593-43a6-873d-4796e920494f
    Spec:
    Display Name:  NVIDIA GPU
    Enabled:       true
    Identifier:    nvidia.com/gpu
    Tolerations:
        Effect:    NoSchedule
        Key:       nvidia.com/gpu
        Operator:  Exists
    Events:        <none>
    ```

- Verify the `taints` key set in your Node / MachineSets match your `Accelerator Profile`.

### 10.2 Add serving runtime

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

#### Pipelines

##### Configure External DB

When a pipeline server is configured for a Data Science Project, a local database using MariaDB is automatically configured for the pipelines. This database is local to the project and not intended for reuse.

Instead, the best practice is to configure an external SQL database for the pipeline server. Let's configure an external database for pipelines.

Create a new project for the database

```sh
oc new-project database
```

Create database

![NOTE]
The pipeline server's metadata service uses a client that _cannot_ handle the default `caching_sha2_password` authentication method in MySQL 8+. You must enable the older `mysql_native_password` authentication method in the MySQL server.

![NOTE]
Also note that MySQL v9 will not work with Data Science Pipelines because the `mysql_native_password` authentication method has been fully deprecated and removed. See this [blog post](https://blogs.oracle.com/mysql/post/mysql-90-its-time-to-abandon-the-weak-authentication-method) for more details.

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
helm install minio --namespace minio --set replicas=1 --set persistence.enabled=false --set mode=standalone --set rootUser=$MINIO_ROOT_USER,rootPassword=$MINIO_ROOT_PASSWORD --set 'buckets[0].name=pipeline-artifacts,buckets[0].policy=none,buckets[0].purge=false' minio/minio
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

![NOTE]
The sample MySQL deployment does not have SSL configured so we need to add a `customExtraParams` field to disable the tls check. For a production MySQL deployment, you can remove this parameter to enable the tls check.

```sh
cat <<EOF | oc apply -n pipeline-test -f -
apiVersion: datasciencepipelinesapplications.opendatahub.io/v1alpha1
kind: DataSciencePipelinesApplication
metadata:
  name: dspa
spec:
  apiServer:
    applyTektonCustomResource: true
    archiveLogs: false
    autoUpdatePipelineDefaultVersion: true
    caBundleFileMountPath: ""
    caBundleFileName: ""
    collectMetrics: true
    dbConfigConMaxLifetimeSec: 120
    deploy: true
    enableOauth: true
    enableSamplePipeline: true
    injectDefaultScript: true
    stripEOF: true
    terminateStatus: Cancelled
    trackArtifacts: true
  database:
    customExtraParams: '{"tls":"false"}'
    disableHealthChecks: false
    externalDB:
      host: mysql.database
      passwordSecret:
        key: dbpassword
        name: dbpassword
      pipelineDBName: pipelines
      port: "3306"
      username: user
  dspVersion: v2
  objectStorage:
    disableHealthCheck: false
    enableExternalRoute: false
    externalStorage:
      basePath: ""
      bucket: pipeline-artifacts
      host: minio.minio:9000
      port: ""
      region: us-east-1
      s3CredentialsSecret:
        accessKey: AWS_ACCESS_KEY_ID
        secretKey: AWS_SECRET_ACCESS_KEY
        secretName: dspa-secret
      scheme: http
  persistenceAgent:
    deploy: true
    numWorkers: 2
  scheduledWorkflow:
    cronScheduleTimezone: UTC
    deploy: true
EOF
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
