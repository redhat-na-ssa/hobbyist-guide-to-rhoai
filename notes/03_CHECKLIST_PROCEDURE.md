# Installing the Red Hat OpenShift AI Operator

## Accessing the cluster via your client CLI

These are the detailed steps that accompany the `CHECKLIST.md` all in one doc.

Login to cluster via terminal

```sh
oc login <openshift_cluster_url> -u <admin_username> -p <password>
```

(optional) Configure bash completion - requires `oc` and `bash-completion` packages installed

```sh
source <(oc completion bash)
```

Git clone this repository

```sh
git clone https://github.com/redhat-na-ssa/hobbyist-guide-to-rhoai.git
```

>Red Hat recommends that you install only one instance of OpenShift AI (or Open Data Hub) on your cluster.

## Fix kubeadmin as an Administrator for Openshift AI (~2 min)

>`kubeadmin` user is an automatically generated temporary user. Best practice is to create a new user using an identity provider and elevate the privileges of that user to `cluster-admin`. Once such user is created, the default `kubeadmin` user should be removed. [source](https://access.redhat.com/solutions/5309141)

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

## Adding administrative users for OpenShift Container Platform (~8 min)

>For this process we are using HTpasswd typical for PoC. You can configure the following types of identity providers [htpasswd, keystone, LDAP, basic-authentication, request-header, GitHub, GitLab, Google, OpenID Connect](https://docs.redhat.com/en/documentation/openshift_container_platform/4.16/html/authentication_and_authorization/understanding-identity-provider#supported-identity-providers). [RHOAI source](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/2.12/html/installing_and_uninstalling_openshift_ai_self-managed/installing-and-deploying-openshift-ai_install#adding-administrative-users-for-openshift-container-platform_install)

Create an htpasswd file to store the user and password information

```sh
mkdir scratch
htpasswd -c -B -b scratch/users.htpasswd <username> <password>
```

```sh
# expected output
...
Adding password for user <username>
```

Create a secret to represent the htpasswd file

```sh
oc create secret generic htpasswd-secret --from-file=htpasswd=scratch/users.htpasswd -n openshift-config
```

```sh
# expected output
secret/htpasswd-secret created
```

Define the custom resource for htpasswd

```yaml
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  identityProviders:
    # This provider name is prefixed to provider user names to form an identity name.
  - name: htpasswd
    # Controls how mappings are established between this provider’s identities and User objects.
    mappingMethod: claim
    type: HTPasswd
    htpasswd:
      fileData:
        # An existing secret containing a file generated using htpasswd.
        name: htpasswd-secret
```

Apply the resource to the default OAuth configuration to add the identity provider

```sh
oc apply -f configs/htpasswd-cr.yaml
```

```sh
# expected output
...
oauth.config.openshift.io/cluster configured
```

> You will have to a few minutes for the account to resolve.

As kubeadmin, assign the cluster-admin role to perform administrator level tasks.

```sh
oc adm policy add-cluster-role-to-user cluster-admin <user>
```

```sh
# expected output
clusterrole.rbac.authorization.k8s.io/cluster-admin added: "<username>"
```

Log in to the cluster as a user from your identity provider, entering the password when prompted

NOTE: You may need to add the parameter `--insecure-skip-tls-verify=true` if your clusters api endpoint does not have a trusted cert.

```sh
oc login --insecure-skip-tls-verify=true -u <username> -p <password>
```

## (Optional) Install the Web Terminal Operator (~5min)

This provides a `Web Terminal` in the same browser as the `OCP Web Console` to minimize context switching between the browser and local client. [docs](https://docs.redhat.com/en/documentation/openshift_container_platform/4.15/html/web_console/web-terminal).

![NOTE] kubeadmin is unable to create web terminals [source](https://github.com/redhat-developer/web-terminal-operator/issues/162)

Create a subscription object for the Web Terminal.

```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: web-terminal
  namespace: openshift-operators
spec:
  channel: fast
  installPlanApproval: Automatic
  name: web-terminal
  source: redhat-operators
  sourceNamespace: openshift-marketplace
```

Apply the web terminal subscription

```sh
oc apply -f configs/web-terminal-subscription.yaml
```

```sh
# expected output
subscription.operators.coreos.com/web-terminal configured
```

![NOTE]The Web Terminal Operator installs the DevWorkspace Operator as a dependency.

From the OCP Web Console, Refresh the browser and click the `>_` icon in the top right of the window. This can serve as your browser based CLI.

## Installing the Red Hat OpenShift AI Operator by using the CLI (~3min)

[Section 2.3 source](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/2.10/html/installing_and_uninstalling_openshift_ai_self-managed/installing-and-deploying-openshift-ai_install#installing-the-openshift-data-science-operator_operator-install)

Create a namespace YAML file, for example, rhoai-operator-ns.yaml

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: redhat-ods-operator
```

Create the namespace in your OpenShift Container Platform cluster

```sh
oc create -f configs/rhoai-operator-ns.yaml
```

```sh
# expected output
namespace/redhat-ods-operator created
```

Create an OperatorGroup object custom resource (CR) file, for example, rhoai-operator-group.yaml

```yaml
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: rhods-operator
  namespace: redhat-ods-operator 
```

Create the OperatorGroup in your OpenShift Container Platform cluster

```sh
oc create -f configs/rhoai-operator-group.yaml
```

```sh
# expected output
operatorgroup.operators.coreos.com/rhods-operator created
```

Create a Subscription object CR file, for example, rhoai-operator-subscription.yaml

>Understanding `update channels`. We are using `fast` channel as this gives customers access to the latest product features. [source](https://access.redhat.com/support/policy/updates/rhoai-sm/lifecycle).

```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhods-operator
  namespace: redhat-ods-operator 
spec:
  name: rhods-operator
  channel: fast 
  source: redhat-operators
  sourceNamespace: openshift-marketplace
```

Create the Subscription object in your OpenShift Container Platform cluster

```sh
oc create -f configs/rhoai-operator-subscription.yaml
```

```sh
# expected output
subscription.operators.coreos.com/rhods-operator created
```

Verification

Check the installed operators for `rhods-operator.redhat-ods-operator`

```sh
oc get operators
```

```sh
# expected output
NAME                                        AGE
devworkspace-operator.openshift-operators   21m
rhods-operator.redhat-ods-operator          7s
web-terminal.openshift-operators            22m
```

Check the created projects `redhat-ods-applications|redhat-ods-monitoring|redhat-ods-operator`

```sh
oc get projects | egrep redhat-ods
```

```sh
# expected output
redhat-ods-applications                                           Active
redhat-ods-monitoring                                             Active
redhat-ods-operator                                               Active
```

>IMPORTANT
The RHOAI Operator has instances deployed as a result of installing the operator.

```sh
oc get DSCInitialization,FeatureTracker -n redhat-ods-operator
```

```sh
# expected output
NAME                                                              AGE   PHASE         CREATED AT
dscinitialization.dscinitialization.opendatahub.io/default-dsci   22m   Progressing   2024-07-25T20:26:03Z

NAME                                                                                         AGE
featuretracker.features.opendatahub.io/redhat-ods-applications-mesh-control-plane-creation   22m
featuretracker.features.opendatahub.io/redhat-ods-applications-mesh-metrics-collection       22m
featuretracker.features.opendatahub.io/redhat-ods-applications-mesh-shared-configmap         22m
```

The RHOAI Operator is installed with a 'default-dcsi' object with the following. Notice how the `serviceMesh` is `Managed`. By default, RHOAI is managing `ServiceMesh`.

```yaml
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
        - 'https://kubernetes.default.svc'
    controlPlane:
      metricsCollection: Istio
      name: data-science-smcp
      namespace: istio-system
    managementState: Managed
  trustedCABundle:
    customCABundle: ''
    managementState: Managed
```

## Installing and managing Red Hat OpenShift AI components (~1min)

Before you install KServe, you must install and configure some dependencies. Specifically, you must create Red Hat OpenShift Service Mesh and Knative Serving instances and then configure secure gateways for Knative Serving.

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

## Adding a CA bundle (~5min)

[Section 3.2 source](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/2.10/html/installing_and_uninstalling_openshift_ai_self-managed/working-with-certificates_certs#adding-a-ca-bundle_certs)

Set environment variables to define base directories for generation of a wildcard certificate and key for the gateways.

```sh
export BASE_DIR=/tmp/kserve
export BASE_CERT_DIR=${BASE_DIR}/certs
```

Set an environment variable to define the common name used by the ingress controller of your OpenShift cluster

```sh
export COMMON_NAME=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' | awk -F'.' '{print $(NF-1)"."$NF}')
```

Set an environment variable to define the domain name used by the ingress controller of your OpenShift cluster.

```sh
export DOMAIN_NAME=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')
```

Create the required base directories for the certificate generation, based on the environment variables that you previously set.

```sh
mkdir ${BASE_DIR}
mkdir ${BASE_CERT_DIR}
```

Create the OpenSSL configuration for generation of a wildcard certificate.

```sh
cat <<EOF> ${BASE_DIR}/openssl-san.config
[ req ]
distinguished_name = req
[ san ]
subjectAltName = DNS:*.${DOMAIN_NAME}
EOF
```

Generate a root certificate.

```sh
openssl req -x509 -sha256 -nodes -days 3650 -newkey rsa:2048 \
-subj "/O=Example Inc./CN=${COMMON_NAME}" \
-keyout $BASE_DIR/root.key \
-out $BASE_DIR/root.crt
```

Generate a wildcard certificate signed by the root certificate.

```sh
openssl req -x509 -newkey rsa:2048 \
-sha256 -days 3560 -nodes \
-subj "/CN=${COMMON_NAME}/O=Example Inc." \
-extensions san -config ${BASE_DIR}/openssl-san.config \
-CA $BASE_DIR/root.crt \
-CAkey $BASE_DIR/root.key \
-keyout $BASE_DIR/wildcard.key  \
-out $BASE_DIR/wildcard.crt

openssl x509 -in ${BASE_DIR}/wildcard.crt -text
```

Verify the wildcard certificate.

```sh
openssl verify -CAfile ${BASE_DIR}/root.crt ${BASE_DIR}/wildcard.crt
```

```sh
# expected output
/tmp/kserve/wildcard.crt: OK
```

Copy the `root.crt` to paste into `default-dcsi`.

```sh
cat ${BASE_DIR}/root.crt
```

```sh
# expected output-ish
-----BEGIN CERTIFICATE-----
certificateCERTIFICATECERTIFICATESDFCERTIFICATEcertificateCERTIFICATE
certificateCERTIFICATECERTIFICATESDFCERTIFICATEcertificateCERTIFICATE
certificateCERTIFICATECERTIFICATESDFCERTIFICATEcertificateCERTIFICATE
certificateCERTIFICATECERTIFICATESDFCERTIFICATEcertificateCERTIFICATE
certificateCERTIFICATECERTIFICATESDFCERTIFICATEcertificateCERTIFICATE
certificateCERTIFICATECERTIFICATESDFCERTIFICATEcertificateCERTIFICATE
certificateCERTIFICATECERTIFICATESDFCERTIFICATEcertificateCERTIFICATE
certificateCERTIFICATECERTIFICATESDFCERTIFICATEcertificateCERTIFICATE
certificateCERTIFICATECERTIFICATESDFCERTIFICATEcertificateCERTIFICATE
certificateCERTIFICATECERTIFICATESDFCERTIFICATEcertificateCERTIFICATE
certificateCERTIFICATECERTIFICATESDFCERTIFICATEcertificateCERTIFICATE
certificateCERTIFICATECERTIFICATESDFCERTIFICATEcertificateCERTIFICATE
-----END CERTIFICATE-----
```

Open your dscinitialization object `default-dsci` via the CLI or terminal
`oc edit dscinitialization -n redhat-ods-applications`

In the spec section, add the custom root signed certificate to the customCABundle field for trustedCABundle, as shown in the following example:

```yaml
spec:
  trustedCABundle:
    customCABundle: |
      -----BEGIN CERTIFICATE-----
      -----END CERTIFICATE-----
    managementState: Managed
```

>in vi, you can use `:set nu` to show line numbers
you can use `:34,53s/^/       /` to indent the pasted cert

```sh
# expected output
dscinitialization.dscinitialization.opendatahub.io/default-dsci edited
```

More info on managementState [source](https://access.redhat.com/documentation/en-us/red_hat_openshift_ai_self-managed/2.10/html/installing_and_uninstalling_openshift_ai_self-managed/working-with-certificates_certs#managing-certificates_certs)

Verify the `odh-trusted-ca-bundle` configmap for your root signed cert in the `odh-ca-bundle.crt:` section

```sh
oc get cm/odh-trusted-ca-bundle -o yaml -n redhat-ods-applications
```

Run the following command to verify that all non-reserved namespaces contain the odh-trusted-ca-bundle ConfigMap
```sh
oc get configmaps --all-namespaces -l app.kubernetes.io/part-of=opendatahub-operator | grep odh-trusted-ca-bundle
```

```sh
# expected output
istio-system              odh-trusted-ca-bundle   2      10m
redhat-ods-applications   odh-trusted-ca-bundle   2      10m
redhat-ods-monitoring     odh-trusted-ca-bundle   2      10m
redhat-ods-operator       odh-trusted-ca-bundle   2      10m
rhods-notebooks           odh-trusted-ca-bundle   2      6m55s
```

## (Optional) Configuring the OpenShift AI Operator logger

[Section 3.5.1 source](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/2.10/html/installing_and_uninstalling_openshift_ai_self-managed/installing-and-deploying-openshift-ai_install#configuring-the-operator-logger_operator-log) You can change the log level for OpenShift AI Operator (`development`, `""`, `production`) components by setting the .spec.devFlags.logmode flag for the DSC Initialization/DSCI custom resource during runtime. If you do not set a logmode value, the logger uses the INFO log level by default.

Configure the log level from the OpenShift CLI by using the following command with the logmode value set to the log level that you want
```sh
oc patch dsci default-dsci -p '{"spec":{"devFlags":{"logmode":"development"}}}' --type=merge
```

```sh
# expected output
dscinitialization.dscinitialization.opendatahub.io/default-dsci patched
```

Viewing the OpenShift AI Operator log
```sh
oc get pods -l name=rhods-operator -o name -n redhat-ods-operator |  xargs -I {} oc logs -f {} -n redhat-ods-operator
```

You can also view via the console
**Workloads > Deployments > Pods > redhat-ods-operator > Logs**

## Installing KServe dependencies (~3min)

### Install Service Mesh
A service mesh is an infrastructure layer that simplifies the communication between services in a (loosely coupled) microservices architecture. Red Hat OpenShift Service Mesh, which is based on the open source Istio project, addresses a variety of problems in a microservice architecture by creating a centralized point of control in an application. It adds a transparent layer on existing distributed applications without requiring any changes to the application code. It includes a collection of lightweight network proxies, known as sidecars, which are placed next to each service in the system. [source](https://docs.redhat.com/en/documentation/openshift_container_platform/4.15/html/service_mesh/service-mesh-2-x#ossm-about)

It is made up of two main components: the control plane and the data plane.

[Section 3.3.1 source](https://access.redhat.com/documentation/en-us/red_hat_openshift_ai_self-managed/2.10/html/serving_models/serving-large-models_serving-large-models#manually-installing-kserve_serving-large-models)

Create the required namespace for Red Hat OpenShift Service Mesh.

```sh
oc create ns istio-system
```

```sh
# expected output
namespaces "istio-system" already exists
```

Define the required subscription for the Red Hat OpenShift Service Mesh Operator

```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: servicemeshoperator
  namespace: openshift-operators
spec:
  channel: stable 
  installPlanApproval: Automatic
  name: servicemeshoperator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  ```

Apply the Service Mesh subscription to install the operator

```sh
oc create -f configs/servicemesh-subscription.yaml
```

```sh
# expected output
subscription.operators.coreos.com/servicemeshoperator created
```

Define a ServiceMeshControlPlane object. The control plane acts as the central management and configuration layer of the service mesh. With the control plane, administrators can define and configure the services within the mesh.

>Support for the Red Hat OpenShift distributed tracing platform (Jaeger) Operator is deprecated. To collect trace spans, use the Red Hat OpenShift distributed tracing platform (Tempo) Stack, This component is based on the open source Grafana Tempo project. Support for the OpenShift Elasticsearch Operator is deprecated.

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

### Creating a Knative Serving instance

[Section 3.3.1.2 source](https://access.redhat.com/documentation/en-us/red_hat_openshift_ai_self-managed/2.10/html/serving_models/serving-large-models_serving-large-models#creating-a-knative-serving-instance_serving-large-models)

Define the Serverless operator ns, operatorgroup, and subscription

```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  annotations:
    openshift.io/display-name: "Red Hat OpenShift Serverless"
  labels:
    openshift.io/cluster-monitoring: 'true'
  name: openshift-serverless
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: serverless-operator
  namespace: openshift-serverless
spec: {}
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: serverless-operator
  namespace: openshift-serverless
spec:
  channel: stable 
  name: serverless-operator 
  source: redhat-operators 
  sourceNamespace: openshift-marketplace 
```

Install the Serverless Operator objects

```sh
oc create -f configs/serverless-operator.yaml
```

```sh
# expected output
namespace/openshift-serverless created
operatorgroup.operators.coreos.com/serverless-operator created
subscription.operators.coreos.com/serverless-operator created
```

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

(Optional) use a TLS certificate to secure the mapped service from [source](https://access.redhat.com/documentation/en-us/red_hat_openshift_ai_self-managed/2.10/html/serving_models/serving-large-models_serving-large-models#creating-a-knative-serving-instance_serving-large-models)

Review the default ServiceMeshMemberRoll object in the istio-system namespace and confirm that it includes the knative-serving namespace.
```sh
oc describe smmr default -n istio-system
```

```yaml
# expected output
...  
Member Statuses:
    Conditions:
      Last Transition Time:  2024-07-25T22:15:59Z
      Status:                True
      Type:                  Reconciled
    Namespace:               knative-serving
  Members:
    knative-serving
...
```

```sh
oc get smmr default -n istio-system -o jsonpath='{.status.memberStatuses}'
```

```sh
# expected output TODO
[{"conditions":[{"lastTransitionTime":"2024-07-16T18:09:10Z","status":"Unknown","type":"Reconciled"}],"namespace":"knative-serving"}]
```

Verify creation of the Knative Serving instance
```sh
oc get pods -n knative-serving
```

```sh
# expected output
activator-5cf876c6cf-jtvs2                                    0/1     Running     0             91s
activator-5cf876c6cf-ntf79                                    0/1     Running     0             76s
autoscaler-84655b4df5-w9lmc                                   1/1     Running     0             91s
autoscaler-84655b4df5-zznlw                                   1/1     Running     0             91s
autoscaler-hpa-986bb8687-llms8                                1/1     Running     0             90s
autoscaler-hpa-986bb8687-qtgln                                1/1     Running     0             90s
controller-84cb7b64bc-9654q                                   1/1     Running     0             89s
controller-84cb7b64bc-bdhps                                   1/1     Running     0             83s
net-istio-controller-6498db6ccb-4ddvd                         0/1     Running     2 (24s ago)   89s
net-istio-controller-6498db6ccb-f66mv                         0/1     Running     2 (24s ago)   89s
net-istio-webhook-79cbc7c4d4-r6gln                            1/1     Running     0             89s
net-istio-webhook-79cbc7c4d4-snd7k                            1/1     Running     0             89s
storage-version-migration-serving-serving-1.12-1.33.0-6v9ll   0/1     Completed   0             89s
webhook-6bb9cd8c97-46lz4                                      1/1     Running     0             90s
webhook-6bb9cd8c97-cxm2n                                      1/1     Running     0             75s
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

### Manually adding an authorization provider (~4min)

[Section 3.3.3 source](https://access.redhat.com/documentation/en-us/red_hat_openshift_ai_self-managed/2.10/html/serving_models/serving-large-models_serving-large-models#manually-adding-an-authorization-provider_serving-large-models)

Why? Adding an authorization provider allows you to enable token authorization for models that you deploy on the platform, which ensures that only authorized parties can make inference requests to the models.

Create subscription for the Authorino Operator

```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: authorino-operator
  namespace: openshift-operators
spec:
  channel: managed-services
  installPlanApproval: Automatic
  name: authorino-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  # startingCSV: authorino-operator.v1.0.1
```

Apply the Authorino operator
```sh
oc create -f configs/authorino-subscription.yaml
```

```sh
# expected output
subscription.operators.coreos.com/authorino-operator created
```

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

## Enabling GPU support in OpenShift AI

[Section 5 source](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/2.10/html/installing_and_uninstalling_openshift_ai_self-managed/enabling-gpu-support_install)

### Adding a GPU node to an existing OpenShift Container Platform cluster (12min)

[source](https://docs.redhat.com/en/documentation/openshift_container_platform/4.15/html/machine_management/managing-compute-machines-with-the-machine-api#nvidia-gpu-aws-adding-a-gpu-node_creating-machineset-aws)

View the existing nodes
```sh
oc get nodes
```

```sh
# expected output
NAME                                        STATUS   ROLES                         AGE     VERSION
ip-10-x-xx-xxx.us-east-x.compute.internal   Ready    control-plane,master,worker   5h11m   v1.28.10+a2c84a5
```

View the machines and machine sets that exist in the openshift-machine-api namespace
```sh
oc get machinesets -n openshift-machine-api
```

```sh
# expected output
NAME                                    DESIRED   CURRENT   READY   AVAILABLE   AGE
cluster-xxxxx-xxxxx-worker-us-east-xc   0         0                             5h13m
```

View the machines that exist in the openshift-machine-api namespace
```sh
oc get machines -n openshift-machine-api | egrep worker
```

Make a copy of one of the existing compute MachineSet definitions and output the result to a YAML file

```sh
# get your machineset names
oc get machineset -n openshift-machine-api

# make a copy of an existing machineset definition
oc get machineset <your-machineset-name> -n openshift-machine-api -o yaml > scratch/machineset.yaml
```

Update the following fields:

- [ ] `.spec.replicas` from `0` to `2`
- [ ] `.metadata.name` to a name containing `gpu`.
- [ ] `.spec.selector.matchLabels["machine.openshift.io/cluster-api-machineset"]` to match the new `.metadata.name`.
- [ ] `.spec.template.metadata.labels["machine.openshift.io/cluster-api-machineset"]` to match the new `.metadata.name`.
- [ ] `.spec.template.spec.providerSpec.value.instanceType` to `g4dn.4xlarge`.

Remove the following fields:

- [ ] `uid`
- [ ] `generation`

Apply the configuration to create the gpu machine

```sh
oc apply -f scratch/machineset.yaml
```

```sh
# expected output
machineset.machine.openshift.io/cluster-xxxx-xxxx-worker-us-east-gpu created
```

Verify the gpu machineset you created is running

```sh
oc -n openshift-machine-api get machinesets | grep gpu
```

```sh
# expected output
cluster-xxxxx-xxxxx-worker-us-east-xc-gpu   2         2         2       2           6m37s
```

View the Machine object that the machine set created

```sh
oc -n openshift-machine-api get machines | grep gpu
```

```sh
# expected output
cluster-xxxxx-xxxxx-worker-us-east-xc-gpu-29whc   Running   g4dn.4xlarge   us-east-2   us-east-2c   7m59s
cluster-xxxxx-xxxxx-worker-us-east-xc-gpu-nr59d   Running   g4dn.4xlarge   us-east-2   us-east-2c   7m59s
```

### Deploying the Node Feature Discovery Operator (12-30min)

[source](https://docs.redhat.com/en/documentation/openshift_container_platform/4.15/html/machine_management/managing-compute-machines-with-the-machine-api#nvidia-gpu-aws-deploying-the-node-feature-discovery-operator_creating-machineset-aws)

List the available operators for installation searching for Node Feature Discovery (NFD)

```sh
oc get packagemanifests -n openshift-marketplace | grep nfd
```

```sh
# expected output
openshift-nfd-operator                             Community Operators   8h
nfd                                                Red Hat Operators     8h
```

Create a Namespace object YAML file

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-nfd
```

Apply the Namespace object

```sh
oc apply -f configs/nfd-operator-ns.yaml
```

```sh
# expected output
namespace/openshift-nfd created
```

Create an OperatorGroup object YAML file

```yaml
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: nfd
  namespace: openshift-nfd
```

Apply the OperatorGroup object

```sh
oc apply -f configs/nfd-operator-group.yaml
```

```sh
# expected output
operatorgroup.operators.coreos.com/nfd created
```

Create a Subscription object YAML file to subscribe a namespace to an Operator

```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: nfd
  namespace: openshift-nfd
spec:
  channel: stable
  name: nfd
  source: redhat-operators 
  sourceNamespace: openshift-marketplace 
  installPlanApproval: Automatic
```

Apply the Subscription object

```sh
oc apply -f configs/nfd-operator-sub.yaml
```

```sh
# expected output
subscription.operators.coreos.com/nfd created
```

Verify the operator is installed and running

```sh
oc get pods -n openshift-nfd
```

```sh
# expected output
NAME                                      READY   STATUS    RESTARTS   AGE
nfd-controller-manager-78758c57f7-7xfh4   2/2     Running   0          48s
```

Create an NodeFeatureDiscovery instance via the CLI or UI (recommended)

```yaml
kind: NodeFeatureDiscovery
apiVersion: nfd.openshift.io/v1
metadata:
  name: nfd-instance
  namespace: openshift-nfd
spec:
  operand:
    image: 'registry.redhat.io/openshift4/ose-node-feature-discovery-rhel9@sha256:a98a205e5541550dfd46caaf52147f078101a6c6e7221b7fb7cefb9581761dcb'
    servicePort: 12000
  workerConfig:
    configData: |
      core:
        sleepInterval: 60s
      sources:
        pci:
          deviceClassWhitelist:
            - "0200"
            - "03"
            - "12"
          deviceLabelFields:
            - "vendor"
```

Create the nfd instance object

```sh
oc apply -f configs/nfd-instance.yaml
```

```sh
# expected output
nodefeaturediscovery.nfd.openshift.io/nfd-instance created
```

![IMPORTANT]
The NFD Operator uses vendor PCI IDs to identify hardware in a node. NVIDIA uses the PCI ID 10de.

Verify the NFD pods are `Running` on the cluster nodes polling for devices
```sh
oc get pods -n openshift-nfd
```

```sh
# expected output
NAME                                      READY   STATUS    RESTARTS   AGE
nfd-controller-manager-78758c57f7-7xfh4   2/2     Running   0          99s
nfd-master-74db665cb6-vht4l               1/1     Running   0          25s
nfd-worker-8zkpz                          1/1     Running   0          25s
nfd-worker-d7wgh                          1/1     Running   0          25s
nfd-worker-l6sqx                          1/1     Running   0          25s
```

Verify the NVIDIA GPU is discovered

```sh
# list your nodes
oc get nodes

# display the role feature list of a gpu node
oc describe node <NODE_NAME> | egrep 'Roles|pci'
```

```sh
# expected output
Roles:              worker
                    feature.node.kubernetes.io/pci-10de.present=true
                    feature.node.kubernetes.io/pci-1d0f.present=true
```

Verify the NVIDIA GPU is discovered
10de appears in the node feature list for the GPU-enabled node. This mean the NFD Operator correctly identified the node from the GPU-enabled MachineSet.

### Installing the NVIDIA GPU Operator (10min)

[source](https://docs.nvidia.com/datacenter/cloud-native/openshift/latest/install-gpu-ocp.html#installing-the-nvidia-gpu-operator-using-the-cli)

List the available operators for installation searching for Node Feature Discovery (NFD)

```sh
oc get packagemanifests -n openshift-marketplace | grep gpu
```

```sh
# expected output
amd-gpu-operator                                   Community Operators   8h
gpu-operator-certified                             Certified Operators   8h
```

Create a Namespace custom resource (CR) that defines the nvidia-gpu-operator namespace

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: nvidia-gpu-operator
```

Apply the Namespace object YAML file

```sh
oc apply -f configs/nvidia-gpu-operator-ns.yaml
```

```sh
# expected output
namespace/nvidia-gpu-operator created
```

Create an OperatorGroup CR

```yaml
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: nvidia-gpu-operator-group
  namespace: nvidia-gpu-operator
spec:
 targetNamespaces:
 - nvidia-gpu-operator
 ```

Apply the OperatorGroup YAML file

```sh
oc apply -f configs/nvidia-gpu-operator-group.yaml 
```

```sh
# expected output
operatorgroup.operators.coreos.com/nvidia-gpu-operator-group created
```

Run the following command to get the channel value

```sh
oc get packagemanifest gpu-operator-certified -n openshift-marketplace -o jsonpath='{.status.defaultChannel}'
```

```sh
# expected output
v24.3
```

Run the following commands to get the startingCSV

```sh
# set channel value from output
CHANNEL=v24.3

# run the command to get the startingCSV
oc get packagemanifests/gpu-operator-certified -n openshift-marketplace -ojson | jq -r '.status.channels[] | select(.name == "'$CHANNEL'") | .currentCSV'
```

```sh
# expected output
gpu-operator-certified.v24.3.0
```

Create the following Subscription CR and save the YAML
Update the `channel` and `startingCSV` fields with the information returned

```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: gpu-operator-certified
  namespace: nvidia-gpu-operator
spec:
  channel: "v24.3"
  installPlanApproval: Automatic
  name: gpu-operator-certified
  source: certified-operators
  sourceNamespace: openshift-marketplace
  # startingCSV: "gpu-operator-certified.v24.3.0"
```

Apply the Subscription CR

```sh
oc apply -f configs/nvidia-gpu-operator-subscription.yaml
```

```sh
# expected output
subscription.operators.coreos.com/gpu-operator-certified created
```

Verify an install plan has been created

```sh
oc get installplan -n nvidia-gpu-operator
```

```sh
# expected output
NAME            CSV                              APPROVAL    APPROVED
install-q9rnm   gpu-operator-certified.v24.3.0   Automatic   true
```

(Optional) Approve the install plan if not `Automatic`

```sh
INSTALL_PLAN=$(oc get installplan -n nvidia-gpu-operator -oname)
```

Create the cluster policy

```sh
oc get csv -n nvidia-gpu-operator gpu-operator-certified.v24.3.0 -o jsonpath='{.metadata.annotations.alm-examples}' | jq '.[0]' > scratch/nvidia-gpu-clusterpolicy.json
```

Apply the clusterpolicy

```sh
oc apply -f scratch/nvidia-gpu-clusterpolicy.json
```

```sh
# expected output
clusterpolicy.nvidia.com/gpu-cluster-policy created
```

At this point, the GPU Operator proceeds and installs all the required components to set up the NVIDIA GPUs in the OpenShift 4 cluster. Wait at least 10-20 minutes before digging deeper into any form of troubleshooting because this may take a period of time to finish.

Verify the successful installation of the NVIDIA GPU Operator

```sh
oc get pods,daemonset -n nvidia-gpu-operator
```

```sh
# expected output
NAME                                                           DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR                                                                                                         AGE
daemonset.apps/gpu-feature-discovery                           0         0         0       0            0           nvidia.com/gpu.deploy.gpu-feature-discovery=true                                                                      22s
daemonset.apps/nvidia-container-toolkit-daemonset              0         0         0       0            0           nvidia.com/gpu.deploy.container-toolkit=true                                                                          22s
daemonset.apps/nvidia-dcgm                                     0         0         0       0            0           nvidia.com/gpu.deploy.dcgm=true                                                                                       22s
daemonset.apps/nvidia-dcgm-exporter                            0         0         0       0            0           nvidia.com/gpu.deploy.dcgm-exporter=true                                                                              22s
daemonset.apps/nvidia-device-plugin-daemonset                  0         0         0       0            0           nvidia.com/gpu.deploy.device-plugin=true                                                                              22s
daemonset.apps/nvidia-device-plugin-mps-control-daemon         0         0         0       0            0           nvidia.com/gpu.deploy.device-plugin=true,nvidia.com/mps.capable=true                                                  22s
daemonset.apps/nvidia-driver-daemonset-415.92.202406251950-0   2         2         0       2            0           feature.node.kubernetes.io/system-os_release.OSTREE_VERSION=415.92.202406251950-0,nvidia.com/gpu.deploy.driver=true   22s
daemonset.apps/nvidia-mig-manager                              0         0         0       0            0           nvidia.com/gpu.deploy.mig-manager=true                                                                                22s
daemonset.apps/nvidia-node-status-exporter                     2         2         2       2            2           nvidia.com/gpu.deploy.node-status-exporter=true                                                                       22s
daemonset.apps/nvidia-operator-validator                       0         0         0       0            0           nvidia.com/gpu.deploy.operator-validator=true                                                                         22s
```

Once the NVIDIA GPU Operator (specifically, nvidia-driver-daemonset) has finished, you can add a label to the GPU node Role as `gpu, worker` for readability (cosmetic).

```sh
oc label node -l nvidia.com/gpu.machine node-role.kubernetes.io/gpu=''
```

```sh
oc get nodes
```

```
# expected output
NAME                                        STATUS   ROLES                         AGE   VERSION
ip-10-0-xx-xxx.us-east-2.compute.internal   Ready    gpu,worker                    19h   v1.28.10+a2c84a5
ip-10-0-xx-xxx.us-east-2.compute.internal   Ready    gpu,worker                    19h   v1.28.10+a2c84a5
...
```

In order to apply this label to new machines/nodes:

```sh
# set an env value
MACHINE_SET_TYPE=$(oc -n openshift-machine-api get machinesets.machine.openshift.io -o name | grep gpu | head -n1)

# patch the machineset
oc -n openshift-machine-api \
  patch "${MACHINE_SET_TYPE}" \
  --type=merge --patch '{"spec":{"template":{"spec":{"metadata":{"labels":{"node-role.kubernetes.io/gpu":""}}}}}}'
```

```sh
# expected output
machineset.machine.openshift.io/cluster-xxxxx-xxxxx-worker-us-east-xc-gpu patched
```

### (Optional) Running a sample GPU Application (1min)

[Sample App](https://docs.nvidia.com/datacenter/cloud-native/openshift/latest/install-gpu-ocp.html#running-a-sample-gpu-application)

Run a simple CUDA VectorAdd sample, which adds two vectors together to ensure the GPUs have bootstrapped correctly

```sh
apiVersion: v1
kind: Pod
metadata:
  name: cuda-vectoradd
spec:
 restartPolicy: OnFailure
 containers:
 - name: cuda-vectoradd
   image: "nvidia/samples:vectoradd-cuda11.2.1"
   resources:
     limits:
       nvidia.com/gpu: 1
```

Create a test project

```sh
oc new-project sandbox
```

```sh
# expected output
Now using project "sandbox" on server "https://api.cluster-582gr.582gr.sandbox2642.opentlc.com:6443".
```

Create the sample app

```sh
oc create -f configs/nvidia-gpu-sample-app.yaml
```

```sh
# expected output
pod/cuda-vectoradd created
```

Check the logs of the container

```sh
oc logs cuda-vectoradd
```

```sh
# expected output
[Vector addition of 50000 elements]
Copy input data from the host memory to the CUDA device
CUDA kernel launch with 196 blocks of 256 threads
Copy output data from the CUDA device to the host memory
Test PASSED
Done
```

```sh
oc get pods
```

```sh
# expected output
oc get pods
NAME             READY   STATUS      RESTARTS   AGE
cuda-vectoradd   0/1     Completed   0          54s
```

Get information about the GPU

```sh
oc project nvidia-gpu-operator
```

View the new pods

```sh
oc get pod -o wide -l openshift.driver-toolkit=true
```

```sh
# expected output
NAME                                                  READY   STATUS    RESTARTS   AGE   IP            NODE                                       NOMINATED NODE   READINESS GATES
nvidia-driver-daemonset-415.92.202407091355-0-64sml   2/2     Running   2          21h   10.130.0.8    ip-10-0-22-25.us-east-2.compute.internal   <none>           <none>
nvidia-driver-daemonset-415.92.202407091355-0-clp7f   2/2     Running   2          21h   10.129.0.10   ip-10-0-22-15.us-east-2.compute.internal   <none>           <none>
```

With the Pod and node name, run the nvidia-smi on the correct node.

```sh
oc exec -it nvidia-driver-daemonset-410.84.202203290245-0-xxgdv -- nvidia-smi
```

```sh
# expected output
Fri Jul 26 20:06:33 2024       
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 550.54.15              Driver Version: 550.54.15      CUDA Version: 12.4     |
|-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
|                                         |                        |               MIG M. |
|=========================================+========================+======================|
|   0  Tesla T4                       On  |   00000000:00:1E.0 Off |                    0 |
| N/A   34C    P8             14W /   70W |       0MiB /  15360MiB |      0%      Default |
|                                         |                        |                  N/A |
+-----------------------------------------+------------------------+----------------------+
                                                                                         
+-----------------------------------------------------------------------------------------+
| Processes:                                                                              |
|  GPU   GI   CI        PID   Type   Process name                              GPU Memory |
|        ID   ID                                                               Usage      |
|=========================================================================================|
|  No running processes found                                                             |
+-----------------------------------------------------------------------------------------+
```

1. The first table reflects the information about all available GPUs (the example shows one GPU).
1. The second table provides details on the processes using the GPUs.

### Enabling the GPU Monitoring Dashboard (3min)

[source](https://docs.nvidia.com/datacenter/cloud-native/openshift/latest/enable-gpu-monitoring-dashboard.html)

Download the latest NVIDIA DCGM Exporter Dashboard from the DCGM Exporter repository on GitHub:

```sh
curl -Lf https://github.com/NVIDIA/dcgm-exporter/raw/main/grafana/dcgm-exporter-dashboard.json -o scratch/dcgm-exporter-dashboard.json
```

```sh
# expected output
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
100 18114  100 18114    0     0  23496      0 --:--:-- --:--:-- --:--:-- 23496
```

```sh
# check for modifications
diff -u configs/files/nvidia-dcgm-dashboard.json scratch/dcgm-exporter-dashboard.json
```

```sh
# expected output
<blank>
```

Create a config map from the downloaded file in the openshift-config-managed namespace

```sh
# create the configmap
# oc create configmap nvidia-dcgm-exporter-dashboard -n openshift-config-managed --from-file=configs/files/nvidia-dcgm-dashboard-cm.json
oc create -f configs/nvidia-dcgm-dashboard-cm.yaml
```

```sh
# expected output
configmap/nvidia-dcgm-exporter-dashboard created
```

Label the config map to expose the dashboard in the Administrator perspective of the web console `dashboard`:

```sh
oc label configmap nvidia-dcgm-exporter-dashboard -n openshift-config-managed "console.openshift.io/dashboard=true"
```

```sh
# expected output
configmap/nvidia-dcgm-exporter-dashboard labeled
```

Optional: Label the config map to expose the dashboard in the Developer perspective of the web console `odc-dashboard`:

```sh
oc label configmap nvidia-dcgm-exporter-dashboard -n openshift-config-managed "console.openshift.io/odc-dashboard=true"
```

```sh
# expected output
configmap/nvidia-dcgm-exporter-dashboard labeled
```

View the created resource and verify the labels

```sh
oc -n openshift-config-managed get cm nvidia-dcgm-exporter-dashboard --show-labels
```

```sh
# expected output
NAME                             DATA   AGE     LABELS
nvidia-dcgm-exporter-dashboard   1      3m28s   console.openshift.io/dashboard=true,console.openshift.io/odc-dashboard=true
```

View the NVIDIA DCGM Exporter Dashboard from the OCP UI from Administrator and Developer

### Installing the NVIDIA GPU administration dashboard (5min)

[source](https://docs.openshift.com/container-platform/4.12/observability/monitoring/nvidia-gpu-admin-dashboard.html)

Add the Helm repository

```sh
helm repo add rh-ecosystem-edge https://rh-ecosystem-edge.github.io/console-plugin-nvidia-gpu
```

```sh
# expected output
"rh-ecosystem-edge" has been added to your repositories

# possible output
"rh-ecosystem-edge" already exists with the same configuration, skipping
```

Helm update

```sh
helm repo update
```

```sh
# expected output
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "rh-ecosystem-edge" chart repository
<snipped>
Update Complete. ⎈Happy Helming!⎈
```

Install the Helm chart in the default NVIDIA GPU operator namespace

```sh
helm install -n nvidia-gpu-operator console-plugin-nvidia-gpu rh-ecosystem-edge/console-plugin-nvidia-gpu
```

```sh
# expected output
NAME: console-plugin-nvidia-gpu
LAST DEPLOYED: Tue Jul 16 18:28:55 2024
NAMESPACE: nvidia-gpu-operator
STATUS: deployed
REVISION: 1
NOTES:

<snipped>

...
```

Check if a plugins field is specified

```sh
oc get consoles.operator.openshift.io cluster --output=jsonpath="{.spec.plugins}"
```

```sh
# expected output
<blank>
```

If not, then run the following to enable the plugin

```sh
oc patch consoles.operator.openshift.io cluster --patch '[{"op": "add", "path": "/spec/plugins/-", "value": "console-plugin-nvidia-gpu" }]' --type=json
```

```sh
# expected output
console.operator.openshift.io/cluster patched
```

add the required DCGM Exporter metrics ConfigMap to the existing NVIDIA operator ClusterPolicy CR

```sh
oc patch clusterpolicies.nvidia.com gpu-cluster-policy --patch '{ "spec": { "dcgmExporter": { "config": { "name": "console-plugin-nvidia-gpu" } } } }' --type=merge
```

```sh
# expected output
clusterpolicy.nvidia.com/gpu-cluster-policy patched
```

You should receive a message on the console "Web console update is available" > Refresh the web console.

#### Go to Compute > GPUs

>Notice the `Telsa T4 Single-Instance` at the top of the screen. This GPU is not shareable (i.e. sliced, partitioned, fractioned) yet.

The dashboard relies mostly on Prometheus metrics exposed by the NVIDIA DCGM Exporter, but the default exposed metrics are not enough for the dashboard to render the required gauges. Therefore, the DGCM exporter is configured to expose a custom set of metrics, as shown here.

```sh
oc get cm console-plugin-nvidia-gpu -n nvidia-gpu-operator -o yaml
```

```sh
# expected output
apiVersion: v1
data:
  dcgm-metrics.csv: |
    DCGM_FI_PROF_GR_ENGINE_ACTIVE, gauge, gpu utilization.
    DCGM_FI_DEV_MEM_COPY_UTIL, gauge, mem utilization.
    DCGM_FI_DEV_ENC_UTIL, gauge, enc utilization.
    DCGM_FI_DEV_DEC_UTIL, gauge, dec utilization.
    DCGM_FI_DEV_POWER_USAGE, gauge, power usage.
    DCGM_FI_DEV_POWER_MGMT_LIMIT_MAX, gauge, power mgmt limit.
    DCGM_FI_DEV_GPU_TEMP, gauge, gpu temp.
    DCGM_FI_DEV_SM_CLOCK, gauge, sm clock.
    DCGM_FI_DEV_MAX_SM_CLOCK, gauge, max sm clock.
    DCGM_FI_DEV_MEM_CLOCK, gauge, mem clock.
    DCGM_FI_DEV_MAX_MEM_CLOCK, gauge, max mem clock.
kind: ConfigMap
metadata:
  annotations:
    meta.helm.sh/release-name: console-plugin-nvidia-gpu
    meta.helm.sh/release-namespace: nvidia-gpu-operator
  ...
  labels:
    app.kubernetes.io/component: console-plugin-nvidia-gpu
    app.kubernetes.io/instance: console-plugin-nvidia-gpu
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: console-plugin-nvidia-gpu
    app.kubernetes.io/part-of: console-plugin-nvidia-gpu
    app.kubernetes.io/version: latest
    helm.sh/chart: console-plugin-nvidia-gpu-0.2.4
  name: console-plugin-nvidia-gpu
  namespace: nvidia-gpu-operator
  ...
```

View the deployed resources

```sh
oc -n nvidia-gpu-operator get all -l app.kubernetes.io/name=console-plugin-nvidia-gpu
```

### GPU sharing methods

Why? By default, you get one workload per GPU. This is inefficient for certain use cases. [How can you share a GPU to 1:N workloads](https://docs.openshift.com/container-platform/4.15/architecture/nvidia-gpu-architecture-overview.html#nvidia-gpu-prerequisites_nvidia-gpu-architecture-overview):

For NVIDIA:

- [Time-slicing NVIDIA GPUs](https://docs.nvidia.com/datacenter/cloud-native/openshift/latest/time-slicing-gpus-in-openshift.html#)
- [Multi-Instance GPU (MIG)](https://docs.nvidia.com/datacenter/cloud-native/openshift/latest/mig-ocp.html)
- [NVIDIA vGPUs](https://docs.nvidia.com/datacenter/cloud-native/openshift/23.9.2/nvaie-with-ocp.html?highlight=passthrough#openshift-container-platform-on-vmware-vsphere-with-nvidia-vgpus)

### Configuring GPUs with time slicing (3min)

[source](https://docs.nvidia.com/datacenter/cloud-native/openshift/latest/time-slicing-gpus-in-openshift.html#configuring-gpus-with-time-slicing)

The following sections show you how to configure NVIDIA Tesla T4 GPUs, as they do not support MIG, but can easily accept multiple small jobs.

The NVIDIA GPU Operator enables oversubscription of GPUs through a set of extended options for the NVIDIA Kubernetes Device Plugin. GPU time-slicing enables workloads that are scheduled on oversubscribed GPUs to interleave with one another.

You configure GPU time-slicing by performing the following high-level steps:

1. Add a config map to the namespace that is used by the GPU operator (i.e. `device-plugin-config`).
1. Configure the cluster policy so that the device plugin uses the config map. (i.e. `gpu-cluster-policy`)
1. Apply a label to the nodes that you want to configure for GPU time-slicing. (i.e. `Tesla-T4-SHARED`)

>Important: The ConfigMap name is `device-plugin-config` and the profile name is `time-sliced-8`. These names are important as you can change them for your purposes. You can list multiple GPU profiles like in the [ai-gitops-catalog](https://github.com/redhat-na-ssa/demo-ai-gitops-catalog/blob/main/components/operators/gpu-operator-certified/instance/components/time-sliced-4/patch-device-plugin-config.yaml). Also, [see Applying multi-node configuration](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/gpu-sharing.html#applying-multiple-node-specific-configurations)

On a machine with one GPU, the following config map configures Kubernetes so that the node advertises 8 GPU resources. A machine with two GPUs advertises 16 GPUs, and so on. [source](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/gpu-sharing.html#about-configuring-gpu-time-slicing)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: device-plugin-config
  namespace: nvidia-gpu-operator
data:
  time-sliced-8: |-
    version: v1
    sharing:
      timeSlicing:
        resources:
          - name: nvidia.com/gpu
            replicas: 8
```

Apply the device plugin configuration

```sh
oc apply -f configs/nvidia-gpu-deviceplugin-cm.yaml
```

```sh
# expected output
configmap/device-plugin-config created
```

Tell the GPU Operator which ConfigMap, in this case `device-plugin-config` to use for the device plugin configuration.

```sh
oc patch clusterpolicy gpu-cluster-policy \
    -n nvidia-gpu-operator --type merge \
    -p '{"spec": {"devicePlugin": {"config": {"name": "device-plugin-config"}}}}'
```

```sh
# expected output
clusterpolicy.nvidia.com/gpu-cluster-policy patched
```

Apply the configuration to all the nodes you have with Tesla T GPUs. GFD, labels the nodes with the GPU product, in this example Tesla-T4, so you can use a node selector to label all of the nodes at once.

```sh
oc label --overwrite node \
    --selector=nvidia.com/gpu.product=Tesla-T4 \
    nvidia.com/device-plugin.config=time-sliced-8
```

```sh
# expected output
node/ip-10-0-29-207.us-east-2.compute.internal labeled
node/ip-10-0-36-189.us-east-2.compute.internal labeled
```

Patch the NVIDIA GPU Operator ClusterPolicy to use the timeslicing configuration by default.

```sh
oc patch clusterpolicy gpu-cluster-policy \
    -n nvidia-gpu-operator --type merge \
    -p '{"spec": {"devicePlugin": {"config": {"default": "time-sliced-8"}}}}'
```

```sh
# expected output
clusterpolicy.nvidia.com/gpu-cluster-policy patched
```

The applied configuration creates eight replicas for Tesla T4 GPUs, so the nvidia.com/gpu external resource is set to 8. You can apply a cluster-wide default time-slicing configuration. You can also apply node-specific configurations. For example, you can apply a time-slicing configuration to nodes with Tesla-T4 GPUs only and not modify nodes with other GPU models.

```sh
oc get node --selector=nvidia.com/gpu.product=Tesla-T4-SHARED -o json | jq '.items[0].status.capacity'
```

The `-SHARED` product name suffix ensures that you can specify a node selector to assign pods to nodes with time-sliced GPUs.

```sh
# expected output
{
  "cpu": "16",
  "ephemeral-storage": "104266732Ki",
  "hugepages-1Gi": "0",
  "hugepages-2Mi": "0",
  "memory": "65029276Ki",
  "nvidia.com/gpu": "8",
  "pods": "250"
}
```

Verify that GFD labels have been added to indicate time-sharing.

1. The `nvidia.com/gpu.count` label reports the number of physical GPUs in the machine.
1. The `nvidia.com/gpu.product` label includes a `-SHARED` suffix to the product name.
1. The `nvidia.com/gpu.replicas` label matches the reported capacity.

```sh
oc get node --selector=nvidia.com/gpu.product=Tesla-T4-SHARED -o json \
 | jq '.items[0].metadata.labels' | grep nvidia
 ```

```sh
# expected output
  ...
  "nvidia.com/gpu.count": "1",
  ...
  "nvidia.com/gpu.product": "Tesla-T4-SHARED",
  "nvidia.com/gpu.replicas": "8",
  ...
```

### Configure Taints and Tolerations (3min)

Why? Prevent non-GPU workloads from being scheduled on the GPU nodes.

Taint the GPU nodes with `nvidia.com/gpu`. This MUST match the Accelerator profile taint key you use (by default may be different, i.e. `nvidia.com/gpu`).

```sh
oc adm taint node -l node-role.kubernetes.io/gpu nvidia.com/gpu=:NoSchedule --overwrite
```

```sh
# expected output
node/ip-10-0-22-15.us-east-2.compute.internal modified
node/ip-10-0-22-25.us-east-2.compute.internal modified
```

Edit the `ClusterPolicy` in the NVIDIA GPU Operator under the `nvidia-gpu-operator` project. Add the below section to `.spec.daemonsets:`

```sh
oc edit ClusterPolicy
```

```sh
  daemonsets:
    tolerations:
    - effect: NoSchedule
      operator: Exists
      key: nvidia.com/gpu
```

Cordon the GPU node, drain the GPU tainted nodes and terminate workloads

```sh
oc adm drain -l node-role.kubernetes.io/gpu --ignore-daemonsets --delete-emptydir-data
```

Allow the GPU node to be schedulable again per tolerations

```sh
oc adm uncordon -l node-role.kubernetes.io/gpu
```

Get the name of the gpu node

```sh
MACHINE_SET_TYPE=$(oc get machineset -n openshift-machine-api -o name |  egrep gpu)
```

Taint the machineset for any new nodes that get added to be tainted with `nvidia.com/gpu`

```sh
oc -n openshift-machine-api \
  patch "${MACHINE_SET_TYPE}" \
  --type=merge --patch '{"spec":{"template":{"spec":{"taints":[{"key":"nvidia.com/gpu","value":"","effect":"NoSchedule"}]}}}}'
```

Tolerations will be set in the RHOAI accelerator profiles that match the Taint key.

### (Optional) Configuring the cluster autoscaler

[source](https://docs.openshift.com/container-platform/4.15/machine_management/applying-autoscaling.html)

## Configuring distributed workloads

[source](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/2.10/html/working_with_distributed_workloads/configuring-distributed-workloads_distributed-workloads)

Components required for Distributed Workloads

1. dashboard
1. workbenches
1. datasciencepipelines
1. codeflare
1. kueue
1. ray

Verify the necessary pods are running - When the status of the codeflare-operator-manager-[pod-id], kuberay-operator-[pod-id], and kueue-controller-manager-[pod-id] pods is Running, the pods are ready to use.

```sh
oc get pods -n redhat-ods-applications | grep -E 'codeflare|kuberay|kueue'
```

```sh
# expected output
codeflare-operator-manager-6bbff698d-74fpz                        1/1     Running   7 (107m ago)   21h
kuberay-operator-bf97858f4-zg45s                                  1/1     Running   8 (10m ago)    21h
kueue-controller-manager-77c758b595-hgrz7                         1/1     Running   8 (10m ago)    21h
```

### Configuring quota management for distributed workloads (~5min)

Create an empty Kueue resource flavor
Why? Resources in a cluster are typically not homogeneous. A ResourceFlavor is an object that represents these resource variations (i.e. Nvidia A100 versus T4 GPUs) and allows you to associate them with cluster nodes through labels, taints and tolerations.

```yaml
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: default-flavor
spec:
  tolerations:
  - effect: NoSchedule
    operator: Exists
    key: nvidia.com/gpu
```

Apply the configuration to create the `default-flavor`

```sh
oc apply -f configs/rhoai-kueue-default-flavor.yaml
```

```sh
# expected output
resourceflavor.kueue.x-k8s.io/default-flavor created
```

Create a cluster queue to manage the empty Kueue resource flavor
Why? A ClusterQueue is a cluster-scoped object that governs a pool of resources such as pods, CPU, memory, and hardware accelerators. Only batch administrators should create ClusterQueue objects.

```yaml
apiVersion: kueue.x-k8s.io/v1beta1
kind: ClusterQueue
metadata:
  name: "cluster-queue"
spec:
  namespaceSelector: {}  # match all.
  resourceGroups:
  - coveredResources: ["cpu", "memory", "nvidia.com/gpu"]
    flavors:
    - name: "default-flavor"
      resources:
      - name: "cpu"
        nominalQuota: 9
      - name: "memory"
        nominalQuota: 36Gi
      - name: "nvidia.com/gpu"
        nominalQuota: 5
```

What is this cluster-queue doing? This ClusterQueue admits Workloads if and only if:

- The sum of the CPU requests is less than or equal to 9.
- The sum of the memory requests is less than or equal to 36Gi.
- The total number of pods is less than or equal to 5.

![IMPORTANT]
Replace the example quota values (9 CPUs, 36 GiB memory, and 5 NVIDIA GPUs) with the appropriate values for your cluster queue. The cluster queue will start a distributed workload only if the total required resources are within these quota limits. Only homogenous NVIDIA GPUs are supported.

Apply the configuration to create the `cluster-queue`

```sh
oc apply -f configs/rhoai-kueue-cluster-queue.yaml
```

```sh
# expected output
clusterqueue.kueue.x-k8s.io/cluster-queue created
```

Create a local queue that points to your cluster queue
Why? A LocalQueue is a namespaced object that groups closely related Workloads that belong to a single namespace. Users submit jobs to a LocalQueue, instead of to a ClusterQueue directly.

```yaml
apiVersion: kueue.x-k8s.io/v1beta1
kind: LocalQueue
metadata:
  namespace: sandbox
  name: local-queue-test
  annotations:
    kueue.x-k8s.io/default-queue: 'true'
spec:
  clusterQueue: cluster-queue
```

![NOTE]
Update the `name` and `namespace` accordingly.

Apply the configuration to create the local-queue object

```sh
oc new-project sandbox
oc apply -f configs/rhoai-kueue-local-queue.yaml
```

```sh
# expected output
localqueue.kueue.x-k8s.io/local-queue-test created
```

How do users known what queues they can submit jobs to? Users submit jobs to a LocalQueue, instead of to a ClusterQueue directly. Tenants can discover which queues they can submit jobs to by listing the local queues in their namespace.

Verify the local queue is created

```sh
oc get -n sandbox queues
```

```sh
# expected output
NAME               CLUSTERQUEUE    PENDING WORKLOADS   ADMITTED WORKLOADS
local-queue-test   cluster-queue   0 
```

### (Optional) Configuring the CodeFlare Operator (~5min)

Get the `codeflare-operator-config` configmap

```sh
oc get cm codeflare-operator-config -n redhat-ods-applications -o yaml
```

In the `codeflare-operator-config`, data:config.yaml:kuberay section, you can patch the [following](https://access.redhat.com/documentation/en-us/red_hat_openshift_ai_self-managed/2.10/html/working_with_distributed_workloads/configuring-distributed-workloads_distributed-workloads#configuring-the-codeflare-operator_distributed-workloads)

1. ingressDomain option is null (ingressDomain: "") by default.
1. mTLSEnabled option is enabled (mTLSEnabled: true) by default.
1. rayDashboardOauthEnabled option is enabled (rayDashboardOAuthEnabled: true) by default.

```yaml
kuberay:
  rayDashboardOAuthEnabled: true
  ingressDomain: ""
  mTLSEnabled: true
  #certGeneratorImage: quay.io/project-codeflare/ray:latest-py39-cu118
```

Recommended to keep default. If needed, apply the configuration to update the object

```sh
oc apply -f configs/rhoai-codeflare-operator-config.yaml
```

## Administrative Configurations for RHOAI

### Review RHOAI Dashboard Settings

Access the RHOAI Dashboard > Settings.

#### Notebook Images

- Import new notebook images  

#### Cluster Settings

- Model serving platforms
- PVC size (see Backing up data)
- Stop idle notebooks
- Usage data collection
- Notebook pod tolerations

#### Accelerator Profiles

- Manage accelerator profile settings for users in your organization

#### Add a new Accelerator Profile (~3min)

[Enabling GPU support in OpenShift AI](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/2.10/html/installing_and_uninstalling_openshift_ai_self-managed/enabling-gpu-support_install)

RHOAI dashboard and check the **Settings > Accelerator profiles** - There should be none listed.

Check the current configmap

```sh
oc get cm migration-gpu-status -n redhat-ods-applications -o yaml
```
```sh
# expected output
apiVersion: v1
data:
  migratedCompleted: "true"
kind: ConfigMap
metadata:
  creationTimestamp: "2024-07-16T17:43:10Z"
  name: migration-gpu-status
  namespace: redhat-ods-applications
  resourceVersion: "48442"
  uid: 1724c41a-8bbc-4619-a55f-df029d98f2ff
```

Delete the migration-gpu-status ConfigMap

```sh
oc delete cm migration-gpu-status -n redhat-ods-applications
```

```sh
# expected output
configmap "migration-gpu-status" deleted
```

Restart the dashboard replicaset

```sh
oc rollout restart deployment rhods-dashboard -n redhat-ods-applications
```

```sh
# expected output
deployment.apps/rhods-dashboard restarted
```

Wait until the Status column indicates that all pods in the rollout have fully restarted

```sh
oc get pods -n redhat-ods-applications | egrep rhods-dashboard
```

```sh
# expected output
rhods-dashboard-69b9bc879d-k6gzb                                  2/2     Running   6                25h
rhods-dashboard-7b67c58d9b-4xzr7                                  2/2     Running   0                67s
rhods-dashboard-7b67c58d9b-chgln                                  2/2     Running   0                67s
rhods-dashboard-7b67c58d9b-dk8sx                                  0/2     Running   0                7s
rhods-dashboard-7b67c58d9b-tsngh                                  2/2     Running   0                67s
rhods-dashboard-7b67c58d9b-x5v89                                  0/2     Running   0                7s
```

Refresh the RHOAI dashboard and check the **Settings > Accelerator profiles** - There should be `NVIDIA GPU` enabled.

Check the acceleratorprofiles

```sh
oc get acceleratorprofile -n redhat-ods-applications
```

```sh
# expected output
NAME           AGE
migrated-gpu   83s
```

Review the acceleratorprofile configuration

```sh
oc describe acceleratorprofile -n redhat-ods-applications
```

```sh
# expected output
Name:         migrated-gpu
Namespace:    redhat-ods-applications
Labels:       <none>
Annotations:  <none>
API Version:  dashboard.opendatahub.io/v1
Kind:         AcceleratorProfile
Metadata:
  Creation Timestamp:  2024-07-17T19:28:24Z
  Generation:          1
  Resource Version:    609012
  UID:                 8f64a27f-6593-43a6-873d-4796e920494f
Spec:
  Display Name:  NVIDIA GPU
  Enabled:       true
  Identifier:    nvidia.com/gpu
  Tolerations:
    Effect:    NoSchedule
    Key:       nvidia.com/gpu
    Operator:  Exists
Events:        <none>
```

Verify the `taints` key set in your Node / MachineSets match your `Accelerator Profile`.

#### Serving Runtimes

- Single-model serving platform
  - Caikit TGIS ServingRuntime for KServe
  - OpenVINO Model Server
  - TGIS Standalone ServingRuntime for KServe
- Multi-model serving platform
  - OpenVINO Model Server

##### Add serving runtime

From RHOAI, Settings > Serving runtimes > Click Add Serving Runtime.

Option 1:

- Select `Multi-model serving`
- Select `Start from scratch`
- Review, Copy and Paste in the content from `configs/rhoai-add-serving-runtime.yaml`
- Add and confirm the runtime can be selected in a Data Science Project

Option 2:

- Review `configs/rhoai-add-serving-runtime-template.yaml`
- `oc apply -f configs/rhoai-add-serving-runtime-template.yaml -n redhat-ods-applications`
- Add and confirm the runtime can be selected in a Data Science Project

#### User Management

- Data scientists
- Administrators

### Review Backing up data

Refer to [A Guide to High Availability / Disaster Recovery for Applications on OpenShift](https://www.redhat.com/en/blog/a-guide-to-high-availability/disaster-recovery-for-applications-on-openshift)

#### Control plane backup and restore operations

You must [back up etcd](https://docs.openshift.com/container-platform/4.15/backup_and_restore/control_plane_backup_and_restore/backing-up-etcd.html#backup-etcd) data before shutting down a cluster; etcd is the key-value store for OpenShift Container Platform, which persists the state of all resource objects.

#### Application backup and restore operations

The OpenShift API for Data Protection (OADP) product safeguards customer applications on OpenShift Container Platform. It offers comprehensive disaster recovery protection, covering OpenShift Container Platform applications, application-related cluster resources, persistent volumes, and internal images. OADP is also capable of backing up both containerized applications and virtual machines (VMs).

However, OADP does not serve as a disaster recovery solution for [etcd](https://docs.openshift.com/container-platform/4.15/backup_and_restore/control_plane_backup_and_restore/backing-up-etcd.html#backup-etcd) or OpenShift Operators.

## Answer key

The following command will apply all configurations from the checklist procedure above.

```sh
# setup machinesets for autoscaling
. configs/functions.sh
ocp_aws_cluster_autoscaling

# apply all configs (still need to patch things)
until oc apply -f configs; do : ; done
```
