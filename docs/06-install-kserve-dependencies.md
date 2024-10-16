# 6. Install RHOAI Kserve Dependencies

<p align="center">
<a href="/docs/05-configure-gpu-sharing-method.md">Prev</a>
&nbsp;&nbsp;&nbsp;
<a href="/docs/07-install-rhoai-operator.md">Next</a>
</p>

### Objectives

- Understanding where we [deploy models](/docs/info-deploy-model.md) to and [ways to do it](/docs/info-model-serving.md)

### Rationale

- RHOAI provides 2x primary methods for serving models that you would choose depending on both resources constraints and inference use cases

### Takeaways

- `ModelMesh` is a general-purpose model serving management/routing layer designed for high-scale, high-density and frequently-changing model use cases. It has no extra dependencies.
- `KServe` provides an interface for serving predictive and generative machine learning (ML) models. It has has specific dependencies.
- [Single](https://kserve.github.io/website/0.8/modelserving/v1beta1/serving_runtime/) vs. [Multi-Model](https://kserve.github.io/website/0.8/modelserving/mms/multi-model-serving/) Serving
- [Runtimes](https://kserve.github.io/website/0.8/modelserving/servingruntimes/) vs. Model Servers

## 6.1 Install the OpenShift Service Mesh Operator

### Objectives

- Creating the Namespace and subscribing to the Service Mesh Operator

### Rationale

- RHOAI KServe needs Service Mesh (by default), just like KServe requires Istio for traffic routing and ingress.

### Takeaways

- Data plane (service discovery, health checks, routing, load balancing, Authn and Authz, and observability)
  - [KServe (Inference) Data Plane](https://kserve.github.io/website/latest/modelserving/data_plane/data_plane/) - consists of a static graph of components (predictor, transformer, explainer) which coordinate requests for a single model.
- Control plane (configuration and policy for all of the data planes).
  - [KServe Control Plane](https://kserve.github.io/website/latest/modelserving/control_plane/) - creates the Knative serverless deployment for predictor, transformer, explainer to enable autoscaling based on incoming request workload including scaling down to zero when no traffic is received.

## Steps

> [!WARNING]
> Do not create the ServiceMeshControlPlane object, as you would if interactively installing OpenShift Service Mesh in the web console.

- [ ] Apply the Service Mesh subscription to install the operator

      oc create -f configs/06/servicemesh-subscription.yaml

> Expected output
>
> `subscription.operators.coreos.com/servicemeshoperator created`

> [!NOTE]
> For `Unmanaged` configuration details, see the \_APPENDIX.md.

## 6.2 Install Red Hat OpenShift Serverless Operator

### Objectives

- Creating the Namespace, OperatorGroup and subscribing to the Serverless Operator

### Rationale

- RHOAI KServe needs Serverless (by default), just like KServe requires Knative Serving for auto-scaling, canary rollout.

### Takeaways

- Knative serverless deployment for predictor, transformer, explainer to enable autoscaling based on incoming request workload including scaling down to zero when no traffic is received.

## Steps

> [!WARNING]
> Do not create the KnativeServing object, as you would if interactively installing OpenShift Serverless in the web console.

- [ ] Create the Serverless Operator objects

      oc create -f configs/06/serverless-operator.yaml

> Expected output
>
> `namespace/openshift-serverless created`\
> `operatorgroup.operators.coreos.com/serverless-operator created`\
> `subscription.operators.coreos.com/serverless-operator created`

> [!NOTE]
> For `Unmanaged` deployments additional steps need to be executed. See the Define a ServiceMeshMember for Serverless in the \_APPENDIX.md

## 6.3 Install Red Hat Authorino Operator

### Objectives

- Subscribing the RH Authorino Operator

### Rationale

- To front services with Auth{n,z}, Authorino provides an authorization proxy (using Envoy) for publicly exposed KServe inference endpoint.

### Takeaways

- Without Authorino, model endpoints are insecure and accessible to anyone
- Authorino implements [Envoy Proxy](https://www.envoyproxy.io/)'s [external authorization](https://www.envoyproxy.io/docs/envoy/latest/start/sandboxes/ext_authz) gRPC protocol, and is a part of Red Hat [Kuadrant](https://github.com/kuadrant) architecture.
- Good [FAQs](https://github.com/kuadrant/authorino?tab=readme-ov-file#faq) section

## Steps

> [!WARNING]
> Do not create the Authorino object, as you would if interactively installing Authorino in the web console.

- [ ] Create the Authorino subscription

      oc create -f configs/06/authorino-subscription.yaml

> Expected output
>
> `subscription.operators.coreos.com/authorino-operator created`

> [!NOTE]
> For `Unmanaged` deployments additional steps need to be executed. See the Configure Authorino for Unmanaged deployments in the \_APPENDIX.md

## Validation

![](/assets/06-validation.gif)

## Automation key (Catch up)

- [ ] From this repository's root directory, run below command

```sh
./scripts/setup.sh -s 6
```

<p align="center">
<a href="/docs/05-configure-gpu-sharing-method.md">Prev</a>
&nbsp;&nbsp;&nbsp;
<a href="/docs/07-install-rhoai-operator.md">Next</a>
</p>
