# 2. Enabling GPU support for RHOAI

<p align="center">
<a href="/docs/01-add-administrative-user.md">Prev</a>
&nbsp;&nbsp;&nbsp;
<a href="/docs/03-run-sample-gpu-application.md">Next</a>
</p>

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

      oc get nodes

> Expected output
>
> `NAME                                        STATUS   ROLES                         AGE     VERSION`\
> `ip-10-x-xx-xxx.us-xxxx-x.compute.internal   Ready    control-plane,master,worker   5h11m   v1.28.10+a2c84a5`

- [ ] View the machines and machine sets that exist in the openshift-machine-api namespace

      oc get machinesets -n openshift-machine-api

> Expected output
>
> `NAME                                    DESIRED   CURRENT   READY   AVAILABLE   AGE`\
> `cluster-xxxxx-xxxxx-worker-us-xxxx-xc   0         0                             5h13m`

- [ ] Make a copy of one of the existing compute MachineSet definitions and output the result to a YAML file

      # get your machineset name --no-headers removes the headers from the output. awk '{print $1}'. extracts the first column.
      # head -n 1 limits the output to the first entry.
      MACHINESET_COPY=$(oc get machinesets -n openshift-machine-api --no-headers | awk '{print $1}' | head -n 1)

      # make a copy of an existing machineset definition
      oc get machineset $MACHINESET_COPY -n openshift-machine-api -o yaml > scratch/machineset.yaml

- [ ] Edit the downloaded machineset.yaml and update the following fields:

  - [ ] ~Line 13`.metadata.name` to a name containing `-gpu`.
  - [ ] ~Line 18 `.spec.replicas` from `0` to `2`
  - [ ] ~Line 22`.spec.selector.matchLabels["machine.openshift.io/cluster-api-machineset"]` to match the new `.metadata.name`.
  - [ ] ~Line 29 `.spec.template.metadata.labels["machine.openshift.io/cluster-api-machineset"]` to match the new `.metadata.name`.
  - [ ] ~Line 51 `.spec.template.spec.providerSpec.value.instanceType` to `g4dn.4xlarge`.

> [!TIP]
> You can use `sed` or `yq` commands. However, sed is more limited and error-prone for complex YAML manipulations. If you have yq installed (a powerful YAML processor), it's much easier to handle such updates.

- [ ] Remove the following fields:

  - [ ] ~Line 10 `generation`
  - [ ] ~Line 16 `uid` (becomes line 15 if you delete line 10 first)
  - [ ] other fields as desired (such as `status` and `metadata.generation`)

- [ ] Apply the configuration to create the gpu machine

      oc apply -f scratch/machineset.yaml

> Expected output
>
> `machineset.machine.openshift.io/cluster-xxxx-xxxx-worker-us-xxxx-gpu created`

- [ ] Verify the gpu machineset you created is running

      oc -n openshift-machine-api get machinesets | grep gpu

> Expected output
>
> `cluster-xxxxx-xxxxx-worker-us-xxxx-xc-gpu   2         2         2       2           6m37s`

- [ ] View the Machine object that the machine set created

      oc -n openshift-machine-api get machines -w | grep gpu

> Expected output
>
> `cluster-xxxxx-xxxxx-worker-us-xxxx-xc-gpu-29whc   Running   g4dn.4xlarge   us-xxxx-x   us-xxxx-xc   7m59s`\
> `cluster-xxxxx-xxxxx-worker-us-xxxx-xc-gpu-nr59d   Running   g4dn.4xlarge   us-xxxx-x   us-xxxx-xc   7m59s`

## 3.2 Deploying the Node Feature Discovery Operator (takes time)

### Objectives

- Creating the Namespace, OperatorGroup, and Subscription for the NFD Operator

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

      oc get packagemanifests -n openshift-marketplace | grep nfd

> Expected output
>
> `openshift-nfd-operator                             Community Operators   8h`\
> `nfd                                                Red Hat Operators     8h`

- [ ] Apply the Namespace object

      oc apply -f configs/02/nfd-operator-ns.yaml

> Expected output
>
> `namespace/openshift-nfd created`

- [ ] Apply the OperatorGroup object

      oc apply -f configs/02/nfd-operator-group.yaml

> Expected output
>
> `operatorgroup.operators.coreos.com/nfd created`

