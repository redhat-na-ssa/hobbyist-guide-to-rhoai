## 9. Configure GPU dashboards

### Enabling the GPU Monitoring Dashboard

[More Info](https://docs.nvidia.com/datacenter/cloud-native/openshift/latest/enable-gpu-monitoring-dashboard.html)

- Download the latest NVIDIA DCGM Exporter Dashboard from the DCGM Exporter repository on GitHub:

  - ```sh
      curl -Lf https://github.com/NVIDIA/dcgm-exporter/raw/main/grafana/dcgm-exporter-dashboard.json -o scratch/dcgm-exporter-dashboard.json
    ```

    ```sh
    # expected output
    % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                    Dload  Upload   Total   Spent    Left  Speed
    0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
    100 18114  100 18114    0     0  23496      0 --:--:-- --:--:-- --:--:-- 23496
    ```

- Check for modifications

  - ```sh
      diff -u configs/09/nvidia-dcgm-dashboard.json scratch/dcgm-exporter-dashboard.json
    ```

    ```sh
    # expected output
    <blank>
    ```

- Create a config map from the downloaded file in the openshift-config-managed namespace

  - ```sh
      oc create -f configs/09/nvidia-dcgm-dashboard-cm.yaml
    ```

    ```sh
    # expected output
    configmap/nvidia-dcgm-exporter-dashboard created
    ```

- Label the config map to expose the dashboard in the Administrator perspective of the web console `dashboard`:

  - ```sh
      oc label configmap nvidia-dcgm-exporter-dashboard -n openshift-config-managed "console.openshift.io/dashboard=true"
    ```

    ```sh
    # expected output
    configmap/nvidia-dcgm-exporter-dashboard labeled
    ```

- Optional: Label the config map to expose the dashboard in the Developer perspective of the web console `odc-dashboard`:

  - ```sh
      oc label configmap nvidia-dcgm-exporter-dashboard -n openshift-config-managed "console.openshift.io/odc-dashboard=true"
    ```

    ```sh
    # expected output
    configmap/nvidia-dcgm-exporter-dashboard labeled
    ```

- View the created resource and verify the labels for the `dashboard` and `odc-dashboard`

  - ```sh
      oc -n openshift-config-managed get cm nvidia-dcgm-exporter-dashboard --show-labels
    ```

    ```sh
    # expected output
    NAME                             DATA   AGE     LABELS
    nvidia-dcgm-exporter-dashboard   1      3m28s   console.openshift.io/dashboard=true,console.openshift.io/odc-dashboard=true
    ```

> View the NVIDIA DCGM Exporter Dashboard from the OCP UI from Administrator and Developer

### Install the NVIDIA GPU administration dashboard

This is a dedicated administration dashboard for NVIDIA GPU usage visualization Web Console. The dashboard relies mostly on Prometheus metrics exposed by the NVIDIA DCGM Exporter, but the default exposed metrics are not enough for the dashboard to render the required gauges. Therefore, the DGCM exporter is configured to expose a custom set of metrics.
[More Info](https://docs.openshift.com/container-platform/4.15/observability/monitoring/nvidia-gpu-admin-dashboard.html)

- Add the Helm repository

  - ```sh
      helm repo add rh-ecosystem-edge https://rh-ecosystem-edge.github.io/console-plugin-nvidia-gpu
    ```

    ```sh
    # expected output
    "rh-ecosystem-edge" has been added to your repositories

    # possible output
    "rh-ecosystem-edge" already exists with the same configuration, skipping
    ```

- Helm update

  - ```sh
      helm repo update
    ```

    ```sh
    # expected output
    Hang tight while we grab the latest from your chart repositories...
    ...Successfully got an update from the "rh-ecosystem-edge" chart repository
    <snipped>
    Update Complete. ⎈Happy Helming!⎈
    ```

- Install the Helm chart in the default NVIDIA GPU operator namespace

  - ```sh
      helm install -n nvidia-gpu-operator console-plugin-nvidia-gpu rh-ecosystem-edge/console-plugin-nvidia-gpu
    ```

    ```sh
    # expected output
    NAME: console-plugin-nvidia-gpu
    LAST DEPLOYED: Tue Jul 16 18:28:55 2024
    NAMESPACE: nvidia-gpu-operator
    STATUS: deployed
    REVISION: 1
    NOTES:

    <snipped>

    ...
    ```

- Check if a plugins field is specified

  - ```sh
      oc get consoles.operator.openshift.io cluster --output=jsonpath="{.spec.plugins}"
    ```

    ```sh
    # expected output
    <blank>
    ```

- If not, then run the following to enable the plugin

  - ```sh
      oc patch consoles.operator.openshift.io cluster --patch '[{"op": "add", "path": "/spec/plugins/-", "value": "console-plugin-nvidia-gpu" }]' --type=json
    ```

    ```sh
    # expected output
    console.operator.openshift.io/cluster patched
    ```

- Add the required DCGM Exporter metrics ConfigMap to the existing NVIDIA operator ClusterPolicy CR

  - ```sh
      oc patch clusterpolicies.nvidia.com gpu-cluster-policy --patch '{ "spec": { "dcgmExporter": { "config": { "name": "console-plugin-nvidia-gpu" } } } }' --type=merge
    ```

    ```sh
    # expected output
    clusterpolicy.nvidia.com/gpu-cluster-policy patched
    ```

You should receive a message on the console "Web console update is available" > Refresh the web console.

> NOTE: If your gauges are not displaying, you can go to your user (top right menu dropdown) > User Preferences > change your theme to `Light`.

#### Viewing the GPU Dashboard

- Go to Compute > GPUs

  > Notice the `Telsa T4 Single-Instance` at the top of the screen. This GPU is NOT shareable (i.e. sliced, partitioned, fractioned) yet. As Manfred Manns lyrics go, be ready to be `Blinded by the light`.

  - ```sh
      oc get cm console-plugin-nvidia-gpu -n nvidia-gpu-operator -o yaml
    ```

    ```sh
    # expected output
    apiVersion: v1
    data:
    dcgm-metrics.csv: |
        DCGM_FI_PROF_GR_ENGINE_ACTIVE, gauge, gpu utilization.
        DCGM_FI_DEV_MEM_COPY_UTIL, gauge, mem utilization.
        DCGM_FI_DEV_ENC_UTIL, gauge, enc utilization.
        DCGM_FI_DEV_DEC_UTIL, gauge, dec utilization.
        DCGM_FI_DEV_POWER_USAGE, gauge, power usage.
        DCGM_FI_DEV_POWER_MGMT_LIMIT_MAX, gauge, power mgmt limit.
        DCGM_FI_DEV_GPU_TEMP, gauge, gpu temp.
        DCGM_FI_DEV_SM_CLOCK, gauge, sm clock.
        DCGM_FI_DEV_MAX_SM_CLOCK, gauge, max sm clock.
        DCGM_FI_DEV_MEM_CLOCK, gauge, mem clock.
        DCGM_FI_DEV_MAX_MEM_CLOCK, gauge, max mem clock.
    kind: ConfigMap
    metadata:
    annotations:
        meta.helm.sh/release-name: console-plugin-nvidia-gpu
        meta.helm.sh/release-namespace: nvidia-gpu-operator
    ...
    labels:
        app.kubernetes.io/component: console-plugin-nvidia-gpu
        app.kubernetes.io/instance: console-plugin-nvidia-gpu
        app.kubernetes.io/managed-by: Helm
        app.kubernetes.io/name: console-plugin-nvidia-gpu
        app.kubernetes.io/part-of: console-plugin-nvidia-gpu
        app.kubernetes.io/version: latest
        helm.sh/chart: console-plugin-nvidia-gpu-0.2.4
    name: console-plugin-nvidia-gpu
    namespace: nvidia-gpu-operator
    ...
    ```

- View the deployed resources

  - ```sh
      oc -n nvidia-gpu-operator get all -l app.kubernetes.io/name=console-plugin-nvidia-gpu
    ```

## Automation key (Catch up)

- From this repository's root directory, run below command
  - ```sh
      ./scripts/setup.sh -s 9
    ```
