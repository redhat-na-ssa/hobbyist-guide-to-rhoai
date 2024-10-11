## 5. Adding a CA bundle

A CA bundle is a collection of root certificates that helps establish trust in SSL/TLS connections. When a client, like a web browser, connects to a server using SSL/TLS, the server provides its SSL certificate. The client then uses the CA bundle to verify that the certificate was issued by a trusted CA and that it hasn't been revoked. If the CA bundle can't verify the certificate, the client will usually display a warning or error message indicating that the connection is untrustworthy.
[More Info](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/2.10/html/Install_and_unInstall_openshift_ai_self-managed/working-with-certificates_certs#adding-a-ca-bundle_certs)

## Steps

- [ ] Set environment variables to define base directories for generation of a wildcard certificate and key for the gateways.

```sh
export BASE_DIR=/tmp/kserve
export BASE_CERT_DIR=${BASE_DIR}/certs
```

- [ ] Set an environment variable to define the common name used by the ingress controller of your OpenShift cluster

```sh
export COMMON_NAME=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' | awk -F'.' '{print $(NF-1)"."$NF}')
```

- [ ] Set an environment variable to define the domain name used by the ingress controller of your OpenShift cluster.

```sh
export DOMAIN_NAME=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')
```

- [ ] Create the required base directories for the certificate generation, based on the environment variables that you previously set.

```sh
mkdir ${BASE_DIR}
mkdir ${BASE_CERT_DIR}
```

- [ ] Create the OpenSSL configuration for generation of a wildcard certificate.

```sh
cat <<EOF> ${BASE_DIR}/openssl-san.config
[ req ]
distinguished_name = req
[ san ]
subjectAltName = DNS:*.${DOMAIN_NAME}
EOF
```

- [ ] Generate a root certificate.

```sh
openssl req -x509 -sha256 -nodes -days 3650 -newkey rsa:2048 \
-subj "/O=Example Inc./CN=${COMMON_NAME}" \
-keyout $BASE_DIR/root.key \
-out $BASE_DIR/root.crt
```

- [ ] Generate a wildcard certificate signed by the root certificate.

```sh
openssl req -x509 -newkey rsa:2048 \
-sha256 -days 3560 -nodes \
-subj "/CN=${COMMON_NAME}/O=Example Inc." \
-extensions san -config ${BASE_DIR}/openssl-san.config \
-CA $BASE_DIR/root.crt \
-CAkey $BASE_DIR/root.key \
-keyout $BASE_DIR/wildcard.key  \
-out $BASE_DIR/wildcard.crt
```

```sh
openssl x509 -in ${BASE_DIR}/wildcard.crt -text
```

- [ ] Verify the wildcard certificate.

```sh
openssl verify -CAfile ${BASE_DIR}/root.crt ${BASE_DIR}/wildcard.crt
```

```sh
# expected output
/tmp/kserve/wildcard.crt: OK
```

- [ ] Copy the `root.crt` to paste into `default-dcsi`.

```sh
cat ${BASE_DIR}/root.crt
```

```sh
# expected output-ish
-----BEGIN CERTIFICATE-----
certificateCERTIFICATECERTIFICATESDFCERTIFICATEcertificateCERTIFICATE
certificateCERTIFICATECERTIFICATESDFCERTIFICATEcertificateCERTIFICATE
certificateCERTIFICATECERTIFICATESDFCERTIFICATEcertificateCERTIFICATE
-----END CERTIFICATE-----
```

- [ ] Open your dscinitialization object `default-dsci` via the CLI or terminal
      `oc edit dscinitialization -n redhat-ods-applications`

- [ ] In the spec section, add the custom root signed certificate to the customCABundle field for trustedCABundle, as shown in the following example ( DON'T FORGET THE PIPE `|`):

```yaml
spec:
trustedCABundle:
  customCABundle: |
    -----BEGIN CERTIFICATE-----
    -----END CERTIFICATE-----
  managementState: Managed
```

```sh
# expected output
dscinitialization.dscinitialization.opendatahub.io/default-dsci edited
```

> in vi, you can use `:set nu` to show line numbers
> you can use `:34,53s/^/       /` to indent the pasted cert

- [ ] Verify the `odh-trusted-ca-bundle` configmap for your root signed cert in the `odh-ca-bundle.crt:` section

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

- [ ] Run the following command to verify that all non-reserved namespaces contain the odh-trusted-ca-bundle ConfigMap

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

## Automation key (Catch up)

- [ ] From this repository's root directory, run below command

```sh
./scripts/setup.sh -s 5
```
