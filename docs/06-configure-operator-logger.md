# 6. (Optional) Configure the RHOAI Operator logger

### Objectives

- Configuring logging level for the RHOAI Operator

### Rationale

- Help with debugging

### Takeaways

- The DSCI file configures the log level

> You can change the log level for RHOAI Operator (`development`, `""`, `production`) components by setting the .spec.devFlags.logmode flag for the DSC Initialization/DSCI CR during runtime. If you do not set a logmode value, the logger uses the INFO log level by default. [More Info](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/2.10/html/Install_and_unInstall_openshift_ai_self-managed/Install-and-deploying-openshift-ai_install#Configure-the-operator-logger_operator-log).

## Steps

- [ ] Configure the log level from the OpenShift CLI by using the following command with the logmode value set to the log level that you want

```sh
oc patch dsci default-dsci -p '{"spec":{"devFlags":{"logmode":"development"}}}' --type=merge
```

```sh
# expected output
dscinitialization.dscinitialization.opendatahub.io/default-dsci patched
```

- [ ] Viewing the RHOAI Operator log

```sh
oc get pods -l name=rhods-operator -o name -n redhat-ods-operator |  xargs -I {} oc logs -f {} -n redhat-ods-operator
```

> You can also view via the console
> **Workloads > Deployments > Pods > redhat-ods-operator > Logs**

## Automation key (Catch up)

- [ ] From this repository's root directory, run below command

```sh
./scripts/setup.sh -s 6
```
