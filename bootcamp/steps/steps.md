# RHOAI BootCamp Installation Instructions

Before you install RHOAI, it is important to understand how it's dependencies will be managed as it be automated or not. Below are required and **use-case dependent operators**:

| Operator                                        | Description                                                           |
|-------------------------------------------------|-----------------------------------------------------------------------|
|`Red Hat OpenShift Serverless Operator`          | if RHOAI KServe is planned for serving, this is required              |
|`Red Hat OpenShift Service Mesh Operator`        | if RHOAI KServe is planned for serving, this is required              |
|`Red Hat Authorino Operator`                     | if you want to authenticate KServe model API endpoints with a route   |
|`Red Hat Node Feature Discovery (NFD) Operator`  | if additional hardware features are being utilized, like GPU          |
|`NVIDIA GPU Operator`                            | if NVIDIA GPU accelerators exist                                      |
|`NVIDIA Network Operator`                        | if NVIDIA Infiniband accelerators exist                               |
|`Kernel Module Management (KMM) Operator`        | if Intel Gaudi/AMD accelerators exist                                 |
|`HabanaAI Operator`                              | if Intel Gaudi accelerators exist                                     |
|`AMD GPU Operator`                               | if AMD accelerators exist                                             |

>NOTE: `NFD` and `KMM` operators exists with other patterns, these are the most common.

### RHOAI Component States

There are 3x RHOAI Operator dependency states to be set: `Managed`, `Removed`, and `Unmanaged`.

| State      |   Description                                                            |
|------------|--------------------------------------------------------------------------|
|`Managed`   |The RHOAI Operator manages the dependency (i.e. `Service Mesh`, `Serverless`, etc.). RHOAI manages the operands, not the operators. This is where `FeatureTrackers` come into play.|
|`Removed`   | The RHOAI Operator removes the dependency. Changing from `Managed` to `Removed` does remove the dependency|
|`Unmanaged` | The RHAOI Operator does not manage the dependency allowing for an administrator to manage it instead.  Changing from `Managed` to `Unmanaged` does not remove the dependency. For example, this is important when the customer has an existing Service Mesh. It won't create it when it doesn't exist, but you can make manual changes.|

## Steps

1. [Add administrative user](/bootcamp/steps/step1-add-administrative-user.md)
1. [(Optional) Install the web terminal]()
1. [Install RHOAI Kserve depndencies](/bootcamp/steps/step3-install-kserve-dependencies.md)