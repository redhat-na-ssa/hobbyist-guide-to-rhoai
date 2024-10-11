# 4. (Optional) Running a sample GPU Application

### Objectives

- Run a simple CUDA VectorAdd that adds two vectors together

### Rationale

- Ensure the GPUs have bootstrapped correctly

### Takeaways

- This does demonstrate a way for researchers/DS to schedule work on the cluster without any additional subs.
- The nvidia-smi output is valuable and familiar for a variety of data points (CUDA Version, and Driver Version) that the operator handles install/config.

> Refer [(Here)](https://docs.nvidia.com/datacenter/cloud-native/openshift/latest/install-gpu-ocp.html#running-a-sample-gpu-application) for details

## Steps

- [ ] Create a test project

      oc project sandbox || oc new-project sandbox

> Expected output
>
> `Now using project "sandbox" on server "https://api.cluster-582gr.582gr.sandbox2642.opentlc.com:6443".`

- [ ] Create the sample app

      oc create -f configs/04/nvidia-gpu-sample-app.yaml

> [!NOTE]
> You may get a warning about PodSecurity Admission in addition to the notification that it was created, because we're not enforcing and simply auditing for the security violations in this pod. This is fine.

> Expected output
>
> `pod/cuda-vectoradd created`

- [ ] Check the logs of the container

      oc logs cuda-vectoradd

> Expected output
>
> `[Vector addition of 50000 elements]`\
> `Copy input data from the host memory to the CUDA device`\
> `CUDA kernel launch with 196 blocks of 256 threads`\
> `Copy output data from the CUDA device to the host memory`\
> `Test PASSED`\
> `Done`

- [ ] Get the sample app pods

      oc get pods

> Expected output
>
> `NAME             READY   STATUS      RESTARTS   AGE`\
> `cuda-vectoradd   0/1     Completed   0          54s`

- [ ] View the driver pods

      oc get pod -o wide -l openshift.driver-toolkit=true -n nvidia-gpu-operator

> Expected output
>
> `NAME                                                  READY   STATUS    RESTARTS   AGE   IP            NODE                                       NOMINATED NODE   READINESS GATES`\
> `nvidia-driver-daemonset-415.92.202407091355-0-64sml   2/2     Running   2          21h   10.xxx.0.x    ip-10-0-22-25.us-xxxx-x.compute.internal   <none>           <none>`\
> `nvidia-driver-daemonset-415.92.202407091355-0-clp7f   2/2     Running   2          21h   10.xxx.0.xx   ip-10-0-22-15.us-xxxx-x.compute.internal   <none>           <none>`

- [ ] Run the nvidia-smi command to see the GPU reporting in

      oc exec -itn nvidia-gpu-operator $(oc get pod -n nvidia-gpu-operator -l openshift.driver-toolkit=true -ojsonpath='{.items[0].metadata.name}') -- nvidia-smi

> Expected output
>
> `Fri Jul 26 20:06:33 2024`\
> `+-----------------------------------------------------------------------------------------+`\
> `| NVIDIA-SMI 550.54.15              Driver Version: 550.54.15      CUDA Version: 12.4     |`\
> `|-----------------------------------------+------------------------+----------------------+`\
> `| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |`\
> `| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |`\
> `|                                         |                        |               MIG M. |`\
> `|=========================================+========================+======================|`\
> `|   0  Tesla T4                       On  |   00000000:00:1E.0 Off |                    0 |`\
> `| N/A   34C    P8             14W /   70W |       0MiB /  15360MiB |      0%      Default |`\
> `|                                         |                        |                  N/A |`\
> `+-----------------------------------------+------------------------+----------------------+`
>
> `+-----------------------------------------------------------------------------------------+`\
> `| Processes:                                                                              |`\
> `|  GPU   GI   CI        PID   Type   Process name                              GPU Memory |`\
> `|        ID   ID                                                               Usage      |`\
> `|=========================================================================================|`\
> `|  No running processes found                                                             |`\
> `+-----------------------------------------------------------------------------------------+`

1. The first table reflects the information about all available GPUs (the example shows one GPU).
1. The second table provides details on the processes using the GPUs.

## Automation key (Catch up)

- [ ] From this repository's root directory, run below command

```sh
./scripts/setup.sh -s 4
```
