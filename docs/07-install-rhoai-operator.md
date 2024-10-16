# 7. Install RHOAI operator

<p align="center">
<a href="/docs/06-install-kserve-dependencies.md">Prev</a>
&nbsp;&nbsp;&nbsp;
<a href="/docs/08-configure-rhoai.md">Next</a>
</p>

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

> [!NOTE] > `NFD` and `KMM` operators exists with other patterns, these are the most common. More information is available [here](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/2.10/html/Install_and_unInstall_openshift_ai_self-managed/Install-and-deploying-openshift-ai_install#Install-the-openshift-data-science-operator_operator-install)

## Steps

- [ ] Check the pre-requisite operators in order to fully deploy RHOAI components.

      oc get subscriptions -A

> Expected output
>
> `NAMESPACE              NAME                                                                PACKAGE                 SOURCE             CHANNEL`\
> `openshift-operators    authorino-operator                                                  authorino-operator      redhat-operators   tech-preview-v1`\
> `openshift-operators    devworkspace-operator-fast-redhat-operators-openshift-marketplace   devworkspace-operator   redhat-operators   fast`\
> `openshift-operators    servicemeshoperator                                                 servicemeshoperator     redhat-operators   stable`\
> `openshift-operators    web-terminal                                                        web-terminal            redhat-operators   fast`\
> `openshift-serverless   serverless-operator                                                 serverless-operator     redhat-operators   stable`

- [ ] Create the namespace in your RHOCP cluster

      oc create -f configs/07/rhoai-operator-ns.yaml

> Expected output
>
> `namespace/redhat-ods-operator created`

- [ ] Create the OperatorGroup object

      oc create -f configs/07/rhoai-operator-group.yaml

> Expected output
>
> `operatorgroup.operators.coreos.com/rhods-operator created`

> [!NOTE]
> We are using `stable` channel as this gives customers access to the stable product features. `fast` can lead to an inconsistent experience as it is only supported for 1 month and it is updated every month. More information about supported versions, channels, and their characteristics is available [here](https://access.redhat.com/articles/rhoai-supported-configs).

- [ ] Create the Subscription object

      oc create -f configs/07/rhoai-operator-subscription.yaml

> Expected output
>
> `subscription.operators.coreos.com/rhods-operator created`

- [ ] Verify at least these projects are created `redhat-ods-applications|redhat-ods-monitoring|redhat-ods-operator`

      oc get projects -w | grep -E "redhat-ods|rhods"

> Expected output
>
> `redhat-ods-applications                                                           Active`\
> `redhat-ods-applications-auth-provider                                             Active`\
> `redhat-ods-monitoring                                                             Active`\
> `redhat-ods-operator                                                               Active`

- When you install the RHOAI Operator in the OpenShift cluster, the following new projects are created:
  1. `redhat-ods-applications` contains the dashboard and other required components of OpenShift AI. Additionally, this is where the included notebook images are stored as `ImageStreams`.
  1. `redhat-ods-applications-auth-provider` is where Authorino would be configured to run, in support of authenticating KServe model inference endpoints.
  1. `redhat-ods-monitoring` contains services for monitoring.
  1. `redhat-ods-operator` contains the RHOAI Operator itself.
  1. `rhods-notebooks` is a namespace that will get created later, where an individual user notebook environments are deployed by default. You or your data scientists must create additional projects for the applications that will use your machine learning models.

> [!IMPORTANT]
> Do not install independent software vendor (ISV) applications in namespaces associated with OpenShift AI.

- The RHOAI Operator is installed with a `default-dsci` object with the following. Notice how the `serviceMesh` is `Managed`. By default, RHOAI is managing `ServiceMesh`.

- [ ] Verify `default-dsci` yaml file

      oc describe DSCInitialization -n redhat-ods-operator

> Expected output
>
> `Name:         default-dsci`\
> `API Version:  dscinitialization.opendatahub.io/v1`\
> `Kind:         DSCInitialization`\
> `Spec:`\
> `  Applications Namespace:  redhat-ods-applications`\
> `  Monitoring:`\
> `    Management State:  Managed`\
> `    Namespace:         redhat-ods-monitoring`\
> `  Service Mesh:`\
> `    Auth:`\
> `      Audiences:`\
> `        https://kubernetes.default.svc`\
> `    Control Plane:`\
> `      Metrics Collection:  Istio`\
> `      Name:                data-science-smcp`\
> `      Namespace:           istio-system`\
> `    Management State:      Unmanaged`\
> `  Trusted CA Bundle:`\
> `  Custom CA Bundle:`\
> `    Management State:  Managed`

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

> [!NOTE]
> In order to use RHOAI functionality, you must create a DataScienceCluster instance.
> When you manually installed KServe, you set the value of the managementState to `Unmanaged` within the Kserve component in the DataScienceCluster and MUST update the DSCInitialization object.
> For `Unmanaged` dependencies, see the Install and managing RHOAI components on the \_APPENDIX.md.

- [ ] Create the DSC object

      oc create -f configs/07/rhoai-operator-dsc.yaml

> Expected output
>
> `datasciencecluster.datasciencecluster.opendatahub.io/default-dsc created`

- [ ] Wait for the DSC to show Ready

> [!NOTE]
> This may take up to around ten minutes.

    oc wait --for=jsonpath='{.status.phase}'=Ready datasciencecluster default-dsc --timeout=15m

> Expected output
>
> `datasciencecluster.datasciencecluster.opendatahub.io/default-dsc condition met`

- [ ] Verify DSC and related object creation

      oc get DataScienceCluster,DSCInitialization,FeatureTracker -n redhat-ods-operator

> Expected output
>
> `NAME                                                               AGE`\
> `datasciencecluster.datasciencecluster.opendatahub.io/default-dsc   4m31s`
>
> `NAME                                                              AGE     PHASE   CREATED AT`\
> `dscinitialization.dscinitialization.opendatahub.io/default-dsci   7m43s   Ready   2024-10-11T17:49:37Z`
>
> `NAME                                                                                                            AGE`\
> `featuretracker.features.opendatahub.io/redhat-ods-applications-enable-proxy-injection-in-authorino-deployment   7m13s`\
> `featuretracker.features.opendatahub.io/redhat-ods-applications-kserve-external-authz                            85s`\
> `featuretracker.features.opendatahub.io/redhat-ods-applications-mesh-control-plane-creation                      7m39s`\
> `featuretracker.features.opendatahub.io/redhat-ods-applications-mesh-control-plane-external-authz                7m17s`\
> `featuretracker.features.opendatahub.io/redhat-ods-applications-mesh-metrics-collection                          7m19s`\
> `featuretracker.features.opendatahub.io/redhat-ods-applications-mesh-shared-configmap                            7m17s`\
> `featuretracker.features.opendatahub.io/redhat-ods-applications-serverless-net-istio-secret-filtering            92s`\
> `featuretracker.features.opendatahub.io/redhat-ods-applications-serverless-serving-deployment                    112s`\
> `featuretracker.features.opendatahub.io/redhat-ods-applications-serverless-serving-gateways                      88s`

## Validation

![](/assets/07-validation.gif)

## Automation key (Catch up)

- [ ] From this repository's root directory, run below command

```sh
./scripts/setup.sh -s 8
```

<p align="center">
<a href="/docs/06-install-kserve-dependencies.md">Prev</a>
&nbsp;&nbsp;&nbsp;
<a href="/docs/08-configure-rhoai.md">Next</a>
</p>
