# 3. Enabling GPU support for RHOAI

In order to enable GPUs for RHOAI, you must follow the procedure to [enable GPUs for RHOCP](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/2.10/html/Install_and_unInstall_openshift_ai_self-managed/enabling-gpu-support_install). Once completed, RHOAI requires an Accelerator Profile custom resource definition in the `redhat-ods-applications`. Currently, NVIDIA and Intel Gaudi are the supported [accelerator profiles](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/2.10/html/working_with_accelerators/overview-of-accelerators_accelerators#overview-of-accelerators_accelerators).

## 3.1 Adding a GPU node to an existing RHOCP cluster

### Objectives

- Copying/modifying an existing machineset to create a GPU-enabled MachineSet and machines on AWS

### Rationale

- RHOAI Operator does not perform any function for configuring and managing GPUs

### Takeaways

- Nodes vs. Machines vs. Machinesets
- GPUs in other cloud providers and bare metal
- Once completed, RHOAI requires an Accelerator Profile custom resource definition in the redhat-ods-applications.
- Currently, NVIDIA and Intel Gaudi are the supported accelerator profiles.

> You can copy and modify a default compute machine set configuration to create a GPU-enabled machine set and machines for the AWS EC2 cloud provider. [More Info](https://docs.redhat.com/en/documentation/openshift_container_platform/4.15/html/machine_management/managing-compute-machines-with-the-machine-api#nvidia-gpu-aws-adding-a-gpu-node_creating-machineset-aws)

## Steps

- [ ] View the existing nodes

```sh
oc get nodes
```

```sh
# expected output
NAME                                        STATUS   ROLES                         AGE     VERSION
ip-10-x-xx-xxx.us-xxxx-x.compute.internal   Ready    control-plane,master,worker   5h11m   v1.28.10+a2c84a5
```

- [ ] View the machines and machine sets that exist in the openshift-machine-api namespace

```sh
oc get machinesets -n openshift-machine-api
```

```sh
# expected output
NAME                                    DESIRED   CURRENT   READY   AVAILABLE   AGE
cluster-xxxxx-xxxxx-worker-us-xxxx-xc   0         0                             5h13m
```

- [ ] Make a copy of one of the existing compute MachineSet definitions and output the result to a YAML file

```sh
# get your machineset name --no-headers removes the headers from the output. awk '{print $1}'. extracts the first column.
head -n 1 limits the output to the first entry.
MACHINESET_COPY=$(oc get machinesets -n openshift-machine-api --no-headers | awk '{print $1}' | head -n 1)

# make a copy of an existing machineset definition
oc get machineset $MACHINESET_COPY -n openshift-machine-api -o yaml > scratch/machineset.yaml
```

- [ ] Edit the downloaded machineset.yaml and update the following fields:

```sh
- [ ] ~Line 13`.metadata.name` to a name containing `-gpu`.
- [ ] ~Line 18 `.spec.replicas` from `0` to `2`
- [ ] ~Line 22`.spec.selector.matchLabels["machine.openshift.io/cluster-api-machineset"]` to match the new `.metadata.name`.
- [ ] ~Line 29 `.spec.template.metadata.labels["machine.openshift.io/cluster-api-machineset"]` to match the new `.metadata.name`.
- [ ] ~Line 51 `.spec.template.spec.providerSpec.value.instanceType` to `g4dn.4xlarge`.
```

> You can use `sed` or `yq` commands. However, sed is more limited and error-prone for complex YAML manipulations. If you have yq installed (a powerful YAML processor), it's much easier to handle such updates.

- [ ] Remove the following fields:

```sh
- [ ] ~Line 10 `generation`
- [ ] ~Line 16 `uid` (becomes line 15 if you delete line 10 first)
- [ ] other fields as desired
```

- [ ] Apply the configuration to create the gpu machine

```sh
oc apply -f scratch/machineset.yaml
```

```sh
# expected output
machineset.machine.openshift.io/cluster-xxxx-xxxx-worker-us-xxxx-gpu created
```

- [ ] Verify the gpu machineset you created is running

```sh
oc -n openshift-machine-api get machinesets | grep gpu
```

```sh
# expected output
cluster-xxxxx-xxxxx-worker-us-xxxx-xc-gpu   2         2         2       2           6m37s
```

- [ ] View the Machine object that the machine set created

```sh
oc -n openshift-machine-api get machines -w | grep gpu
```

```sh
# expected output
cluster-xxxxx-xxxxx-worker-us-xxxx-xc-gpu-29whc   Running   g4dn.4xlarge   us-xxxx-x   us-xxxx-xc   7m59s
cluster-xxxxx-xxxxx-worker-us-xxxx-xc-gpu-nr59d   Running   g4dn.4xlarge   us-xxxx-x   us-xxxx-xc   7m59s
```

## 3.2 Deploying the Node Feature Discovery Operator (takes time)

### Objectives

- Creating the ns, OperatorGroup and subscribing the NFD Operator

### Rationale

- After the GPU-enabled node is created, you need to discover the GPU-enabled node so it can be scheduled. NFD makes it easy to detect and understand the hardware features and configurations of a cluster's nodes.

### Takeaways

- Red Hat supports this operator and it is used for all GPUs
- NFD Operator uses [vendor PCI IDs](https://pcisig.com/membership/member-companies?combine=10de) to identify hardware in a node
  - sources.pci.deviceClassWhitelist is a list of PCI device class IDs for which to publish a label.
  - sources.pci.deviceLabelFields is the set of PCI ID fields to use when constructing the name of the feature label.

> Refer [Here](https://docs.redhat.com/en/documentation/openshift_container_platform/4.15/html/machine_management/managing-compute-machines-with-the-machine-api#nvidia-gpu-aws-deploying-the-node-feature-discovery-operator_creating-machineset-aws) for more information.

## Steps

- [ ] List the available operators for installation searching for Node Feature Discovery (NFD)

```sh
oc get packagemanifests -n openshift-marketplace | grep nfd
```

```sh
# expected output
openshift-nfd-operator                             Community Operators   8h
nfd                                                Red Hat Operators     8h
```

- [ ] Apply the Namespace object

```sh
oc apply -f configs/03/nfd-operator-ns.yaml
```

```sh
# expected output
namespace/openshift-nfd created
```

- [ ] Apply the OperatorGroup object

```sh
oc apply -f configs/03/nfd-operator-group.yaml
```

```sh
# expected output
operatorgroup.operators.coreos.com/nfd created
```

- [ ] Apply the Subscription object

```sh
oc apply -f configs/03/nfd-operator-sub.yaml
```

```sh
# expected output
subscription.operators.coreos.com/nfd created
```

- [ ] Verify the operator is installed and running

```sh
# watch the pods get created in the new project
oc get pods -n openshift-nfd -w
```

```sh
# expected output
NAME                                      READY   STATUS    RESTARTS   AGE
...
nfd-controller-manager-78758c57f7-7xfh4   2/2     Running   0          48s
```

> After Install the NFD Operator, you create instance that installs the `nfd-master` and one `nfd-worker` pod for each compute node in the `openshift-nfd` namespace.
> [More Info](https://docs.openshift.com/container-platform/4.15/hardware_enablement/psap-node-feature-discovery-operator.html#Configure-node-feature-discovery-operator-sources_psap-node-feature-discovery-operator)

- [ ] Create the nfd instance object

```sh
oc apply -f configs/03/nfd-instance.yaml
```

```sh
# expected output
nodefeaturediscovery.nfd.openshift.io/nfd-instance created
```

> This creates NFD pods in the `openshift-nfd` namespace that poll RHOCP nodes for hardware resources and catalogue them.

> [IMPORTANT]
> The NFD Operator uses vendor PCI IDs to identify hardware in a node.

Below are some of the [PCI vendor ID assignments](https://pcisig.com/membership/member-companies?combine=10de):

| PCI id | Vendor |
| ------ | ------ |
| `10de` | NVIDIA |
| `1d0f` | AWS    |
| `1002` | AMD    |
| `8086` | Intel  |

- [ ] Verify the GPU device (NVIDIA uses the PCI ID `10de`) is discovered on the GPU node. This mean the NFD Operator correctly identified the node from the GPU-enabled MachineSet.

```sh
oc describe node | egrep 'Roles|pci' | grep -v master
```

```sh
# expected output
Roles:              worker
                feature.node.kubernetes.io/pci-10de.present=true
                feature.node.kubernetes.io/pci-1d0f.present=true
                feature.node.kubernetes.io/pci-1d0f.present=true
Roles:              worker
                feature.node.kubernetes.io/pci-10de.present=true
                feature.node.kubernetes.io/pci-1d0f.present=true
```

- [ ] Verify the NFD pods are `Running` on the cluster nodes polling for devices

```sh
oc get pods -n openshift-nfd
```

```sh
# expected output
NAME                                      READY   STATUS    RESTARTS   AGE
nfd-controller-manager-78758c57f7-7xfh4   2/2     Running   0          99s
nfd-master-74db665cb6-vht4l               1/1     Running   0          25s
nfd-worker-8zkpz                          1/1     Running   0          25s
nfd-worker-d7wgh                          1/1     Running   0          25s
nfd-worker-l6sqx                          1/1     Running   0          25s
```

- [ ] Verify the NVIDIA GPU is discovered

```sh
# list your nodes
oc get nodes

# display the role feature list of a gpu node
oc describe node <NODE_NAME> | egrep 'Roles|pci'
```

```sh
# expected output
Roles:              worker
                feature.node.kubernetes.io/pci-10de.present=true
                feature.node.kubernetes.io/pci-1d0f.present=true
```

## 3.3 Install the NVIDIA GPU Operator

### Objectives

- Creating the ns, OperatorGroup and subscribing the NVIDIA GPU Operator

### Rationale

- To install and configure

  - NVIDIA drivers (to enable CUDA)
  - Advertise system hardware resources to the Kubelet
  - NVIDIA Container Toolkit
  - Automatic node labelling
  - NVIDIA Data Center GPU Manager (DCGM) for active health monitoring

### Takeaways

- NVIDIA supports this operator and it is used specific NVIDIA GPUs
- The NVIDIA device plugin has a number of options, like MIG Strategy, that can be configured for it.
- With the daemonset deployed, NVIDIA GPUs have the nvidia-device-plugin and can be requested by a container using the nvidia.com/gpu resource type. The NVIDIA device plugin has a number of options, like MIG Strategy, that can be configured for it.

[More Info](https://docs.nvidia.com/datacenter/cloud-native/openshift/latest/install-gpu-ocp.html#Install-the-nvidia-gpu-operator-using-the-cli)

## Steps

- [ ] List the available operators for installation searching for Node Feature Discovery (NFD)

```sh
oc get packagemanifests -n openshift-marketplace | grep gpu
```

```sh
# expected output
amd-gpu-operator                                   Community Operators   8h
gpu-operator-certified                             Certified Operators   8h
```

- [ ] Apply the Namespace object YAML file

```sh
oc apply -f configs/03/nvidia-gpu-operator-ns.yaml
```

```sh
# expected output
namespace/nvidia-gpu-operator created
```

- [ ] Apply the OperatorGroup YAML file

```sh
oc apply -f configs/03/nvidia-gpu-operator-group.yaml
```

```sh
# expected output
operatorgroup.operators.coreos.com/nvidia-gpu-operator-group created
```

- [ ] Apply the Subscription CR

```sh
oc apply -f configs/03/nvidia-gpu-operator-subscription.yaml
```

```sh
# expected output
subscription.operators.coreos.com/gpu-operator-certified created
```

- [ ] Verify an install plan has been created. Be patient.

```sh
# you can watch the installplan instances get created
oc get installplan -n nvidia-gpu-operator -w
```

```sh
# expected output
NAME            CSV                              APPROVAL    APPROVED
...
install-295r6   gpu-operator-certified.v24.6.1   Automatic   true
```

- [ ] (Optional) Approve the install plan if not `Automatic`

```sh
INSTALL_PLAN=$(oc get installplan -n nvidia-gpu-operator -oname)
```

- [ ] Create the cluster policy

```sh
oc get csv -n nvidia-gpu-operator gpu-operator-certified.v24.6.1 -o jsonpath='{.metadata.annotations.alm-examples}' | jq '.[0]' > scratch/nvidia-gpu-clusterpolicy.json
```

- [ ] Apply the clusterpolicy

```sh
oc apply -f scratch/nvidia-gpu-clusterpolicy.json
```

```sh
# expected output
clusterpolicy.nvidia.com/gpu-cluster-policy created
```

> At this point, the GPU Operator proceeds and installs all the required components to set up the NVIDIA GPUs in the OpenShift 4 cluster. Wait at least 10-20 minutes before digging deeper into any form of troubleshooting because this may take a period of time to finish.

- [ ] Verify the successful installation of the NVIDIA GPU Operator

```sh
oc get pods,daemonset -n nvidia-gpu-operator
```

```sh
# expected output
NAME                                                           DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR                                                                                                         AGE
daemonset.apps/gpu-feature-discovery                           0         0         0       0            0           nvidia.com/gpu.deploy.gpu-feature-discovery=true                                                                      22s
daemonset.apps/nvidia-container-toolkit-daemonset              0         0         0       0            0           nvidia.com/gpu.deploy.container-toolkit=true                                                                          22s
daemonset.apps/nvidia-dcgm                                     0         0         0       0            0           nvidia.com/gpu.deploy.dcgm=true                                                                                       22s
daemonset.apps/nvidia-dcgm-exporter                            0         0         0       0            0           nvidia.com/gpu.deploy.dcgm-exporter=true                                                                              22s
daemonset.apps/nvidia-device-plugin-daemonset                  0         0         0       0            0           nvidia.com/gpu.deploy.device-plugin=true                                                                              22s
daemonset.apps/nvidia-device-plugin-mps-control-daemon         0         0         0       0            0           nvidia.com/gpu.deploy.device-plugin=true,nvidia.com/mps.capable=true                                                  22s
daemonset.apps/nvidia-driver-daemonset-415.92.202406251950-0   2         2         0       2            0           feature.node.kubernetes.io/system-os_release.OSTREE_VERSION=415.92.202406251950-0,nvidia.com/gpu.deploy.driver=true   22s
daemonset.apps/nvidia-mig-manager                              0         0         0       0            0           nvidia.com/gpu.deploy.mig-manager=true                                                                                22s
daemonset.apps/nvidia-node-status-exporter                     2         2         2       2            2           nvidia.com/gpu.deploy.node-status-exporter=true                                                                       22s
daemonset.apps/nvidia-operator-validator                       0         0         0       0            0           nvidia.com/gpu.deploy.operator-validator=true                                                                         22s
```

> With the daemonset deployed, NVIDIA GPUs have the `nvidia-device-plugin` and can be requested by a container using the `nvidia.com/gpu` resource type. The [NVIDIA device plugin](https://github.com/NVIDIA/k8s-device-plugin?tab=readme-ov-file#shared-access-to-gpus) has a number of options, like MIG Strategy, that can be configured for it.

## 3.4 Label GPU Nodes

### Objectives

- Add a label to the GPU node Role as gpu, worker for readability

### Rationale

- Reliability

### Takeaways

- nvidia.com/gpu is only used as a resource identifier, not anything else, in the context of differentiating GPU models (i.e. L40s, H100, V100, etc.). Node Selectors and Pod Affinity can still be configured arbitrarily.
- Kueue, allows more granularity than that (including capacity reservation at the cluster and namespace levels).
- If you have heterogeneous GPUs in a single node, this becomes more difficult and outside the capabilities of any of those solutions.

## Steps

- [ ] Add a label to the GPU node Role as `gpu, worker` for readability (cosmetic). You may have to rerun this command for multiple nodes.

```sh
oc label node -l nvidia.com/gpu.machine node-role.kubernetes.io/gpu=''
```

```sh
# expected output
node/ip-10-x-xx-xxx.us-xxxx-x.compute.internal labeled
node/ip-10-x-xx-xxx.us-xxxx-x.compute.internal labeled
```

- [ ] Get nodes to verify the label

```sh

oc get nodes
```

```sh
# expected output
NAME                                        STATUS   ROLES                         AGE   VERSION
...
ip-10-x-xx-xxx.us-xxxx-x.compute.internal   Ready    gpu,worker                    19h   v1.28.10+a2c84a5
ip-10-x-xx-xxx.us-xxxx-x.compute.internal   Ready    gpu,worker                    19h   v1.28.10+a2c84a5
...
```

- [ ] Apply this label to new machines/nodes:

```sh
# set an env value
MACHINE_SET_TYPE=$(oc -n openshift-machine-api get machinesets.machine.openshift.io -o name | grep gpu | head -n1)

# patch the machineset
oc -n openshift-machine-api \
patch "${MACHINE_SET_TYPE}" \
--type=merge --patch '{"spec":{"template":{"spec":{"metadata":{"labels":{"node-role.kubernetes.io/gpu":""}}}}}}'
```

```sh
# expected output
machineset.machine.openshift.io/cluster-xxxxx-xxxxx-worker-us-xxxx-xc-gpu patched
```

> At this time, the Nvidia operator creates an extended resource called `nvidia.com/gpu` on the nodes. `nvidia.com/gpu` is only used as a resource identifier, not anything else, in the context of differentiating GPU models (i.e. L40s, H100, V100, etc.). Node Selectors and Pod Affinity can still be configured arbitrarily. Later in this procedure, Distributed Workloads, `Kueue`, allows more granularity than that (including capacity reservation at the cluster and namespace levels). If you have heterogeneous GPUs in a single node, this becomes more difficult and outside the capabilities of any of those solutions.

## Validation

![](/assets/03-validation.gif)

## Automation key (Catch up)

- [ ] From this repository's root directory, run below command

```sh
./scripts/setup.sh -s 3
```
