# 5. Configure GPU dashboards

## 5.1 Enabling the GPU Monitoring Dashboard

### Objectives

- Enabling the NVIDIA DCGM Exporter Dashboard

### Rationale

- Customers care about Metrics for utilization and even charge back for tenants, this provides access to GPU data

### Takeaways

- What to monitor? This provides System Non-Functional Monitoring NOT Functional ML Monitoring. Is this enough?

- Defaults:

  - GPU Temperature - GPU temperature in C.
  - GPU Avg. Temp - Average GPU temperature in C.
  - GPU Power Usage - Power usage in watts for each GPU.
  - GPU Power Total - Total power usage in watts.
  - GPU SM Clocks - SM clock frequency in hertz.
  - GPU Utilization - GPU utilization, percent.
  - GPU Framebuffer Mem Used - Frame buffer memory used in MB.
    Tensor Core Utilization - Ratio of cycles the tensor (HMMA) pipe is active, percent.

> Refer [Here](https://docs.nvidia.com/datacenter/cloud-native/openshift/latest/enable-gpu-monitoring-dashboard.html) for details

## Steps

- [ ] Download the latest NVIDIA DCGM Exporter Dashboard from the DCGM Exporter repository on GitHub:

```sh
curl -Lf https://github.com/NVIDIA/dcgm-exporter/raw/main/grafana/dcgm-exporter-dashboard.json -o scratch/dcgm-exporter-dashboard.json
```

```sh
# expected output
% Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                Dload  Upload   Total   Spent    Left  Speed
0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
100 18114  100 18114    0     0  23496      0 --:--:-- --:--:-- --:--:-- 23496
```

- [ ] Create a config map from the downloaded file in the openshift-config-managed namespace

```sh
oc create configmap -n openshift-config-managed nvidia-dcgm-exporter-dashboard --from-file=nvidia-dcgm-dashboard.json=scratch/dcgm-exporter-dashboard.json
```

```sh
# expected output
configmap/nvidia-dcgm-exporter-dashboard created
```

- [ ] Label the config map to expose the dashboard in the Administrator perspective of the web console `dashboard`:

```sh
oc label configmap nvidia-dcgm-exporter-dashboard -n openshift-config-managed "console.openshift.io/dashboard=true"
```

```sh
# expected output
configmap/nvidia-dcgm-exporter-dashboard labeled
```

- [ ] Optional: Label the config map to expose the dashboard in the Developer perspective of the web console `odc-dashboard`:

```sh
oc label configmap nvidia-dcgm-exporter-dashboard -n openshift-config-managed "console.openshift.io/odc-dashboard=true"
```

```sh
# expected output
configmap/nvidia-dcgm-exporter-dashboard labeled
```

- [ ] View the created resource and verify the labels for the `dashboard` and `odc-dashboard`

```sh
oc -n openshift-config-managed get cm nvidia-dcgm-exporter-dashboard --show-labels
```

```sh
# expected output
NAME                             DATA   AGE     LABELS
nvidia-dcgm-exporter-dashboard   1      3m28s   console.openshift.io/dashboard=true,console.openshift.io/odc-dashboard=true
```

- [ ] View the NVIDIA DCGM Exporter Dashboard from the OCP UI from Administrator and Developer

> [!TODO]
> We need to insert a picture here

## Additional Information

There are other tools of varying levels of support from other vendors, including Nvidia directly and some efforts that Red Hatters have built and contributed to. You may find references to some of these projects in official documentation. For an example of one of these community supported administration tools, you can check out the information provided [here](/docs/info-gpu-dashboard.md).

## Automation key (Catch up)

- [ ] From this repository's root directory, run below command

```sh
./scripts/setup.sh -s 5
```
