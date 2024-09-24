## 3. Install RHOAI Kserve Dependencies

RHOAI provides 2x primary methods for serving models that you would choose depending on both resources constraints and inference use cases:

1. `Model Mesh`
1. `KServe`

The `ModelMesh` framework is a general-purpose model serving management/routing layer designed for high-scale, high-density and frequently-changing model use cases. There are no extra dependencies needed to configure this solution.

`KServe` has specific dependencies and provides an interface for serving predictive and generative machine learning (ML) models.

- To support the RHOAI KServe component, you must also install Operators for `Red Hat OpenShift Service Mesh` (based on `Istio`) and `Red Hat OpenShift Serverless` (based on  `Knative`). Furthermore, if you want to add an authorization provider, you must also install `Red Hat Authorino Operator` (based on `Kuadrant`).

Because `Service Mesh`, `Serverless`, and `Authorino` will be `Managed` in this procedure, we only need to install the operators. We will not configure instances (i.e. control plane, members, etc.).

## 3.1 Install RHOS Service Mesh Operator
A service mesh is an infrastructure layer that simplifies the communication between services in a loosely-coupled/ microservices architecture without requiring any changes to the application code. It includes a collection of lightweight network proxies, known as sidecars, which are placed next to each service in the system.

Red Hat OpenShift Service Mesh, is based on the open source Istio project.

Service Mesh is made up of a `data plane` (service discovery, health checks, routing, load balancing, Authn and Authz, and observability) and `control plane` (configuration and policy for all of the data planes).

How Istio relates to KServe:

1. `KServe (Inference) Data Plane` - consists of a static graph of components (predictor, transformer, explainer) which coordinate requests for a single model. Advanced features such as Ensembling, A/B testing, and Multi-Arm-Bandits should compose InferenceServices together.
1. `KServe Control Plane` - creates the Knative serverless deployment for predictor, transformer, explainer to enable autoscaling based on incoming request workload including scaling down to zero when no traffic is received. When raw deployment mode is enabled, control plane creates Kubernetes deployment, service, ingress, HPA.

### Steps

- Create the required namespace for Red Hat OpenShift Service Mesh.

    - ```sh
        oc create ns istio-system
        ```

         ```sh
        # expected output
        namespace/istio-system created
        ```
- Apply the Service Mesh subscription to install the operator

    - ```sh
        oc create -f configs/servicemesh-subscription.yaml
        ```

         ```sh
        # expected output
        subscription.operators.coreos.com/servicemeshoperator created
        ```

>NOTE: For `Unmanaged` configuration details, see the _APPENDIX.md.

## 3.2 Install Red Hat OpenShift Serverless Operator

Serverless computing is a method of providing backend services on an as-used basis. Servers are still used to execute code. However, developers of serverless applications are not concerned with capacity planning, configuration, management, maintenance, fault tolerance, or scaling of containers, virtual machines, or physical servers. Overall, serverless computing can simplify the process of deploying code into production.

OpenShift Serverless provides Kubernetes native building blocks that enable developers to create and deploy serverless, event-driven applications on RHOCP. It's is based on the open source Knative project, which provides portability and consistency for hybrid and multi-cloud environments by a providing a platform-agnostic solution for running serverless deployments.   
[More Info Serverless](https://docs.redhat.com/en/documentation/red_hat_openshift_serverless/1.33/html/about_openshift_serverless/about-serverless)     
[More info Knative](https://access.redhat.com/documentation/en-us/red_hat_openshift_ai_self-managed/2.10/html/serving_models/serving-large-models_serving-large-models#creating-a-knative-serving-instance_serving-large-models)

### Steps

- Create the Serverless Operator objects

    - ```sh
        oc create -f configs/serverless-operator.yaml
        ```

        ```sh
        # expected output
        namespace/openshift-serverless created
        operatorgroup.operators.coreos.com/serverless-operator created
        subscription.operators.coreos.com/serverless-operator created
        ```

>For `Unmanaged` deployments additional steps need to be executed. See the Define a ServiceMeshMember for Serverless in the _APPENDIX.md

## 3.3 Install Red Hat Authorino Operator

In order to front services with Auth{n,z}, Authorino provides an authorization proxy (using Envoy) for publicly  exposed [KServe inference endpoint](https://access.redhat.com/documentation/en-us/red_hat_openshift_ai_self-managed/2.10/html/serving_models/serving-large-models_serving-large-models#manually-adding-an-authorization-provider_serving-large-models). You can enable token authorization for models that you expose outside the platform to ensure that only authorized parties can make inference requests.

### Steps

- Create the Authorino subscription
    
    - ```sh
        oc create -f configs/authorino-subscription.yaml
        ```

        ```sh
        # expected output
        subscription.operators.coreos.com/authorino-operator created
        ```

>For `Unmanaged` deployments additional steps need to be executed. See the Configure Authorino for Unmanaged deployments in the _APPENDIX.md