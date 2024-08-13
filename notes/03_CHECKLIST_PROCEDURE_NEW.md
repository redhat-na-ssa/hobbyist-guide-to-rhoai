# Install the Red Hat OpenShift AI Operator

Acronyms:

- RHOCP = Red Hat OpenShift Container Platform
- RHOAI = Red Hat OpenShift AI
- ODH = Open Data Hub

>Intended commands to be executed from the root directory of the hobbyist-guide. The majority of the configurations to be applied are already created, with the exception of the ones that prompts you for specifics that are either created in the command or dumped to a `scratch` dir that is in the `.gitignore`.

## Access the cluster via your client CLI

Login to cluster via terminal

```sh
oc login <openshift_cluster_url> -u <admin_username> -p <password>
```

(optional) Configure bash completion - requires `oc` and `bash-completion` packages installed

```sh
source <(oc completion bash)
```

Git clone this repository to your local editor

```sh
git clone https://github.com/redhat-na-ssa/hobbyist-guide-to-rhoai.git
```

## Add administrative users

Only users with cluster administrator privileges can install and configure OpenShift AI.

You may be logged into the cluster as user `kubeadmin` which is an automatically generated temporary user that should not be used as a best practice. See 06_APPENDIX.md for more details on best practices and patching if needed.

For this procedure, we are using HTpasswd as the Identity Provider (IdP). HTPasswd updates the files that store usernames and password for authentication of HTTP users. RHOAI uses the same IdP as Red Hat OpenShift Container Platform, such as: [htpasswd, keystone, LDAP, basic-authentication, request-header, GitHub, GitLab, Google, OpenID Connect](https://docs.redhat.com/en/documentation/openshift_container_platform/4.15/html/authentication_and_authorization/understanding-identity-provider#supported-identity-providers).

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
# git clone
oc create secret generic htpasswd-secret --from-file=htpasswd=scratch/users.htpasswd -n openshift-config
```

```sh
# expected output
secret/htpasswd-secret created
```

```sh
# this creates a secret/htpasswd-secret object in openshift-config
oc get secret/htpasswd-secret -n openshift-config
```

```sh
# expected output
NAME              TYPE     DATA   AGE
htpasswd-secret   Opaque   1      4m46s
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

```sh
# verify the identity provider
oc get oauth/cluster -o yaml
```

You will have to a few minutes for the account to resolve.

```sh
# watch for the cluster operator to cycle 
oc get co authentication -w
```

As kubeadmin, assign the cluster-admin role to perform administrator level tasks. [See default cluster roles](https://docs.openshift.com/container-platform/4.15/authentication/using-rbac.html#default-roles_using-rbac)

```sh
oc adm policy add-cluster-role-to-user cluster-admin <user>
```

```sh
# expected output
clusterrole.rbac.authorization.k8s.io/cluster-admin added: "<username>"
```

```sh
oc get users 
```

If needed, see [Updating users for an htpasswd identity provider](https://docs.redhat.com/en/documentation/openshift_container_platform/4.15/html-single/authentication_and_authorization/index#identity-provider-htpasswd-update-users_configuring-htpasswd-identity-provider)

```sh
# expected output

NAME    UID                                    FULL NAME   IDENTITIES
admin   5cdea351-fd1d-4b81-9e75-1f05d34104d4               htpasswd:admin
```

Log in to the cluster as a user from your identity provider, entering the password when prompted

NOTE: You may need to add the parameter `--insecure-skip-tls-verify=true` if your clusters api endpoint does not have a trusted cert.

```sh
oc login --insecure-skip-tls-verify=true -u <username> -p <password>
```

The remainder of the procedure should be completed with the new cluster-admin <user>.

## (Optional) Install the Web Terminal Operator

The Web Terminal Operator provides users with the ability to create a terminal instance embedded in the OpenShift Console. This is useful to provide a consistent terminal experience for those using Microsoft OS or MacOS. It also minimizes context switching between the browser and local client. [docs](https://docs.redhat.com/en/documentation/openshift_container_platform/4.15/html/web_console/web-terminal).

>[NOTE] We could not do this sooner as `kubeadmin` is able to install the Web Terminal Operator, however unable to create web terminal instances [source](https://github.com/redhat-developer/web-terminal-operator/issues/162).

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
subscription.operators.coreos.com/web-terminal created
```

From the OCP Web Console, Refresh the browser and click the `>_` icon in the top right of the window. This can serve as your browser based CLI.

You can `git clone` in the instance and complete the rest of the procedure.

```sh
# clone in the web terminal
git clone https://github.com/redhat-na-ssa/hobbyist-guide-to-rhoai.git

# check the dir
ls

# change directory
cd hobbyist-guide-to-rhoai/

# make scratch dir
mkdir scratch
```

## Install RHOAI Optional Dependencies

Before you install RHOAI, it is important to understand how it's dependencies will be managed as it be automated or not. Below are required and **use-case dependent operators**:

1. `Red Hat OpenShift Serverless Operator` (if RHOAI KServe is planned for serving, this is required)
1. `Red Hat OpenShift Service Mesh Operator` (if RHOAI KServe is planned for serving, this is required)
1. `Red Hat Authorino Operator` (if you want to authenticate KServe model API endpoints with a route, RHOAI recommended)
1. `Red Hat Node Feature Discovery (NFD) Operator` (if additional hardware features are beiing utilized, like GPU)
1. `NVIDIA GPU Operator` (if NVIDIA GPU accelerators exist)
1. `NVIDIA Network Operator` (if NVIDIA Infiniband accelerators exist)
1. `Kernel Module Management (KMM) Operator` (if Intel Gaudi/AMD accelerators exist)
1. `HabanaAI Operator` (if Intel Gaudi accelerators exist)
1. `AMD GPU Operator` (if AMD accelerators exist)

>NOTE: NFD and KMM operators exists with other patterns, these are the most common.

There are 3x RHOAI Operator dependency states to be set: `Managed`, `Removed`, and `Unmanaged`.

1. `Managed` = The RHOAI Operator manages the dependency (i.e. Service Mesh, Serverless, etc.). RHOAI manages the operands, not the operators. This is where FeatureTrackers come into play.
1. `Removed` = The RHOAI Operator removes the dependency. Changing from `Managed` to `Removed` does remove the dependency.
1. `Unmanaged` = The RHAOI Operator does not manage the dependency allowing for an administrator to manage it instead.  Changing from `Managed` to `Unmanaged` does not remove the dependency. For example, this is important when the customer has an existing Service Mesh. It won't create it when it doesn't exist, but you can make manual changes.

### Install RHOAI KServe dependencies

RHOAI provides 2x primary methods for serving models that you would choose depending on both resources constraints and inference use cases:

1. `Model Mesh`
1. `KServe`

The `ModelMesh` framework is a general-purpose model serving management/routing layer designed for high-scale, high-density and frequently-changing model use cases. There are no extra dependencies needed to configure this solution.

`KServe` has specific dependencies and provides an interface for serving predictive and generative machine learning (ML) models.

- To support the RHOAI KServe component, you must also install Operators for `Red Hat OpenShift Service Mesh` (based on `Istio`) and `Red Hat OpenShift Serverless` (based on  `Knative`). Furthermore, if you want to add an authorization provider, you must also install `Red Hat Authorino Operator` (based on `Kuadrant`).

Because `Service Mesh`, `Serverless`, and `Authorino` will be `Managed` in this procedure, we only need to install the operators. We will not configure instances (i.e. control plane, members, etc.).

#### Install Red Hat OpenShift Service Mesh Operator

A service mesh is an infrastructure layer that simplifies the communication between services in a loosely-coupled/ microservices architecture without requiring any changes to the application code. It includes a collection of lightweight network proxies, known as sidecars, which are placed next to each service in the system.

Red Hat OpenShift Service Mesh, is based on the open source Istio project.

Service Mesh is made up of a `data plane` (service discovery, health checks, routing, load balancing, Authn and Authz, and observability) and `control plane` (configuration and policy for all of the data planes).

How Istio relates to KServe:

1. `KServe (Inference) Data Plane` - consists of a static graph of components (predictor, transformer, explainer) which coordinate requests for a single model. Advanced features such as Ensembling, A/B testing, and Multi-Arm-Bandits should compose InferenceServices together.
1. `KServe Control Plane` - creates the Knative serverless deployment for predictor, transformer, explainer to enable autoscaling based on incoming request workload including scaling down to zero when no traffic is received. When raw deployment mode is enabled, control plane creates Kubernetes deployment, service, ingress, HPA.

Create the required namespace for Red Hat OpenShift Service Mesh.

```sh
oc create ns istio-system
```

```sh
# expected output
namespace/istio-system created
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

For `Unmanaged` configuration details, see the 06_APPENDIX.md.

#### Install Red Hat OpenShift Serverless Operator

Serverless computing is a method of providing backend services on an as-used basis. Servers are still used to execute code. However, developers of serverless applications are not concerned with capacity planning, configuration, management, maintenance, fault tolerance, or scaling of containers, virtual machines, or physical servers. Overall, serverless computing can simplify the process of deploying code into production.

OpenShift Serverless provides Kubernetes native building blocks that enable developers to create and deploy serverless, event-driven applications on RHOCP. It's is based on the open source Knative project, which provides portability and consistency for hybrid and multi-cloud environments by a providing a platform-agnostic solution for running serverless deployments. [source](https://docs.redhat.com/en/documentation/red_hat_openshift_serverless/1.33/html/about_openshift_serverless/about-serverless)

[source](https://access.redhat.com/documentation/en-us/red_hat_openshift_ai_self-managed/2.10/html/serving_models/serving-large-models_serving-large-models#creating-a-knative-serving-instance_serving-large-models)

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

For `Unmanaged` deployments additional steps need to be executed. See the Define a ServiceMeshMember for Serverless in the 06_APPENDIX.md

#### Install Red Hat Authorino Operator

In order to front services with Auth{n,z}, Authorino provides an authorization proxy (using Envoy) for publicly  exposed [KServe inference endpoint](https://access.redhat.com/documentation/en-us/red_hat_openshift_ai_self-managed/2.10/html/serving_models/serving-large-models_serving-large-models#manually-adding-an-authorization-provider_serving-large-models). You can enable token authorization for models that you expose outside the platform to ensure that only authorized parties can make inference requests.

Create subscription for the Authorino Operator

```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: authorino-operator
  namespace: openshift-operators
spec:
  channel: tech-preview-v1
  installPlanApproval: Automatic
  name: authorino-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
```

Apply the Authorino subscription
```sh
oc create -f configs/authorino-subscription.yaml
```

```sh
# expected output
subscription.operators.coreos.com/authorino-operator created
```

For `Unmanaged` deployments additional steps need to be executed. See the Configure Authorino for Unmanaged deployments in the 06_APPENDIX.md

## Install the Red Hat OpenShift AI Operator

[source](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/2.10/html/Install_and_unInstall_openshift_ai_self-managed/Install-and-deploying-openshift-ai_install#Install-the-openshift-data-science-operator_operator-install)

Check the pre-requisite operators in order to fully deploy RHOAI components.

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

Create a namespace object CR

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

Create an OperatorGroup object CR

```yaml
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: rhods-operator
  namespace: redhat-ods-operator 
```

Create the OperatorGroup object 

```sh
oc create -f configs/rhoai-operator-group.yaml
```

```sh
# expected output
operatorgroup.operators.coreos.com/rhods-operator created
```

Create a Subscription object CR file, for example, rhoai-operator-subscription.yaml

>Understanding `update channels`. We are using `stable` channel as this gives customers access to the stable product features. `fast` can lead to an inconsistent experience as it is only supported for 1 month and it updated every month. [source](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/2.10/html-single/Install_and_unInstall_openshift_ai_self-managed/index#understanding-update-channels_install).

```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhods-operator
  namespace: redhat-ods-operator 
spec:
  name: rhods-operator
  channel: stable-2.10 
  source: redhat-operators
  sourceNamespace: openshift-marketplace
```

Create the Subscription object

```sh
oc create -f configs/rhoai-operator-subscription.yaml
```

```sh
# expected output
subscription.operators.coreos.com/rhods-operator created
```

Check the created projects `redhat-ods-applications|redhat-ods-monitoring|redhat-ods-operator`

When you install the Red Hat OpenShift AI Operator in the OpenShift cluster, the following new projects are created:

1. `redhat-ods-operator` contains the Red Hat OpenShift AI Operator.
1. `redhat-ods-applications` installs the dashboard and other required components of OpenShift AI.
1. `redhat-ods-monitoring` contains services for monitoring.
1. `rhods-notebooks` is where an individual user notebook environments are deployed by default.
1. You or your data scientists must create additional projects for the applications that will use your machine learning models.

```sh
oc get projects | grep -E "redhat-ods|rhods"
```

```sh
# expected output
redhat-ods-applications                                           Active
redhat-ods-monitoring                                             Active
redhat-ods-operator                                               Active
rhods-notebooks                                                   Active
```

>IMPORTANT
Do not install independent software vendor (ISV) applications in namespaces associated with OpenShift AI.

The RHOAI Operator is installed with a 'default-dcsi' object with the following. Notice how the `serviceMesh` is `Managed`. By default, RHOAI is managing `ServiceMesh`.

```sh
oc describe DSCInitialization -n redhat-ods-operator
```

```yaml
# expected output

...
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
...
```

### Install and managing Red Hat OpenShift AI components

In order to use the RHOAI Operator, you must create a DataScienceCluster instance. Create a DataScienceCluster object custom resource (CR) file, for example, rhoai-operator-dsc.yaml

```yaml
apiVersion: datasciencecluster.opendatahub.io/v1
kind: DataScienceCluster
metadata:
  name: default-dsc
  labels:
    app.kubernetes.io/name: datasciencecluster
    app.kubernetes.io/instance: default-dsc
    app.kubernetes.io/part-of: rhods-operator
    app.kubernetes.io/managed-by: kustomize
    app.kubernetes.io/created-by: rhods-operator
spec:
  components:
    codeflare:
      managementState: Managed
    kserve:
      serving:
        ingressGateway:
          certificate:
            type: OpenshiftDefaultIngress
        managementState: Managed
        name: knative-serving
      managementState: Managed
    ray:
      managementState: Managed
    kueue:
      managementState: Managed
    workbenches:
      managementState: Managed
    dashboard:
      managementState: Managed
    modelmeshserving:
      managementState: Managed
    datasciencepipelines:
      managementState: Managed
    trainingoperator:
      managementState: Removed
```

>When you manually installed KServe, you set the value of the managementState to `Unmanaged` within the Kserve component in the DataScienceCluster and MUST update the DSCInitialization object.

Create the DSC object

```sh
oc create -f configs/rhoai-operator-dsc.yaml 
```

```sh
# expected output

datasciencecluster.datasciencecluster.opendatahub.io/default-dsc created
```

For `Unmanaged` dependencies, see the Install and managing Red Hat OpenShift AI components on the 06_APPENDIX.md.

The RHOAI Operator has instances deployed as a result of Install the operator.

TODO Add watch

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

## Adding a CA bundle

TODO Why add CA Bundle

[source](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/2.10/html/Install_and_unInstall_openshift_ai_self-managed/working-with-certificates_certs#adding-a-ca-bundle_certs)

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

Verify the `odh-trusted-ca-bundle` configmap for your root signed cert in the `odh-ca-bundle.crt:` section

```sh
oc get cm/odh-trusted-ca-bundle -o yaml -n redhat-ods-applications
```

```sh
# expected output
...
 odh-ca-bundle.crt: |
    -----BEGIN CERTIFICATE-----
    -----END CERTIFICATE-----  
... 
```

Run the following command to verify that all non-reserved namespaces contain the odh-trusted-ca-bundle ConfigMap
```sh
oc get configmaps --all-namespaces -l app.kubernetes.io/part-of=opendatahub-operator | grep odh-trusted-ca-bundle
```

```sh
# expected output
istio-system                            odh-trusted-ca-bundle   2      14m
knative-eventing                        odh-trusted-ca-bundle   2      14m
knative-serving                         odh-trusted-ca-bundle   2      14m
redhat-ods-applications-auth-provider   odh-trusted-ca-bundle   2      14m
redhat-ods-applications                 odh-trusted-ca-bundle   2      14m
redhat-ods-monitoring                   odh-trusted-ca-bundle   2      14m
redhat-ods-operator                     odh-trusted-ca-bundle   2      14m
rhods-notebooks                         odh-trusted-ca-bundle   2      6m14s
```

## (Optional) Configure the OpenShift AI Operator logger

[source](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/2.10/html/Install_and_unInstall_openshift_ai_self-managed/Install-and-deploying-openshift-ai_install#Configure-the-operator-logger_operator-log) You can change the log level for OpenShift AI Operator (`development`, `""`, `production`) components by setting the .spec.devFlags.logmode flag for the DSC Initialization/DSCI custom resource during runtime. If you do not set a logmode value, the logger uses the INFO log level by default.

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

## Enabling GPU support for OpenShift AI

In order to enable GPUs for RHOAI, you must follow the procedure to [enable GPUs for RHOCP](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/2.10/html/Install_and_unInstall_openshift_ai_self-managed/enabling-gpu-support_install). Once completed, RHOAI requires an Accelerator Profile cusstome resource definition in the `redhat-ods-applications`. Currently, NVIDIA and Intel Gaudi are the supported [accelerator profiles](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/2.10/html/working_with_accelerators/overview-of-accelerators_accelerators#overview-of-accelerators_accelerators).

### Adding a GPU node to an existing OpenShift Container Platform cluster

You can copy and modify a default compute machine set configuration to create a GPU-enabled machine set and machines for the AWS EC2 cloud provider.

[source](https://docs.redhat.com/en/documentation/openshift_container_platform/4.15/html/machine_management/managing-compute-machines-with-the-machine-api#nvidia-gpu-aws-adding-a-gpu-node_creating-machineset-aws)

View the existing nodes
```sh
oc get nodes
```

```sh
# expected output
NAME                                        STATUS   ROLES                         AGE     VERSION
ip-10-x-xx-xxx.us-xxxx-x.compute.internal   Ready    control-plane,master,worker   5h11m   v1.28.10+a2c84a5
```

View the machines and machine sets that exist in the openshift-machine-api namespace
```sh
oc get machinesets -n openshift-machine-api
```

```sh
# expected output
NAME                                    DESIRED   CURRENT   READY   AVAILABLE   AGE
cluster-xxxxx-xxxxx-worker-us-xxxx-xc   0         0                             5h13m
```

Make a copy of one of the existing compute MachineSet definitions and output the result to a YAML file

```sh
# get your machineset names
oc get machineset -n openshift-machine-api

# make a copy of an existing machineset definition
oc get machineset <your-machineset-name> -n openshift-machine-api -o yaml > scratch/machineset.yaml
```

Update the following fields:

- [ ] ~Line 13`.metadata.name` to a name containing `-gpu`.
- [ ] ~Line 18 `.spec.replicas` from `0` to `2`
- [ ] ~Line 22`.spec.selector.matchLabels["machine.openshift.io/cluster-api-machineset"]` to match the new `.metadata.name`.
- [ ] ~Line 29 `.spec.template.metadata.labels["machine.openshift.io/cluster-api-machineset"]` to match the new `.metadata.name`.
- [ ] ~Line 51 `.spec.template.spec.providerSpec.value.instanceType` to `g4dn.4xlarge`.

Remove the following fields:

- [ ] ~Line 10 `generation`
- [ ] ~Line 16 `uid` (becomes line 15 if you delete line 10 first)

Apply the configuration to create the gpu machine

```sh
oc apply -f scratch/machineset.yaml
```

```sh
# expected output
machineset.machine.openshift.io/cluster-xxxx-xxxx-worker-us-xxxx-gpu created
```

Verify the gpu machineset you created is running

```sh
oc -n openshift-machine-api get machinesets | grep gpu
```

```sh
# expected output
cluster-xxxxx-xxxxx-worker-us-xxxx-xc-gpu   2         2         2       2           6m37s
```

View the Machine object that the machine set created

```sh
oc -n openshift-machine-api get machines | grep gpu
```

```sh
# expected output
cluster-xxxxx-xxxxx-worker-us-xxxx-xc-gpu-29whc   Running   g4dn.4xlarge   us-xxxx-x   us-xxxx-xc   7m59s
cluster-xxxxx-xxxxx-worker-us-xxxx-xc-gpu-nr59d   Running   g4dn.4xlarge   us-xxxx-x   us-xxxx-xc   7m59s
```

### Deploying the Node Feature Discovery Operator (takes time)

After the GPU-enabled node is created, you need to discover the GPU-enabled node so it can be scheduled. To do this, install the Node Feature Discovery (NFD) Operator. The NFD operator is a tool for OCP administrators that makes it easy to detect and understand the hardware features and configurations of a cluster's nodes. With this operator, administrators can easily gather information about their nodes that can be used for scheduling, resource management, and more by controlling the life cycle of NFD.

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
# watch the pods create in the new project
oc get pods -n openshift-nfd -w
```

```sh
# expected output
NAME                                      READY   STATUS    RESTARTS   AGE
nfd-controller-manager-78758c57f7-7xfh4   2/2     Running   0          48s
```

After Install the NFD Operator, you Create instance that installs the `nfd-master` and one `nfd-worker` pod for each compute node in the `openshift-nfd` namespace.

Create an NodeFeatureDiscovery instance via the CLI or UI (recommended). Pay attention the `spec.operand.image` from quay.io, the `sources.pci.deviceClassWhitelist`, and `sources.pci.deviceLabelFields`

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

[source](https://docs.openshift.com/container-platform/4.15/hardware_enablement/psap-node-feature-discovery-operator.html#Configure-node-feature-discovery-operator-sources_psap-node-feature-discovery-operator):

- `sources.pci.deviceClassWhitelist` is a list of [PCI device class IDs](https://admin.pci-ids.ucw.cz/read/PD) for which to publish a label. It can be specified as a main class only (for example, `03`) or full class-subclass combination (for example `0300`). The former implies that all subclasses are accepted. The format of the labels can be further configured with deviceLabelFields.
- `sources.pci.deviceLabelFields` is the set of PCI ID fields to use when constructing the name of the feature label. Valid fields are `class`, `vendor`, `device`, `subsystem_vendor` and `subsystem_device`. With the example config above, NFD would publish labels such as `feature.node.kubernetes.io/pci-<vendor-id>.present=true`

Create the nfd instance object

```sh
oc apply -f configs/nfd-instance.yaml
```

This creates NFD pods in the `openshift-nfd` namespace that poll RHOCP nodes for hardware resources and catalogue them.

```sh
# expected output
nodefeaturediscovery.nfd.openshift.io/nfd-instance created
```

![IMPORTANT]
The NFD Operator uses vendor PCI IDs to identify hardware in a node.

Below are some of the [PCI vendor ID assignments](https://pcisig.com/membership/member-companies?combine=10de):

- `10de`  NVIDIA
- `1d0f` AWS
- `1002` AMD
- `8086` Intel

Verify the GPU device (NVIDIA uses the PCI ID `10de`) is discovered on the GPU node. This mean the NFD Operator correctly identified the node from the GPU-enabled MachineSet.

```sh
oc describe node | egrep 'Roles|pci' | grep -v master
```

```sh
# expected output
Roles:              worker
                    feature.node.kubernetes.io/pci-10de.present=true
                    feature.node.kubernetes.io/pci-1d0f.present=true
                    feature.node.kubernetes.io/pci-1d0f.present=true
Roles:              worker
                    feature.node.kubernetes.io/pci-10de.present=true
                    feature.node.kubernetes.io/pci-1d0f.present=true
```

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

### Install the NVIDIA GPU Operator

Kubernetes provides access to special hardware resources such as NVIDIA GPUs, NICs, Infiniband adapters and other devices through the [device plugin framework](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/device-plugins/). However, Configure and managing nodes with these hardware resources requires configuration of multiple software components such as drivers, container runtimes or other libraries which are difficult and prone to errors. The NVIDIA GPU Operator uses the [operator framework](https://coreos.com/blog/introducing-operator-framework) within Kubernetes to automate the management of all NVIDIA software components needed to provision GPU. These components include:

1. the NVIDIA drivers (to enable CUDA) for creating high-performance, GPU-accelerated applications
1. Kubernetes device plugin for GPUs to advertise system hardware resources to the Kubelet
1. the NVIDIA Container Toolkit to build and run GPU accelerated containers
1. automatic node labelling using [GPU Feature Discovery (GFD)](https://github.com/NVIDIA/gpu-feature-discovery)
1. [NVIDIA Data Center GPU Manager (DCGM)](https://developer.nvidia.com/dcgm) for active health monitoring, comprehensive diagnostics, system alerts and governance policies including power and clock management

[source](https://docs.nvidia.com/datacenter/cloud-native/openshift/latest/install-gpu-ocp.html#Install-the-nvidia-gpu-operator-using-the-cli)

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
# set channel value
CHANNEL=$(oc get packagemanifest gpu-operator-certified -n openshift-marketplace -o jsonpath='{.status.defaultChannel}')
```

```sh
# echo the channel
echo $CHANNEL
```

```sh
# expected output
v24.6
```

Run the following commands to get the startingCSV

```sh
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

Verify an install plan has been created. Be patient.

```sh
# you can watch the installplan instances get created
oc get installplan -n nvidia-gpu-operator -w
```

```sh
# expected output
NAME            CSV                              APPROVAL    APPROVED
install-xxxx    gpu-operator-certified.v24.3.0   Automatic   true
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

(Optional) When the NVIDIA operator completes labeling the nodes, you can add a label to the GPU node Role as `gpu, worker` for readability (cosmetic). You may have to rerun this command for multilpe nodes.

```sh
oc label node -l nvidia.com/gpu.machine node-role.kubernetes.io/gpu=''
```

```sh
# expected output
node/ip-10-x-xx-xxx.us-xxxx-x.compute.internal labeled
```

```sh
oc get nodes
```

```sh
# expected output
NAME                                        STATUS   ROLES                         AGE   VERSION
ip-10-x-xx-xxx.us-xxxx-x.compute.internal   Ready    gpu,worker                    19h   v1.28.10+a2c84a5
ip-10-x-xx-xxx.us-xxxx-x.compute.internal   Ready    gpu,worker                    19h   v1.28.10+a2c84a5
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
machineset.machine.openshift.io/cluster-xxxxx-xxxxx-worker-us-xxxx-xc-gpu patched
```

### (Optional) Running a sample GPU Application

[Sample App](https://docs.nvidia.com/datacenter/cloud-native/openshift/latest/install-gpu-ocp.html#running-a-sample-gpu-application)

Run a simple CUDA VectorAdd sample, which adds two vectors together to ensure the GPUs have bootstrapped correctly

```yaml
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
nvidia-driver-daemonset-415.92.202407091355-0-64sml   2/2     Running   2          21h   10.xxx.0.x    ip-10-0-22-25.us-xxxx-x.compute.internal   <none>           <none>
nvidia-driver-daemonset-415.92.202407091355-0-clp7f   2/2     Running   2          21h   10.xxx.0.xx   ip-10-0-22-15.us-xxxx-x.compute.internal   <none>           <none>
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

### Enabling the GPU Monitoring Dashboard

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

View the created resource and verify the labels for the `dashboard` and `odc-dashboard`

```sh
oc -n openshift-config-managed get cm nvidia-dcgm-exporter-dashboard --show-labels
```

```sh
# expected output
NAME                             DATA   AGE     LABELS
nvidia-dcgm-exporter-dashboard   1      3m28s   console.openshift.io/dashboard=true,console.openshift.io/odc-dashboard=true
```

View the NVIDIA DCGM Exporter Dashboard from the OCP UI from Administrator and Developer

### Install the NVIDIA GPU administration dashboard

This is a dedicated administration dashboard for NVIDIA GPU usage visualization Web Console. The dashboard relies mostly on Prometheus metrics exposed by the NVIDIA DCGM Exporter, but the default exposed metrics are not enough for the dashboard to render the required gauges. Therefore, the DGCM exporter is configured to expose a custom set of metrics, as shown here.

[source](https://docs.openshift.com/container-platform/4.15/observability/monitoring/nvidia-gpu-admin-dashboard.html)

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

>NOTE: If your gauges are not displaying, you can go to your user (top right menu dropdown) > User Preferences > change your theme to `Light`.

#### Viewing the GPU Dashboard

Go to Compute > GPUs

>Notice the `Telsa T4 Single-Instance` at the top of the screen. This GPU is NOT shareable (i.e. sliced, partitioned, fractioned) yet. As Manfred Manns lyrics go, be ready to be `Blinded by the light`.

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

For NVIDIA GPU there are a few methods to optimize GPU utilization:

- [Time-slicing NVIDIA GPUs](https://docs.nvidia.com/datacenter/cloud-native/openshift/latest/time-slicing-gpus-in-openshift.html#)
- [Multi-Instance GPU (MIG)](https://docs.nvidia.com/datacenter/cloud-native/openshift/latest/mig-ocp.html)
- [NVIDIA vGPUs](https://docs.nvidia.com/datacenter/cloud-native/openshift/23.9.2/nvaie-with-ocp.html?highlight=passthrough#openshift-container-platform-on-vmware-vsphere-with-nvidia-vgpus)

### Configure GPUs with time slicing

[source](https://docs.nvidia.com/datacenter/cloud-native/openshift/latest/time-slicing-gpus-in-openshift.html#Configure-gpus-with-time-slicing)

The following sections show you how to configure NVIDIA Tesla T4 GPUs, as they do not support MIG, but can easily accept multiple small jobs.

The NVIDIA GPU Operator enables oversubscription of GPUs through a set of extended options for the NVIDIA Kubernetes Device Plugin. GPU time-slicing enables workloads that are scheduled on oversubscribed GPUs to interleave with one another.

You configure GPU time-slicing by performing the following high-level steps:

1. Add a config map to the namespace that is used by the GPU operator (i.e. `device-plugin-config`).
1. Configure the cluster policy so that the device plugin uses the config map. (i.e. `gpu-cluster-policy`)
1. Apply a label to the nodes that you want to configure for GPU time-slicing. (i.e. `Tesla-T4-SHARED`)

>Important: The ConfigMap name is `device-plugin-config` and the profile name is `time-sliced-8`. These names are important as you can change them for your purposes. You can list multiple GPU profiles like in the [ai-gitops-catalog](https://github.com/redhat-na-ssa/demo-ai-gitops-catalog/blob/main/components/operators/gpu-operator-certified/instance/components/time-sliced-4/patch-device-plugin-config.yaml). Also, [see Applying multi-node configuration](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/gpu-sharing.html#applying-multiple-node-specific-configurations)

On a machine with one GPU, the following config map configures Kubernetes so that the node advertises 8 GPU resources. A machine with two GPUs advertises 16 GPUs, and so on. [source](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/gpu-sharing.html#about-Configure-gpu-time-slicing)

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
node/ip-10-0-29-207.us-xxxx-x.compute.internal labeled
node/ip-10-0-36-189.us-xxxx-x.compute.internal labeled
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

>The `-SHARED` product name suffix ensures that you can specify a node selector to assign pods to nodes with time-sliced GPUs.

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

### Configure Taints and Tolerations

Why? Prevent non-GPU workloads from being scheduled on the GPU nodes.

Taint the GPU nodes with `nvidia.com/gpu`. This MUST match the Accelerator profile taint key you use (this could be different, i.e. `nvidia-gpu-only`).

```sh
oc adm taint node -l nvidia.com/gpu.machine nvidia.com/gpu=:NoSchedule --overwrite
```

```sh
# expected output
node/ip-10-x-xx-xxx.us-xxxx-x.compute.internal modified
node/ip-10-x-xx-xxx.us-xxxx-x.compute.internal modified
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
oc adm drain -l nvidia.com/gpu.machine --ignore-daemonsets --delete-emptydir-data
```

```sh
# expected output
node/ip-10-x-xx-xxx.us-xxxx-x.compute.internal cordoned
node/ip-10-x-xx-xxx.us-xxxx-x.compute.internal cordoned
...
evicting pod nvidia-gpu-operator/console-plugin-nvidia-gpu-754ddf45-8nfx5
evicting pod openshift-nfd/nfd-controller-manager-69fc4d5fb9-sflpw
evicting pod nvidia-gpu-operator/nvidia-cuda-validator-5v7lx
pod/nvidia-cuda-validator-5v7lx evicted
pod/console-plugin-nvidia-gpu-754ddf45-8nfx5 evicted
pod/nfd-controller-manager-69fc4d5fb9-sflpw evicted
node/ip-10-x-xx-xxx.us-xxxx-x.compute.internal drained
...
evicting pod nvidia-gpu-operator/gpu-operator-97655fdc-kgpb4
evicting pod sandbox/cuda-vectoradd
evicting pod openshift-marketplace/619c4bd263651f3b6508183066a8f9f3ef96907a573bfcd1d5252721a5csdd4
evicting pod openshift-operator-lifecycle-manager/collect-profiles-28709130-jqpcm
evicting pod nvidia-gpu-operator/nvidia-cuda-validator-fvwnh
evicting pod openshift-operator-lifecycle-manager/collect-profiles-28709145-mxvx7
evicting pod openshift-operator-lifecycle-manager/collect-profiles-28709160-p87sh
evicting pod openshift-marketplace/4e6357cf195932a62fceaa1d7eae5734b36af199315bc628f91659603bd95p9
pod/collect-profiles-28709130-jqpcm evicted
pod/cuda-vectoradd evicted
pod/619c4bd263651f3b6508183066a8f9f3ef96907a573bfcd1d5252721a5csdd4 evicted
pod/collect-profiles-28709145-mxvx7 evicted
pod/collect-profiles-28709160-p87sh evicted
pod/4e6357cf195932a62fceaa1d7eae5734b36af199315bc628f91659603bd95p9 evicted
pod/nvidia-cuda-validator-fvwnh evicted
pod/gpu-operator-97655fdc-kgpb4 evicted
node/ip-10-x-xx-xxx.us-xxxx-x.compute.internal drained
```

Allow the GPU node to be schedulable again per tolerations

```sh
oc adm uncordon -l nvidia.com/gpu.machine
```

```sh
# expected output
node/ip-10-x-xx-xxx.us-xxxx-x.compute.internal uncordoned
node/ip-10-x-xx-xxx.us-xxxx-x.compute.internal uncordoned
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

>IMPORTANT: Tolerations will be set in the RHOAI accelerator profiles that match the Taint key.

### (Optional) Configure the cluster autoscaler

[source](https://docs.openshift.com/container-platform/4.15/machine_management/applying-autoscaling.html)

## Configure distributed workloads

Why?
1. You can iterate faster and experiment more frequently because of the reduced processing time.
1. You can use larger datasets, which can lead to more accurate models.
1. You can use complex models that could not be trained on a single node.
1. You can submit distributed workloads at any time, and the system then schedules the distributed workload when the required resources are available.

Distributed Workloads is made of up a series of components.

1. CodeFlare Operator - Secures deployed Ray clusters and grants access to their URLs
1. CodeFlare SDK - Defines and controls the remote distributed compute jobs and infrastructure for any Python-based environment
1. KubeRay - Manages remote Ray clusters on OpenShift for running distributed compute workloads
1. Kueue - Manages quotas and how distributed workloads consume them, and manages the queueing of distributed workloads with respect to quotas

You can run distributed workloads from data science pipelines, from Jupyter notebooks, or from Microsoft Visual Studio Code files.

[source](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/2.10/html/working_with_distributed_workloads/Configure-distributed-workloads_distributed-workloads)

Components required for Distributed Workloads

1. dashboard
1. workbenches
1. datasciencepipelines
1. codeflare operator
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

### Configure quota management for distributed workloads

#### Create an empty Kueue resource flavor

Why? Resources in a cluster are typically not homogeneous. A ResourceFlavor is an object that describes these resource variations (i.e. Nvidia A100 versus T4 GPUs) and allows you to associate them with cluster nodes through labels, taints and tolerations.

A cluster administrator can create an empty ResourceFlavor object named `default-flavor`, without any labels or taints, as follows:

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

>In OpenShift AI 2.10, Red Hat supports only a single cluster queue per cluster (that is, homogenous clusters), and only empty resource flavors.

Apply the configuration to create the `default-flavor`

```sh
oc apply -f configs/rhoai-kueue-default-flavor.yaml
```

```sh
# expected output
resourceflavor.kueue.x-k8s.io/default-flavor created
```

#### Create a cluster queue to manage the empty Kueue resource flavor

Why? The Kueue ClusterQueue object manages a pool of cluster resources such as pods, CPUs, memory, and accelerators. A cluster can have multiple cluster queues, and each cluster queue can reference multiple resource flavors.

Cluster administrators can configure cluster queues to define the resource flavors that the queue manages, and assign a quota for each resource in each resource flavor. Cluster administrators can also configure usage limits and queueing strategies to apply fair sharing rules across multiple cluster queues in a cluster.

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

What is this cluster-queue doing? The example configures a cluster queue to assign a quota of 9 CPUs, 36 GiB memory, 5 pods, and 5 NVIDIA GPUs.

- The sum of the CPU requests is less than or equal to 9.
- The sum of the memory requests is less than or equal to 36Gi.
- The total number of pods is less than or equal to 5.

![IMPORTANT]
Replace the example quota values (9 CPUs, 36 GiB memory, and 5 NVIDIA GPUs) with the appropriate values for your cluster queue. The cluster queue will start a distributed workload only if the total required resources are within these quota limits, otherwise the cluster queue does not admit the distributed workload.. Only homogenous NVIDIA GPUs are supported.

Apply the configuration to create the `cluster-queue`

```sh
oc apply -f configs/rhoai-kueue-cluster-queue.yaml
```

```sh
# expected output
clusterqueue.kueue.x-k8s.io/cluster-queue created
```

#### Create a local queue that points to your cluster queue

Why? A LocalQueue is a namespaced object that groups closely related Workloads that belong to a single namespace. Users submit jobs to a LocalQueue, instead of to a ClusterQueue directly. A cluster administrator can optionally define one local queue in a project as the default local queue for that project.

When Configure a distributed workload, the user specifies the local queue name. If a cluster administrator configured a default local queue, the user can omit the local queue specification from the distributed workload code.

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

In this example, the kueue.x-k8s.io/default-queue: "true" annotation defines this local queue as the default local queue for the `sandbox` project. If a user submits a distributed workload in the `sandbox` project and that distributed workload does not specify a local queue in the cluster configuration, Kueue automatically routes the distributed workload to the `local-queue-test` local queue. The distributed workload can then access the resources that the cluster-queue cluster queue manages.

![NOTE]
Update the `name` and `namespace` accordingly.

Apply the configuration to create the local-queue object

```sh
oc project sandbox
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

### (Optional) Configure the CodeFlare Operator (~5min)

Get the `codeflare-operator-config` configmap

```sh
oc get cm codeflare-operator-config -n redhat-ods-applications -o yaml
```

In the `codeflare-operator-config`, data:config.yaml:kuberay section, you can patch the [following](https://access.redhat.com/documentation/en-us/red_hat_openshift_ai_self-managed/2.10/html/working_with_distributed_workloads/Configure-distributed-workloads_distributed-workloads#Configure-the-codeflare-operator_distributed-workloads)

1. `ingressDomain` option is null (ingressDomain: "") by default.
1. `mTLSEnabled` option is enabled (mTLSEnabled: true) by default.
1. `rayDashboardOauthEnabled` option is enabled (rayDashboardOAuthEnabled: true) by default.

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

[Enabling GPU support in OpenShift AI](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/2.10/html/Install_and_unInstall_openshift_ai_self-managed/enabling-gpu-support_install)

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
