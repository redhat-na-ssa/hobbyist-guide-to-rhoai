# 8. Install RHOAI operator

### Objectives

- Creating the Namespace, OperatorGroup and subscribing Serverless Operator

### Rationale

- Needed to run AI demos

### Takeaways

- Stable vs fast product features.
- Fast can lead to an inconsistent experience as it is only supported for 1 month and it updated every month (source)
- Review the default-dsci
- Review the created projects

Before you install RHOAI, it is important to understand how it's dependencies will be managed as it be automated or not. Below are required and **use-case dependent operators**:

| Operator                                        | Description                                                         |
| ----------------------------------------------- | ------------------------------------------------------------------- |
| `Red Hat OpenShift Serverless Operator`         | if RHOAI KServe is planned for serving, this is required            |
| `Red Hat OpenShift Service Mesh Operator`       | if RHOAI KServe is planned for serving, this is required            |
| `Red Hat Authorino Operator`                    | if you want to authenticate KServe model API endpoints with a route |
| `Red Hat Node Feature Discovery (NFD) Operator` | if additional hardware features are being utilized, like GPU        |
| `NVIDIA GPU Operator`                           | if NVIDIA GPU accelerators exist                                    |
| `NVIDIA Network Operator`                       | if NVIDIA Infiniband accelerators exist                             |
| `Kernel Module Management (KMM) Operator`       | if Intel Gaudi/AMD accelerators exist                               |
| `HabanaAI Operator`                             | if Intel Gaudi accelerators exist                                   |
| `AMD GPU Operator`                              | if AMD accelerators exist                                           |

