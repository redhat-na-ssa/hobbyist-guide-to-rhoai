## Install the NVIDIA GPU administration dashboard

### Objectives

- Visualizing a custom set of metrics via the Web Console Admin Perspective

### Rationale

- Demonstrate customization of metrics and giving a different view of using the data.

### Takeaways

- More System Non-Functional Monitoring NOT Functional ML Monitoring. Is this enough?
- Notice the Telsa T4 Single-Instance at the top of the screen. This GPU is NOT shareable (i.e. sliced, partitioned, fractioned) yet.
- Are you in dark mode?

> Refer [Here](https://docs.openshift.com/container-platform/4.15/observability/monitoring/nvidia-gpu-admin-dashboard.html) for more details

## Steps

- [ ] Add the Helm repository

```sh
helm repo add rh-ecosystem-edge https://rh-ecosystem-edge.github.io/console-plugin-nvidia-gpu
```

```sh
# expected output
"rh-ecosystem-edge" has been added to your repositories

# possible output
"rh-ecosystem-edge" already exists with the same configuration, skipping
```

- [ ] Helm update

```sh
helm repo update
```

```sh
# expected output
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "rh-ecosystem-edge" chart repository
<snipped>
Update Complete. ⎈Happy Helming!⎈
```

- [ ] Install the Helm chart in the default NVIDIA GPU operator namespace

```sh
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

- [ ] Check if a plugins field is specified

```sh
oc get consoles.operator.openshift.io cluster --output=jsonpath="{.spec.plugins}"
```

```sh
# expected output
<blank>
```

- [ ] If not, then run the following to enable the plugin

```sh
oc patch consoles.operator.openshift.io cluster --patch '[{"op": "add", "path": "/spec/plugins/-", "value": "console-plugin-nvidia-gpu" }]' --type=json
```

```sh
# expected output
console.operator.openshift.io/cluster patched
```

- [ ] Add the required DCGM Exporter metrics ConfigMap to the existing NVIDIA operator ClusterPolicy CR

```sh
oc patch clusterpolicies.nvidia.com gpu-cluster-policy --patch '{ "spec": { "dcgmExporter": { "config": { "name": "console-plugin-nvidia-gpu" } } } }' --type=merge
```

```sh
# expected output
clusterpolicy.nvidia.com/gpu-cluster-policy patched
```

> [!NOTE]
> You should receive a message on the console "Web console update is available" > Refresh the web console.

> If your gauges are not displaying, you can go to your user (top right menu dropdown) > User Preferences > change your theme to `Light`.

### Viewing the GPU Dashboard

- [ ] Go to Compute > GPUs

> [!NOTE]
> Notice the `Telsa T4 Single-Instance` at the top of the screen. This GPU is NOT shareable (i.e. sliced, partitioned, fractioned) yet. As Manfred Manns lyrics go, be ready to be `Blinded by the light`.

```sh
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

- [ ] View the deployed resources

```sh
oc -n nvidia-gpu-operator get all -l app.kubernetes.io/name=console-plugin-nvidia-gpu
```
