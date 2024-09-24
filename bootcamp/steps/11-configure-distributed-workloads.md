## 11. Configure distributed workloads

**Why?**

1. You can iterate faster and experiment more frequently because of the reduced processing time.
1. You can use larger datasets, which can lead to more accurate models.
1. You can use complex models that could not be trained on a single node.
1. You can submit distributed workloads at any time, and the system then schedules the distributed workload when the required resources are available.

**Distributed Workloads is made of up a series of components.**

1. CodeFlare Operator - Secures deployed Ray clusters and grants access to their URLs
1. CodeFlare SDK - Defines and controls the remote distributed compute jobs and infrastructure for any Python-based environment
1. KubeRay - Manages remote Ray clusters on OpenShift for running distributed compute workloads
1. Kueue - Manages quotas and how distributed workloads consume them, and manages the queueing of distributed workloads with respect to quotas

You can run distributed workloads from data science pipelines, from Jupyter notebooks, or from Microsoft Visual Studio Code files.
[More Info](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/2.10/html/working_with_distributed_workloads/Configure-distributed-workloads_distributed-workloads)

Components required for Distributed Workloads

1. dashboard
1. workbenches
1. datasciencepipelines
1. codeflare operator
1. codeflare
1. kueue
1. ray

### Steps

- Verify the necessary pods are running - When the status of the codeflare-operator-manager-[pod-id], kuberay-operator-[pod-id], and kueue-controller-manager-[pod-id] pods is Running, the pods are ready to use.

    - ```sh
        oc get pods -n redhat-ods-applications | grep -E 'codeflare|kuberay|kueue'
        ```

        ```sh
        # expected output
        codeflare-operator-manager-6bbff698d-74fpz                        1/1     Running   7 (107m ago)   21h
        kuberay-operator-bf97858f4-zg45s                                  1/1     Running   8 (10m ago)    21h
        kueue-controller-manager-77c758b595-hgrz7                         1/1     Running   8 (10m ago)    21h
        ```

### Configure quota management for distributed workloads

#### Create an empty Kueue resource flavor

Resources in a cluster are typically not homogeneous. A ResourceFlavor is an object that describes these resource variations (i.e. Nvidia A100 versus T4 GPUs) and allows you to associate them with cluster nodes through labels, taints and tolerations.

A cluster administrator can create an empty ResourceFlavor object named `default-flavor`, without any labels or taints

In RHOAI, Red Hat supports only a single cluster queue per cluster (that is, homogenous clusters), and only empty resource flavors.

#### Steps
- Apply the configuration to create the `default-flavor`

    - ```sh
        oc apply -f configs/rhoai-kueue-default-flavor.yaml
        ```

        ```sh
        # expected output
        resourceflavor.kueue.x-k8s.io/default-flavor created
        ```

#### Create a cluster queue to manage the empty Kueue resource flavor

The Kueue ClusterQueue object manages a pool of cluster resources such as pods, CPUs, memory, and accelerators. A cluster can have multiple cluster queues, and each cluster queue can reference multiple resource flavors.

Cluster administrators can configure cluster queues to define the resource flavors that the queue manages, and assign a quota for each resource in each resource flavor. Cluster administrators can also configure usage limits and queueing strategies to apply fair sharing rules across multiple cluster queues in a cluster.

What is this cluster-queue doing? The example configures a cluster queue to assign a quota of 9 CPUs, 36 GiB memory, 5 pods, and 5 NVIDIA GPUs.

- The sum of the CPU requests is less than or equal to 9.
- The sum of the memory requests is less than or equal to 36Gi.
- The total number of pods is less than or equal to 5.

>![IMPORTANT]
Replace the example quota values (9 CPUs, 36 GiB memory, and 5 NVIDIA GPUs) with the appropriate values for your cluster queue. The cluster queue will start a distributed workload only if the total required resources are within these quota limits, otherwise the cluster queue does not admit the distributed workload.. Only homogenous NVIDIA GPUs are supported.

#### Steps

- Apply the configuration to create the `cluster-queue`

    - ```sh
        oc apply -f configs/rhoai-kueue-cluster-queue.yaml
        ```

        ```sh
        # expected output
        clusterqueue.kueue.x-k8s.io/cluster-queue created
        ```

#### Create a local queue that points to your cluster queue

A LocalQueue is a namespaced object that groups closely related Workloads that belong to a single namespace. Users submit jobs to a LocalQueue, instead of to a ClusterQueue directly. A cluster administrator can optionally define one local queue in a project as the default local queue for that project.

When Configure a distributed workload, the user specifies the local queue name. If a cluster administrator configured a default local queue, the user can omit the local queue specification from the distributed workload code.

In this example, the kueue.x-k8s.io/default-queue: "true" annotation defines this local queue as the default local queue for the `sandbox` project. If a user submits a distributed workload in the `sandbox` project and that distributed workload does not specify a local queue in the cluster configuration, Kueue automatically routes the distributed workload to the `local-queue-test` local queue. The distributed workload can then access the resources that the cluster-queue cluster queue manages.

>![NOTE]
Update the `name` and `namespace` accordingly.

#### Steps

- Apply the configuration to create the local-queue object

    - ```sh
        # go to sandbox
        oc project sandbox

        ## create local queue
        oc apply -f configs/rhoai-kueue-local-queue.yaml
        ```

        ```sh
        # expected output
        localqueue.kueue.x-k8s.io/local-queue-test created
        ```

How do users known what queues they can submit jobs to? Users submit jobs to a LocalQueue, instead of to a ClusterQueue directly. Tenants can discover which queues they can submit jobs to by listing the local queues in their namespace.

- Verify the local queue is created

    - ```sh
        oc get -n sandbox queues
        ```

        ```sh
        # expected output
        NAME               CLUSTERQUEUE    PENDING WORKLOADS   ADMITTED WORKLOADS
        local-queue-test   cluster-queue   0 
        ```