> [!NOTE]
> `NFD` and `KMM` operators exists with other patterns, these are the most common.  
> [More Info](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/2.10/html/Install_and_unInstall_openshift_ai_self-managed/Install-and-deploying-openshift-ai_install#Install-the-openshift-data-science-operator_operator-install)

## Steps

- [ ] Check the pre-requisite operators in order to fully deploy RHOAI components.

```sh
oc get subscriptions -A
```

```sh
# expected output
NAMESPACE              NAME                                                                PACKAGE                 SOURCE             CHANNEL
openshift-operators    authorino-operator                                                  authorino-operator      redhat-operators   tech-preview-v1
openshift-operators    devworkspace-operator-fast-redhat-operators-openshift-marketplace   devworkspace-operator   redhat-operators   fast
openshift-operators    servicemeshoperator                                                 servicemeshoperator     redhat-operators   stable
openshift-operators    web-terminal                                                        web-terminal            redhat-operators   fast
openshift-serverless   serverless-operator                                                 serverless-operator     redhat-operators   stable
```

- [ ] Create the namespace in your RHOCP cluster

```sh
oc create -f configs/08/rhoai-operator-ns.yaml
```

```sh
# expected output
namespace/redhat-ods-operator created
```

- [ ] Create the OperatorGroup object

```sh
oc create -f configs/08/rhoai-operator-group.yaml
```

```sh
# expected output
operatorgroup.operators.coreos.com/rhods-operator created
```

> Understanding `update channels`. We are using `stable` channel as this gives customers access to the stable product features. `fast` can lead to an inconsistent experience as it is only supported for 1 month and it updated every month. [More Info](https://access.redhat.com/articles/rhoai-supported-configs).

- [ ] Create the Subscription object

```sh
oc create -f configs/08/rhoai-operator-subscription.yaml
```

```sh
# expected output
subscription.operators.coreos.com/rhods-operator created
```

- [ ] Verify at least these projects are created `redhat-ods-applications|redhat-ods-monitoring|redhat-ods-operator`

```sh
oc get projects -w | grep -E "redhat-ods|rhods"
```

```sh
# expected output
redhat-ods-applications                                                           Active
redhat-ods-applications-auth-provider                                             Active
redhat-ods-monitoring                                                             Active
redhat-ods-operator                                                               Active
```

When you install the RHOAI Operator in the OpenShift cluster, the following new projects are created:

1. `redhat-ods-operator` contains the RHOAI Operator.
1. `redhat-ods-applications` installs the dashboard and other required components of OpenShift AI.
1. `redhat-ods-monitoring` contains services for monitoring.

Note:

- `rhods-notebooks` is where an individual user notebook environments are deployed by default.
- You or your data scientists must create additional projects for the applications that will use your machine learning models.

> IMPORTANT
> Do not install independent software vendor (ISV) applications in namespaces associated with OpenShift AI.

The RHOAI Operator is installed with a `default-dsci` object with the following. Notice how the `serviceMesh` is `Managed`. By default, RHOAI is managing `ServiceMesh`.

- [ ] Verify `default-dsci` yaml file

```sh
oc describe DSCInitialization -n redhat-ods-operator
```

```yaml
# expected output
---
apiVersion: dscinitialization.opendatahub.io/v1
kind: DSCInitialization
metadata:
finalizers:
- dscinitialization.opendatahub.io/finalizer
name: default-dsci
spec:
applicationsNamespace: redhat-ods-applications
monitoring:
managementState: Managed
namespace: redhat-ods-monitoring
serviceMesh:
auth:
audiences:
  - "https://kubernetes.default"
controlPlane:
metricsCollection: Istio
name: data-science-smcp
namespace: istio-system
managementState: Managed
trustedCABundle:
customCABundle: ""
managementState: Managed
```

## 8.1 Install RHOAI components

### Objectives

- Defining the components we want to use

### Rationale

- In order to use the RHOAI Operator, you must create a DataScienceCluster instance.

### Takeaways

- The Channel, DSC and DSCI are critical
- When you manually installed KServe, you set the value of the managementState to Unmanaged within the Kserve component in the DataScienceCluster and MUST update the DSCInitialization object.

#### RHOAI Component States

There are 3x RHOAI Operator dependency states to be set: `Managed`, `Removed`, and `Unmanaged`.

| State       | Description                                                                                                                                                                                                                                                                                                                            |
| ----------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Managed`   | The RHOAI Operator manages the dependency (i.e. `Service Mesh`, `Serverless`, etc.). RHOAI manages the operands, not the operators. This is where `FeatureTrackers` come into play.                                                                                                                                                    |
| `Removed`   | The RHOAI Operator removes the dependency. Changing from `Managed` to `Removed` does remove the dependency                                                                                                                                                                                                                             |
| `Unmanaged` | The RHAOI Operator does not manage the dependency allowing for an administrator to manage it instead. Changing from `Managed` to `Unmanaged` does not remove the dependency. For example, this is important when the customer has an existing Service Mesh. It won't create it when it doesn't exist, but you can make manual changes. |

## Steps

> In order to use the RHOAI Operator, you must create a DataScienceCluster instance.
> When you manually installed KServe, you set the value of the managementState to `Unmanaged` within the Kserve component in the DataScienceCluster and MUST update the DSCInitialization object.  
> For `Unmanaged` dependencies, see the Install and managing RHOAI components on the \_APPENDIX.md.

- [ ] Create the DSC object

```sh
oc create -f configs/08/rhoai-operator-dsc.yaml
```

```sh
# expected output

datasciencecluster.datasciencecluster.opendatahub.io/default-dsc created
```

- [ ] Verify DSC object creation

```sh
oc get DSCInitialization,FeatureTracker -n redhat-ods-operator
```

```sh
# expected output
NAME                                                              AGE   PHASE   CREATED AT
dscinitialization.dscinitialization.opendatahub.io/default-dsci   10m   Ready   2024-07-31T22:35:06Z

NAME                                                                                                   AGE
featuretracker.features.opendatahub.io/redhat-ods-applications-kserve-external-authz                   94s
featuretracker.features.opendatahub.io/redhat-ods-applications-mesh-control-plane-creation             10m
featuretracker.features.opendatahub.io/redhat-ods-applications-mesh-control-plane-external-authz       10m
featuretracker.features.opendatahub.io/redhat-ods-applications-mesh-metrics-collection                 10m
featuretracker.features.opendatahub.io/redhat-ods-applications-mesh-shared-configmap                   10m
featuretracker.features.opendatahub.io/redhat-ods-applications-serverless-net-istio-secret-filtering   101s
featuretracker.features.opendatahub.io/redhat-ods-applications-serverless-serving-deployment           2m19s
featuretracker.features.opendatahub.io/redhat-ods-applications-serverless-serving-gateways             97s
```

## Validation

![](/assets/08-validation.gif)

## Automation key (Catch up)

- [ ] From this repository's root directory, run below command

```sh
./scripts/setup.sh -s 8
```