- [ ] Apply the Subscription object

      oc apply -f configs/02/nfd-operator-sub.yaml

> Expected output
>
> `subscription.operators.coreos.com/nfd created`

- [ ] Verify the operator is installed and running

      # watch the pods get created in the new project
      oc get pods -n openshift-nfd -w

> Expected output
>
> `NAME                                      READY   STATUS    RESTARTS   AGE`\
> `...`\
> `nfd-controller-manager-78758c57f7-7xfh4   2/2     Running   0          48s`

> [!NOTE]
> After installing the NFD Operator, you create instance that installs the `nfd-master` and one `nfd-worker` pod for each compute node. [More Info](https://docs.openshift.com/container-platform/4.15/hardware_enablement/psap-node-feature-discovery-operator.html#Configure-node-feature-discovery-operator-sources_psap-node-feature-discovery-operator)

- [ ] Create the nfd instance object

      oc apply -f configs/02/nfd-instance.yaml

> Expected output
>
> `nodefeaturediscovery.nfd.openshift.io/nfd-instance created`

> [!IMPORTANT]
> The NFD Operator uses vendor PCI IDs to identify hardware in a node.

Below are some of the [PCI vendor ID assignments](https://pcisig.com/membership/member-companies?combine=10de):

| PCI id | Vendor |
| ------ | ------ |
| `10de` | NVIDIA |
| `1d0f` | AWS    |
| `1002` | AMD    |
| `8086` | Intel  |

- [ ] Verify the NFD pods are `Running` on the cluster nodes polling for devices

      oc get pods -n openshift-nfd

> Expected output
>
> `NAME                                      READY   STATUS    RESTARTS   AGE`\
> `nfd-controller-manager-78758c57f7-7xfh4   2/2     Running   0          99s`\
> `nfd-master-74db665cb6-vht4l               1/1     Running   0          25s`\
> `nfd-worker-8zkpz                          1/1     Running   0          25s`\
> `nfd-worker-d7wgh                          1/1     Running   0          25s`\
> `nfd-worker-l6sqx                          1/1     Running   0          25s`

- [ ] Verify the GPU device (NVIDIA uses the PCI ID `10de`) is discovered on the GPU node. This means the NFD Operator correctly identified the node from the GPU-enabled MachineSet.

      oc describe node | egrep 'Roles|pci' | grep -v master

> Expected output
>
> `Roles:              worker`\
> `                    feature.node.kubernetes.io/pci-10de.present=true`\
> `                    feature.node.kubernetes.io/pci-1d0f.present=true`\
> `                    feature.node.kubernetes.io/pci-1d0f.present=true`\
> `Roles:              worker`\
> `                    feature.node.kubernetes.io/pci-10de.present=true`\
> `                    feature.node.kubernetes.io/pci-1d0f.present=true`

> [!NOTE]
> You may have to rerun the command over a period of time as NFD pods come online and apply the labels before they show up.

## 3.3 Install the NVIDIA GPU Operator

### Objectives

- Creating the Namespace, OperatorGroup and Subscription to the NVIDIA GPU Operator

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

      oc get packagemanifests -n openshift-marketplace | grep gpu

> Expected output
>
> `amd-gpu-operator                                   Community Operators   8h`\
> `gpu-operator-certified                             Certified Operators   8h`

- [ ] Apply the Namespace object YAML file

      oc apply -f configs/02/nvidia-gpu-operator-ns.yaml

> Expected output
>
> `namespace/nvidia-gpu-operator created`

- [ ] Apply the OperatorGroup YAML file

      oc apply -f configs/02/nvidia-gpu-operator-group.yaml

> Expected output
>
> `operatorgroup.operators.coreos.com/nvidia-gpu-operator-group created`

- [ ] Apply the Subscription CR

      oc apply -f configs/02/nvidia-gpu-operator-subscription.yaml

> Expected output
>
> `subscription.operators.coreos.com/gpu-operator-certified created`

- [ ] Verify an install plan has been created. Be patient.

      # you can watch the installplan instances get created
      oc get installplan -n nvidia-gpu-operator -w

> Expected output
>
> `NAME            CSV                              APPROVAL    APPROVED`\
> `...`\
> `install-295r6   gpu-operator-certified.v24.6.1   Automatic   true`

- [ ] Create the cluster policy

      oc get csv -n nvidia-gpu-operator -l operators.coreos.com/gpu-operator-certified.nvidia-gpu-operator -ojsonpath='{.items[0].metadata.annotations.alm-examples}' | jq '.[0]' > scratch/nvidia-gpu-clusterpolicy.json

- [ ] Apply the clusterpolicy

      oc apply -f scratch/nvidia-gpu-clusterpolicy.json

> Expected output
>
> `clusterpolicy.nvidia.com/gpu-cluster-policy created`

> [!NOTE]
> At this point, the GPU Operator proceeds and installs all the required components to set up the NVIDIA GPUs in the OpenShift 4 cluster. Wait at least 10-20 minutes before digging deeper into any form of troubleshooting because this may take a period of time to finish.

- [ ] Verify the successful installation of the NVIDIA GPU Operator and deployment of the drivers

      oc get pod -l openshift.driver-toolkit -n nvidia-gpu-operator

> [!IMPORTANT]
> The Nvidia drivers are not loaded and ready for consumption until this command shows both pods at `2/2` ready. This means that the label selector used in the next step for labelling the nodes won't work either.

> Expected output
>
> `NAME                                                  READY   STATUS    RESTARTS   AGE`\
> `nvidia-driver-daemonset-416.94.202409191851-0-8mzb2   2/2     Running   0          5m34s`\
> `nvidia-driver-daemonset-416.94.202409191851-0-q5r7d   2/2     Running   0          5m34s`

> [!NOTE]
> With the daemonset deployed, NVIDIA GPUs have the `nvidia-device-plugin` and can be requested by a container using the `nvidia.com/gpu` resource type. The [NVIDIA device plugin](https://github.com/NVIDIA/k8s-device-plugin?tab=readme-ov-file#shared-access-to-gpus) has a number of options, like MIG Strategy, that can be configured for it. We will do this in a later step.

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

      oc label node -l nvidia.com/gpu.machine node-role.kubernetes.io/gpu=''

> Expected output
>
> `node/ip-10-x-xx-xxx.us-xxxx-x.compute.internal labeled`\
> `node/ip-10-x-xx-xxx.us-xxxx-x.compute.internal labeled`

- [ ] Get nodes to verify the label

      oc get nodes

> Expected output
>
> `NAME                                        STATUS   ROLES                         AGE   VERSION`\
> `...`\
> `ip-10-x-xx-xxx.us-xxxx-x.compute.internal   Ready    gpu,worker                    19h   v1.28.10+a2c84a5`\
> `ip-10-x-xx-xxx.us-xxxx-x.compute.internal   Ready    gpu,worker                    19h   v1.28.10+a2c84a5`\
> `...`

- [ ] Apply this label to new machines/nodes:

      # set an env value
      MACHINE_SET_TYPE=$(oc -n openshift-machine-api get machinesets.machine.openshift.io -o name | grep gpu | head -n1)

      # patch the machineset
      oc -n openshift-machine-api \
        patch "${MACHINE_SET_TYPE}" \
        --type=merge --patch '{"spec":{"template":{"spec":{"metadata":{"labels":{"node-role.kubernetes.io/gpu":""}}}}}}'

> Expected output
>
> `machineset.machine.openshift.io/cluster-xxxxx-xxxxx-worker-us-xxxx-xc-gpu patched`

> [!NOTE]
> At this time, the Nvidia operator creates an extended resource called `nvidia.com/gpu` on the nodes. `nvidia.com/gpu` is only used as a resource identifier, not anything else, in the context of differentiating GPU models (i.e. L40s, H100, V100, etc.). Node Selectors and Pod Affinity can still be configured arbitrarily. Later in this procedure, Distributed Workloads, `Kueue`, allows more granularity than that (including capacity reservation at the cluster and namespace levels). If you have heterogeneous GPUs in a single node, this becomes more difficult and outside the capabilities of any of those solutions.

## Validation

![](/assets/02-validation.gif)

## Automation key (Catch up)

- [ ] From this repository's root directory, run below command

```sh
./scripts/setup.sh -s 2
```

<p align="center">
<a href="/docs/01-add-administrative-user.md">Prev</a>
&nbsp;&nbsp;&nbsp;
<a href="/docs/03-run-sample-gpu-application.md">Next</a>
</p>
