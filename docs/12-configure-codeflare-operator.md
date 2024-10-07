## 12. (Optional) Configure the CodeFlare Operator (~5min)

### Steps

- Get the `codeflare-operator-config` configmap

  - ```sh
      oc get cm codeflare-operator-config -n redhat-ods-applications -o yaml
    ```

In the `codeflare-operator-config`, data:config.yaml:kuberay section, you can patch the [following](https://access.redhat.com/documentation/en-us/red_hat_openshift_ai_self-managed/2.10/html/working_with_distributed_workloads/Configure-distributed-workloads_distributed-workloads#Configure-the-codeflare-operator_distributed-workloads)

1. `ingressDomain` option is null (ingressDomain: "") by default.
1. `mTLSEnabled` option is enabled (mTLSEnabled: true) by default.
1. `rayDashboardOauthEnabled` option is enabled (rayDashboardOAuthEnabled: true) by default.

- Recommended to keep default. If needed, apply the configuration to update the object

  - ```sh
      oc apply -f configs/12/rhoai-codeflare-operator-config.yaml
    ```

## Automation key (Catch up)

- From this repository's root directory, run below command
  - ```sh
      ./scripts/runstep.sh -s 12
    ```
