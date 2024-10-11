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

- Restart the dashboard Deployment

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
