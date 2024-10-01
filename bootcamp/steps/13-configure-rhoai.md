## 13. Administrative Configurations for RHOAI

### 13.1 Add a new Accelerator Profile

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
        ...
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

### 13.2 Add serving runtime

### Steps
- From RHOAI, Settings > Serving runtimes > Click Add Serving Runtime.

    **Option 1 (manual)**:

    - Select `Multi-model serving`
    - Select `Start from scratch`
    - Review, Copy and Paste in the content from `configs/rhoai-add-serving-runtime.yaml`
    - Add and confirm the runtime can be selected in a Data Science Project

    **Option 2**:

    - ```sh
        oc apply -f configs/rhoai-add-serving-runtime-template.yaml -n redhat-ods-applications
        ```
    - Add and confirm the runtime can be selected in a Data Science Project

#### User Management

- Data scientists
- Administrators

### Review Backing up data

Refer to [A Guide to High Availability / Disaster Recovery for Applications on OpenShift](https://www.redhat.com/en/blog/a-guide-to-high-availability/disaster-recovery-for-applications-on-openshift)

#### Control plane backup and restore operations

You must [back up etcd](https://docs.openshift.com/container-platform/4.15/backup_and_restore/control_plane_backup_and_restore/backing-up-etcd.html#backup-etcd) data before shutting down a cluster; etcd is the key-value store for RHOCP, which persists the state of all resource objects.

#### Application backup and restore operations

The OpenShift API for Data Protection (OADP) product safeguards customer applications on RHOCP. It offers comprehensive disaster recovery protection, covering RHOCP applications, application-related cluster resources, persistent volumes, and internal images. OADP is also capable of backing up both containerized applications and virtual machines (VMs).

However, OADP does not serve as a disaster recovery solution for [etcd](https://docs.openshift.com/container-platform/4.15/backup_and_restore/control_plane_backup_and_restore/backing-up-etcd.html#backup-etcd) or OpenShift Operators.

## Automation key

- From this repo's root directory, run below command
    - ```sh
        ./bootcamp/scripts/runstep.sh -s 13