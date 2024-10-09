# 7. Install RHOAI Kserve Dependencies

### Objectives

- Understanding where we [deploy models](/docs/info-deploy-model.md) to and [ways to do it](/docs/info-model-serving.md)

### Rationale

- RHOAI provides 2x primary methods for serving models that you would choose depending on both resources constraints and inference use cases

### Takeaways

- `ModelMesh` is a general-purpose model serving management/routing layer designed for high-scale, high-density and frequently-changing model use cases. It has no extra dependencies.
- `KServe` provides an interface for serving predictive and generative machine learning (ML) models. It has has specific dependencies.
- [Single](https://kserve.github.io/website/0.8/modelserving/v1beta1/serving_runtime/) vs. [Multi-Model](https://kserve.github.io/website/0.8/modelserving/mms/multi-model-serving/) Serving
- [Runtimes](https://kserve.github.io/website/0.8/modelserving/servingruntimes/) vs. Model Servers

## 7.1 Install RHOS Service Mesh Operator

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

- [ ] Create the required namespace for Red Hat OpenShift Service Mesh.

```sh
oc create ns istio-system
```

```sh
# expected output
namespace/istio-system created
```

Apply the Service Mesh subscription to install the operator

```sh
oc create -f configs/07/servicemesh-subscription.yaml
```

```sh
# expected output
subscription.operators.coreos.com/servicemeshoperator created
```

> NOTE: For `Unmanaged` configuration details, see the \_APPENDIX.md.

## 7.2 Install Red Hat OpenShift Serverless Operator

### Objectives

- Creating the Namespace, OperatorGroup and subscribing to the Serverless Operator

### Rationale

- RHOAI KServe needs Serverless (by default), just like KServe requires Knative Serving for auto-scaling, canary rollout.

### Takeaways

- Knative serverless deployment for predictor, transformer, explainer to enable autoscaling based on incoming request workload including scaling down to zero when no traffic is received.

## Steps

- [ ] Create the Serverless Operator objects

```sh
oc create -f configs/07/serverless-operator.yaml
```

```sh
# expected output
namespace/openshift-serverless created
operatorgroup.operators.coreos.com/serverless-operator created
subscription.operators.coreos.com/serverless-operator created
```

> For `Unmanaged` deployments additional steps need to be executed. See the Define a ServiceMeshMember for Serverless in the \_APPENDIX.md

## 7.3 Install Red Hat Authorino Operator

### Objectives

- Subscribing the RH Authorino Operator

### Rationale

- To front services with Auth{n,z}, Authorino provides an authorization proxy (using Envoy) for publicly exposed KServe inference endpoint.

### Takeaways

- Without Authorino, model endpoints are insecure and accessible to anyone
- Authorino implements [Envoy Proxy](https://www.envoyproxy.io/)'s [external authorization](https://www.envoyproxy.io/docs/envoy/latest/start/sandboxes/ext_authz) gRPC protocol, and is a part of Red Hat [Kuadrant](https://github.com/kuadrant) architecture.
- Good [FAQs](https://github.com/kuadrant/authorino?tab=readme-ov-file#faq) section

## Steps

- [ ] Create the Authorino subscription

```sh
oc create -f configs/07/authorino-subscription.yaml
```

```sh
# expected output
subscription.operators.coreos.com/authorino-operator created
```

> For `Unmanaged` deployments additional steps need to be executed. See the Configure Authorino for Unmanaged deployments in the \_APPENDIX.md

## Validation

![](/assets/07-validation.gif)

## Automation key (Catch up)

- [ ] From this repository's root directory, run below command

```sh
./scripts/setup.sh -s 7
```