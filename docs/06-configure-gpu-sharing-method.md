# 6. GPU sharing methods

### Objectives

- Configuring the GPU so we can fully utilize the resources

### Rationale

- Minimize idle assets
- Maximize utilization
- Demonstrate reconfigurability
- This is a configuration that will flux

### Takeaways

- Who offers GPU optimization techniques? NVIDIA, Run.ai (acquired by NVIDIA), AMD, Intel?
- There are different pros/cons/use cases for different strategies:
  - GPU model
  - Workload resource consumption
  - QoS: isolation / fault tolerance / shared access
  - Parallel / simultaneous processing
  - use case:
    - AI inference on MIG during the day
    - DL training on single instance off-hours

> [!NOTE]
> By default, you get one workload per GPU. This is inefficient for most use cases. [How can you share a GPU to 1:N workloads](https://docs.openshift.com/container-platform/4.15/architecture/nvidia-gpu-architecture-overview.html#nvidia-gpu-prerequisites_nvidia-gpu-architecture-overview):

For NVIDIA GPU there are a few methods to optimize GPU utilization:

| Sharing Method                                                                                                                                                                              | Description                                                                                                                                                                                                                                       |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [Time-slicing NVIDIA GPUs](https://docs.nvidia.com/datacenter/cloud-native/openshift/latest/time-slicing-gpus-in-openshift.html#)                                                           | Allows workloads sharing a GPU to interleave with each other. Nothing special is done to isolate workloads. Each workload has access to the GPU memory and runs in the same fault-domain as others (meaning if one workload crashes, they all do) |
| [Multi-Process Service](https://docs.nvidia.com/deploy/mps/)                                                                                                                                | A control daemon is used to manage access to the shared GPU. MPS does space partitioning and allows memory and compute resources to be explicitly partitioned and enforces these limits per workload.                                             |
| [Multi-Instance GPU (MIG)](https://docs.nvidia.com/datacenter/cloud-native/openshift/latest/mig-ocp.html)                                                                                   | Allows you to split your hardware resources into multiple GPU instances, each exposed to the operating system as an independent CUDA-enabled GPU. They operate completely isolated from each other using dedicated hardware resources.            |
| [NVIDIA vGPUs](https://docs.nvidia.com/datacenter/cloud-native/openshift/23.9.2/nvaie-with-ocp.html?highlight=passthrough#openshift-container-platform-on-vmware-vsphere-with-nvidia-vgpus) | Creates virtual GPUs that can be shared across multiple virtual machines. Guest VMs use the NVIDIA vGPUs in the same manner as a physical GPU that has been passed through by the hypervisor. Requires NVIDIA AI Enterprise (NVAIE).              |

> Note: The use of time-slicing and MPS are mutually exclusive.

## 6.1 Configure GPUs with time slicing

### Objectives

- Configuring the GPU with time-slicing create a configmap, patch a cluster-policy, and node labels

### Rationale

- The AWS m6a.4xlarge provides an NVIDIA Tesla that does not support MIG, only time-slicing

### Takeaways

- Best suited where complex resource management is not required and tasks can tolerate variable GPU access and performance.
- Useful when
  - There are many jobs to run on limited hardware.
  - GPU demands are dynamic, such as when multiple tasks or users need concurrent access.
  - Maximize throughput for workloads that benefit from burst computation.
  - Dynamic allocation of GPU time based on workload needs.

> Refer [Here](https://docs.nvidia.com/datacenter/cloud-native/openshift/latest/time-slicing-gpus-in-openshift.html#Configure-gpus-with-time-slicing) for details

## Steps

- [ ] Apply the device plugin configuration

```sh
oc apply -f configs/06/nvidia-gpu-deviceplugin-cm.yaml
```

```sh
# expected output
configmap/device-plugin-config created
```

- [ ] Tell the GPU Operator which ConfigMap, in this case `device-plugin-config` to use for the device plugin configuration.

```sh
oc patch clusterpolicy gpu-cluster-policy \
-n nvidia-gpu-operator --type merge \
-p '{"spec": {"devicePlugin": {"config": {"name": "device-plugin-config"}}}}'
```

```sh
# expected output
clusterpolicy.nvidia.com/gpu-cluster-policy patched
```

- [ ] Apply the configuration to all the nodes you have with Tesla T GPUs. GFD, labels the nodes with the GPU product, in this example Tesla-T4, so you can use a node selector to label all of the nodes at once.

```sh
oc label --overwrite node \
--selector=nvidia.com/gpu.product=Tesla-T4 \
nvidia.com/device-plugin.config=time-sliced-8
```

```sh
# expected output
node/ip-10-0-29-207.us-xxxx-x.compute.internal labeled
node/ip-10-0-36-189.us-xxxx-x.compute.internal labeled
```

- [ ] Patch the NVIDIA GPU Operator ClusterPolicy to use the timeslicing configuration by default.

```sh
oc patch clusterpolicy gpu-cluster-policy \
-n nvidia-gpu-operator --type merge \
-p '{"spec": {"devicePlugin": {"config": {"default": "time-sliced-8"}}}}'
```

```sh
# expected output
clusterpolicy.nvidia.com/gpu-cluster-policy patched
```

> The applied configuration creates eight replicas for Tesla T4 GPUs, so the nvidia.com/gpu external resource is set to 8. You can apply a cluster-wide default time-slicing configuration. You can also apply node-specific configurations. For example, you can apply a time-slicing configuration to nodes with Tesla-T4 GPUs only and not modify nodes with other GPU models.

- [ ] Verify replicas for each GPU node

```sh
oc get node --selector=nvidia.com/gpu.product=Tesla-T4-SHARED -o json | jq '.items[0].status.capacity'
```

```sh
# expected output
{
"cpu": "16",
"ephemeral-storage": "104266732Ki",
"hugepages-1Gi": "0",
"hugepages-2Mi": "0",
"memory": "65029276Ki",
"nvidia.com/gpu": "8",
"pods": "250"
}
```

- [ ] Verify that GFD labels have been added to indicate time-sharing.

  1. The `nvidia.com/gpu.count` label reports the number of physical GPUs in the machine.
  1. The `nvidia.com/gpu.product` label includes a `-SHARED` suffix to the product name.
  1. The `nvidia.com/gpu.replicas` label matches the reported capacity.

     > The `-SHARED` product name suffix ensures that you can specify a node selector to assign pods to nodes with time-sliced GPUs.

```sh
oc get node --selector=nvidia.com/gpu.product=Tesla-T4-SHARED -o json \
| jq '.items[0].metadata.labels' | grep nvidia
```

```sh
# expected output
...
"nvidia.com/gpu.count": "1",
...
"nvidia.com/gpu.product": "Tesla-T4-SHARED",
"nvidia.com/gpu.replicas": "8",
...
```

## 6.2 Configure Taints and Tolerations

### Objectives

- Preventing non-GPU workloads from being scheduled on the GPU nodes via labels, draining the nodes, and making them schedulable again.

### Rationale

- Minimize GPU resource waste
- Maximize GPU utilization

### Takeaways

- This only taints the nodes.
- Tolerations will be set in the RHOAI accelerator profiles that match the Taint key.
- This MUST match the Accelerator profile taint key you use (this could be different, i.e. `nvidia-gpu-only` or `nvidia.com/gpu`).

## Steps

- [ ] Taint the GPU nodes with `nvidia.com/gpu`. This MUST match the Accelerator profile taint key you use (this could be different, i.e. `nvidia-gpu-only`).

```sh
oc adm taint node -l nvidia.com/gpu.machine nvidia.com/gpu=:NoSchedule --overwrite
```

```sh
# expected output
node/ip-10-x-xx-xxx.us-xxxx-x.compute.internal modified
node/ip-10-x-xx-xxx.us-xxxx-x.compute.internal modified
```

- [ ] Edit the `ClusterPolicy` in the NVIDIA GPU Operator under the `nvidia-gpu-operator` project. Add the below section to `.spec.daemonsets:`

```sh
oc edit ClusterPolicy
```

```sh
daemonsets:
  tolerations:
  - effect: NoSchedule
  operator: Exists
  key: nvidia.com/gpu
```

- [ ] Cordon the GPU node, drain the GPU tainted nodes and terminate workloads

```sh
oc adm drain -l nvidia.com/gpu.machine --ignore-daemonsets --delete-emptydir-data
```

```sh
# expected output
node/ip-10-x-xx-xxx.us-xxxx-x.compute.internal cordoned
node/ip-10-x-xx-xxx.us-xxxx-x.compute.internal cordoned
...
evicting pod nvidia-gpu-operator/console-plugin-nvidia-gpu-754ddf45-8nfx5
evicting pod openshift-nfd/nfd-controller-manager-69fc4d5fb9-sflpw
evicting pod nvidia-gpu-operator/nvidia-cuda-validator-5v7lx
pod/nvidia-cuda-validator-5v7lx evicted
pod/console-plugin-nvidia-gpu-754ddf45-8nfx5 evicted
pod/nfd-controller-manager-69fc4d5fb9-sflpw evicted
node/ip-10-x-xx-xxx.us-xxxx-x.compute.internal drained
...
evicting pod nvidia-gpu-operator/gpu-operator-97655fdc-kgpb4
evicting pod sandbox/cuda-vectoradd
evicting pod openshift-marketplace/
...
pod/collect-profiles-28709130-jqpcm evicted
pod/cuda-vectoradd evicted
pod/619c4bd263651f3b6508183066a8f9f3ef96907a573bfcd1d5252721a5csdd4 evicted
pod/collect-profiles-28709145-mxvx7 evicted
pod/collect-profiles-28709160-p87sh evicted
pod/4e6357cf195932a62fceaa1d7eae5734b36af199315bc628f91659603bd95p9 evicted
pod/nvidia-cuda-validator-fvwnh evicted
pod/gpu-operator-97655fdc-kgpb4 evicted
node/ip-10-x-xx-xxx.us-xxxx-x.compute.internal drained
```

- [ ] Allow the GPU node to be schedulable again per tolerations

```sh
oc adm uncordon -l nvidia.com/gpu.machine
```

```sh
# expected output
node/ip-10-x-xx-xxx.us-xxxx-x.compute.internal uncordoned
node/ip-10-x-xx-xxx.us-xxxx-x.compute.internal uncordoned
```

- [ ] Get the name of the gpu node

```sh
MACHINE_SET_TYPE=$(oc get machineset -n openshift-machine-api -o name |  egrep gpu)
```

- [ ] Taint the machineset for any new nodes that get added to be tainted with `nvidia.com/gpu`

```sh
oc -n openshift-machine-api \
patch "${MACHINE_SET_TYPE}" \
--type=merge --patch '{"spec":{"template":{"spec":{"taints":[{"key":"nvidia.com/gpu","value":"","effect":"NoSchedule"}]}}}}'
```

> IMPORTANT: Tolerations will be set in the RHOAI accelerator profiles that match the Taint key.

## Automation key (Catch up)

- [ ] From this repository's root directory, run below command

```sh
./scripts/setup.sh -s 6
```
