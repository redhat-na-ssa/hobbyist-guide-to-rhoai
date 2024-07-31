## Fix kubeadmin as an Administrator for Openshift AI (~2 min)

`kubeadmin` user is an automatically generated temporary user. Best practice is to create a new user using an identity provider and elevate the privileges of that user to `cluster-admin`. Once such user is created, the default `kubeadmin` user should be removed. [source](https://access.redhat.com/solutions/5309141)

RHOAI also stipulates 'Access to the cluster as a user with the cluster-admin role; the kubeadmin user is not allowed.'

Create a cluster role binding so that OpenShift AI will recognize `kubeadmin` as a `cluster-admin`

```yaml
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: fix-rhoai-kubeadmin
subjects:
  - kind: User
    apiGroup: rbac.authorization.k8s.io
    name: 'kube:admin'
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
```

```sh
oc apply -f configs/fix-kubeadmin.yaml
```

```sh
# expected output
clusterrolebinding.rbac.authorization.k8s.io/fix-rhoai-kubeadmin created
```

## Red Hat Service Mesh Control Plane

Assuming the 03_CHECKLIST_PROCEDURE.md was completed and the intended end state is not to allow RHOAI to `manage` Red Hat Service Mesh, complete these steps.

Define a ServiceMeshControlPlane object. The control plane acts as the central management and configuration layer of the service mesh. With the control plane, administrators can define and configure the services within the mesh.

```yaml
apiVersion: maistra.io/v2
kind: ServiceMeshControlPlane
metadata:
  name: minimal
  namespace: istio-system
spec:
  tracing:
    type: None
  addons:
    grafana:
      enabled: false
    kiali:
      name: kiali
      enabled: false
    prometheus:
      enabled: false
    jaeger:
      name: jaeger
  security:
    dataPlane:
      mtls: true
    identity:
      type: ThirdParty
  techPreview:
    meshConfig:
      defaultConfig:
        terminationDrainDuration: 35s
  gateways:
    ingress:
      service:
        metadata:
          labels:
            knative: ingressgateway
  proxy:
    networking:
      trafficControl:
        inbound:
          excludedPorts:
            - 8444
            - 8022
```

[Service Mesh configuration definition](https://docs.openshift.com/container-platform/4.15/service_mesh/v2x/ossm-reference-smcp.html)

Apply the servicemesh control plane object.

```sh
oc create -f configs/servicemesh-scmp.yaml
```

```sh
# expected output
servicemeshcontrolplane.maistra.io/minimal created
```

Verify the pods are running for the service mesh control plane, ingress gateway, and egress gateway

```sh
oc get pods -n istio-system
```

```sh
# expected output
istio-egressgateway-f9b5cf49c-c7fst    1/1     Running   0          59s
istio-ingressgateway-c69849d49-fjswg   1/1     Running   0          59s
istiod-minimal-5c68bf675d-whrns        1/1     Running   0          68s
```

## FeatureTracker Error

FeatureTrack error fix. There are two objects that are in an error state after installation at this point.

FeatureTracker Phase: Error
redhat-ods-applications-mesh-metrics-collection
redhat-ods-applications-mesh-control-plane-creation

```sh
# get the mutatingwebhook
oc get MutatingWebhookConfiguration -A | grep -i maistra

# delete the mutatingwebhook
oc delete MutatingWebhookConfiguration/openshift-operators.servicemesh-resources.maistra.io -A

# get the validatingwebhook
oc get ValidatingWebhookConfiguration -A | grep -i maistra

# delete the validatingwebhook
oc delete ValidatingWebhookConfiguration/openshift-operators.servicemesh-resources.maistra.io -A

# delete the FeatureTracker
oc delete FeatureTracker/redhat-ods-applications-mesh-control-plane-creation -A
oc delete FeatureTracker/redhat-ods-applications-mesh-metrics-collection -A
```

## Define a ServiceMeshMember for Serverless

Define a ServiceMeshMember object in a YAML file called serverless-smm.yaml

```yaml
apiVersion: maistra.io/v1
kind: ServiceMeshMember
metadata:
  name: default
  namespace: knative-serving
spec:
  controlPlaneRef:
    namespace: istio-system
    name: minimal
```

Apply the ServiceMeshMember object in the istio-system namespace

```sh
oc project -n istio-system && oc apply -f configs/serverless-smm.yaml
```

```sh
# expected output
Using project "default" on server "https://api.cluster-9ngld.9ngld.sandbox2808.opentlc.com:6443".
servicemeshmember.maistra.io/default created
```

Define a KnativeServing object in a YAML file called serverless-istio.yaml

>adds the following actions to each of the activator and autoscaler pods:

1. Injects an Istio sidecar to the pod. This makes the pod part of the service mesh.
1. Enables the Istio sidecar to rewrite the HTTP liveness and readiness probes for the pod.

>Service Mesh sidecars are essential for managing communication and offer capabilities like finding services, balancing loads, controlling traffic, and ensuring security.

```yaml
apiVersion: operator.knative.dev/v1beta1
kind: KnativeServing
metadata:
  name: knative-serving
  namespace: knative-serving
  annotations:
    serverless.openshift.io/default-enable-http2: "true"
spec:
  workloads:
    - name: net-istio-controller
      env:
        - container: controller
          envVars:
            - name: ENABLE_SECRET_INFORMER_FILTERING_BY_CERT_UID
              value: 'true'
    - annotations:
        sidecar.istio.io/inject: "true" 
        sidecar.istio.io/rewriteAppHTTPProbers: "true" 
      name: activator
    - annotations:
        sidecar.istio.io/inject: "true"
        sidecar.istio.io/rewriteAppHTTPProbers: "true"
      name: autoscaler
  ingress:
    istio:
      enabled: true
  config:
    features:
      kubernetes.podspec-affinity: enabled
      kubernetes.podspec-nodeselector: enabled
      kubernetes.podspec-tolerations: enabled
```

Apply the KnativeServing object in the specified knative-serving namespace

```sh
oc create -f configs/serverless-istio.yaml
```

```sh
# expected output
knativeserving.operator.knative.dev/knative-serving created
```

#### Creating secure gateways for Knative Serving (4min)

[Section 3.3.1.3 source](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/2.10/html/serving_models/serving-large-models_serving-large-models#creating-secure-gateways-for-knative-serving_serving-large-models)

Why? To secure traffic between your Knative Serving instance and the service mesh, you must create secure gateways for your Knative Serving instance.

The initial steps to generate a root signed certificate were completed previous

Verify the wildcard certificate
```sh
openssl verify -CAfile ${BASE_DIR}/root.crt ${BASE_DIR}/wildcard.crt
```

```sh
# expected output
/tmp/kserve/wildcard.crt: OK
```

Export the wildcard key and certificate that were created by the script to new environment variables

```sh
export TARGET_CUSTOM_CERT=${BASE_DIR}/wildcard.crt
export TARGET_CUSTOM_KEY=${BASE_DIR}/wildcard.key
```

Create a TLS secret in the istio-system namespace using the environment variables that you set for the wildcard certificate and key
```sh
oc create secret tls wildcard-certs --cert=${TARGET_CUSTOM_CERT} --key=${TARGET_CUSTOM_KEY} -n istio-system
```

```sh
# expected output
secret/wildcard-certs created
```

>Defines a service in the istio-system namespace for the Knative local gateway.
Defines an ingress gateway in the knative-serving namespace. The gateway uses the TLS secret you created earlier in this procedure. The ingress gateway handles external traffic to Knative.
Defines a local gateway for Knative in the knative-serving namespace.

Create a serverless-gateway.yaml YAML file with the following contents

```yaml
apiVersion: v1
kind: Service 
metadata:
  labels:
    experimental.istio.io/disable-gateway-port-translation: "true"
  name: knative-local-gateway
  namespace: istio-system
spec:
  ports:
    - name: http2
      port: 80
      protocol: TCP
      targetPort: 8081
  selector:
    knative: ingressgateway
  type: ClusterIP
---
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: knative-ingress-gateway 
  namespace: knative-serving
spec:
  selector:
    knative: ingressgateway
  servers:
    - hosts:
        - '*'
      port:
        name: https
        number: 443
        protocol: HTTPS
      tls:
        credentialName: wildcard-certs
        mode: SIMPLE
---
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
 name: knative-local-gateway 
 namespace: knative-serving
spec:
 selector:
   knative: ingressgateway
 servers:
   - port:
       number: 8081
       name: https
       protocol: HTTPS
     tls:
       mode: ISTIO_MUTUAL
     hosts:
       - "*"
```

Apply the serverless-gateways.yaml file to create the defined resources
```sh
oc apply -f configs/serverless-gateway.yaml
```

```sh
# expected output
service/knative-local-gateway unchanged
gateway.networking.istio.io/knative-ingress-gateway created
gateway.networking.istio.io/knative-local-gateway created
```

Review the gateways that you created
```sh
oc get gateway --all-namespaces
```

Expected Output:

```sh
NAMESPACE         NAME                      AGE
knative-serving   knative-ingress-gateway   2m
knative-serving   knative-local-gateway     2m
```

#### Configuring Authorino for Unmanaged deployments

Create a namespace to install the Authorino instance
```sh
oc create ns redhat-ods-applications-auth-provider
```

```sh
# expected output
namespace/redhat-ods-applications-auth-provider created
```

Enroll the new namespace for the Authorino instance in your existing OpenShift Service Mesh instance, create a new YAML file authorino-smm.yaml with the following contents

```yaml
  apiVersion: maistra.io/v1
  kind: ServiceMeshMember
  metadata:
    name: default
    namespace: redhat-ods-applications-auth-provider
  spec:
    controlPlaneRef:
      namespace: istio-system
      name: minimal
```

Create the ServiceMeshMember resource on your cluster
```sh
oc create -f configs/authorino-smm.yaml
```

```sh
# expected output
servicemeshmember.maistra.io/default created
```

Configure an Authorino instance, create a new YAML file as shown

```yaml
  apiVersion: operator.authorino.kuadrant.io/v1beta1
  kind: Authorino
  metadata:
    name: authorino
    namespace: redhat-ods-applications-auth-provider
  spec:
    authConfigLabelSelectors: security.opendatahub.io/authorization-group=default
    clusterWide: true
    listener:
      tls:
        enabled: false
    oidcServer:
      tls:
        enabled: false
```

Create the Authorino resource on your cluster.
```sh
oc create -f configs/authorino-instance.yaml
```

```sh
# expected output
authorino.operator.authorino.kuadrant.io/authorino created
```

Patch the Authorino deployment to inject an Istio sidecar, which makes the Authorino instance part of your OpenShift Service Mesh instance
```sh
oc patch deployment authorino -n redhat-ods-applications-auth-provider -p '{"spec": {"template":{"metadata":{"labels":{"sidecar.istio.io/inject":"true"}}}} }'
```

```sh
# expected output
deployment.apps/authorino patched
```

Check the pods (and containers) that are running in the namespace that you created for the Authorino instance, as shown in the following example
```sh
oc get pods -n redhat-ods-applications-auth-provider -o="custom-columns=NAME:.metadata.name,STATUS:.status.phase,CONTAINERS:.spec.containers[*].name"
```

```sh
# expected output
NAME                         STATUS    CONTAINERS
authorino-75585d99bd-vh65n   Running   authorino,istio-proxy
```

#### Configuring an OpenShift Service Mesh instance to use Authorino (~6min)

[Section 3.3.3.3 source](https://access.redhat.com/documentation/en-us/red_hat_openshift_ai_self-managed/2.10/html/serving_models/serving-large-models_serving-large-models#configuring-service-mesh-instance-to-use-authorino_serving-large-models)

Why? you must configure your OpenShift Service Mesh instance to use Authorino as an authorization provider

Create a new YAML file with the following contents `servicemesh-smcp-patch.yaml`

```yaml
spec:
 techPreview:
   meshConfig:
     extensionProviders:
     - name: redhat-ods-applications-auth-provider
       envoyExtAuthzGrpc:
         service: authorino-authorino-authorization.redhat-ods-applicatiions-auth-provider.svc.cluster.local
         port: 50051
```

Use the oc patch command to apply the YAML file to your OpenShift Service Mesh instance

```sh
oc patch smcp minimal --type merge -n istio-system --patch-file configs/files/servicemesh-smcp-patch.yaml
```

```sh
# expected output
servicemeshcontrolplane.maistra.io/minimal patched
```

Inspect the ConfigMap object for your OpenShift Service Mesh instance
```sh
oc get configmap istio-minimal -n istio-system --output=jsonpath={.data.mesh}
```

```sh
# expected output
defaultConfig:
  discoveryAddress: istiod-minimal.istio-system.svc:15012
  proxyMetadata:
    ISTIO_META_DNS_AUTO_ALLOCATE: "true"
    ISTIO_META_DNS_CAPTURE: "true"
    PROXY_XDS_VIA_AGENT: "true"
  terminationDrainDuration: 35s
  tracing: {}
dnsRefreshRate: 300s
enablePrometheusMerge: true
extensionProviders:
- envoyExtAuthzGrpc:
    port: 50051
    service: authorino-authorino-authorization.redhat-ods-applicatiions-auth-provider.svc.cluster.local
  name: redhat-ods-applications-auth-provider
ingressControllerMode: "OFF"
rootNamespace: istio-system
trustDomain: null
```

Confirm that you see output that the Authorino instance has been successfully added as an extension provider

#### Configuring authorization for KServe (~3min)

[Section 3.3.3.4 source](https://access.redhat.com/documentation/en-us/red_hat_openshift_ai_self-managed/2.10/html/serving_models/serving-large-models_serving-large-models#configuring-authorization-for-kserve_serving-large-models)

Why? you must create a global AuthorizationPolicy resource that is applied to the KServe predictor pods that are created when you deploy a model. In addition, to account for the multiple network hops that occur when you make an inference request to a model, you must create an EnvoyFilter resource that continually resets the HTTP host header to the one initially included in the inference request.

Create a new YAML file with the following contents:

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: kserve-predictor
spec:
  action: CUSTOM
  provider:
     name: redhat-ods-applications-auth-provider 
  rules:
     - to:
          - operation:
               notPaths:
                  - /healthz
                  - /debug/pprof/
                  - /metrics
                  - /wait-for-drain
  selector:
     matchLabels:
        component: predictor
```

Create the AuthorizationPolicy resource in the namespace for your OpenShift Service Mesh instance
```sh
oc create -n istio-system -f configs/servicemesh-authorization-policy.yaml
```

```sh
# expected output
authorizationpolicy.security.istio.io/kserve-predictor created
```

Create another new YAML file with the following contents:
The EnvoyFilter resource shown continually resets the HTTP host header to the one initially included in any inference request.

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: activator-host-header
spec:
  priority: 20
  workloadSelector:
    labels:
      component: predictor
  configPatches:
  - applyTo: HTTP_FILTER
    match:
      listener:
        filterChain:
          filter:
            name: envoy.filters.network.http_connection_manager
    patch:
      operation: INSERT_BEFORE
      value:
        name: envoy.filters.http.lua
        typed_config:
          '@type': type.googleapis.com/envoy.extensions.filters.http.lua.v3.Lua
          inlineCode: |
           function envoy_on_request(request_handle)
              local headers = request_handle:headers()
              if not headers then
                return
              end
              local original_host = headers:get("k-original-host")
              if original_host then
                port_seperator = string.find(original_host, ":", 7)
                if port_seperator then
                  original_host = string.sub(original_host, 0, port_seperator-1)
                end
                headers:replace('host', original_host)
              end
            end
```

Create the EnvoyFilter resource in the namespace for your OpenShift Service Mesh instance
```sh
oc create -n istio-system -f configs/servicemesh-envoyfilter.yaml
```

```sh
# expected output
envoyfilter.networking.istio.io/activator-host-header created
```

Check that the AuthorizationPolicy resource was successfully created.
```sh
oc get authorizationpolicies -n istio-system
```

```sh
# expected output
NAME               AGE
kserve-predictor   62s
```

Check that the EnvoyFilter resource was successfully created.
```sh
oc get envoyfilter -n istio-system
```

Example Output:

```sh
NAME                                AGE
activator-host-header               101s
metadata-exchange-1.6-minimal       56m
tcp-metadata-exchange-1.6-minimal   56m
```

## Installing and managing Red Hat OpenShift AI components (~1min)


[3.4.1. Installing Red Hat OpenShift AI components by using the CLI](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/2.10/html/installing_and_uninstalling_openshift_ai_self-managed/installing-and-deploying-openshift-ai_install#installing-openshift-ai-components-using-cli_component-install)

In the spec.components section of the CR, for each OpenShift AI component shown, set the value of the managementState field to either Managed or Removed:
- `Managed` - The Operator actively manages the component, installs it, and tries to keep it active. The Operator will upgrade the component only if it is safe to do so.
- `Removed` - The Operator actively manages the component but does not install it. If the component is already installed, the Operator will try to remove it.

Create a DataScienceCluster object custom resource (CR) file, for example, rhoai-operator-dsc.yaml

```yaml
apiVersion: datasciencecluster.opendatahub.io/v1
kind: DataScienceCluster
metadata:
  name: default-dsc
spec:
  components:
    dashboard:
      managementState: Managed
    workbenches:
      managementState: Managed
    datasciencepipelines:
      managementState: Managed
    kueue:
      managementState: Managed
    codeflare:
      managementState: Managed
    ray:
      managementState: Managed
    modelmeshserving:
      managementState: Managed
    kserve:
      managementState: Removed
      serving:
        ingressGateway:
          certificate:
            secretName: knative-serving-cert
            type: SelfSigned
        managementState: Unmanaged
        name: knative-serving       
```

>When you manually installed KServe, you set the value of the managementState to `Unmanaged` within the kserve component.

Apply the DSC object

```sh
oc create -f configs/rhoai-operator-dcs.yaml
```

```sh
# expected output
datasciencecluster.datasciencecluster.opendatahub.io/default-dsc created
```

When you manually installed KServe, you set the value of the managementState field for the serviceMesh component to `Unmanaged` to prevent RHOAI from managing it. Modify the DSCI object so that ServiceMesh is not managed by the RHOAI operator

```yaml
apiVersion: dscinitialization.opendatahub.io/v1
kind: DSCInitialization

metadata:
  name: default-dsci
spec:
  applicationsNamespace: redhat-ods-applications
  monitoring:
    managementState: Managed
    namespace: redhat-ods-monitoring
  serviceMesh:
    auth:
      audiences:
        - 'https://kubernetes.default.svc'
    controlPlane:
      metricsCollection: Istio
      name: minimal
      namespace: istio-system
    managementState: Unmanaged
  trustedCABundle:
    customCABundle: ''
    managementState: Managed
```

Apply the default-dsci object

```sh
oc apply -f configs/rhoai-operator-dsci.yaml
```

```sh
# expected output
...
dscinitialization.dscinitialization.opendatahub.io/default-dsci configured
```