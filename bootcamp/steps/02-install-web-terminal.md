## 2. (Optional) Install the web terminal

The Web Terminal Operator provides users with the ability to create a terminal instance embedded in the OpenShift Console. This is useful to provide a consistent terminal experience for those using Microsoft OS or MacOS. It also minimizes context switching between the browser and local client. [More info](https://docs.redhat.com/en/documentation/openshift_container_platform/4.15/html/web_console/web-terminal).

> [NOTE] We could not do this sooner as `kubeadmin` is able to install the Web Terminal Operator, however unable to create web terminal instances. [More info](https://github.com/redhat-developer/web-terminal-operator/issues/162).

### Steps

- Apply the subscription object

  - ```sh
    oc apply -f configs/web-terminal-subscription.yaml
    ```
    ```sh
    # expected output
    subscription.operators.coreos.com/web-terminal configured
    ```

> From the OCP Web Console, Refresh the browser and click the `>_` icon in the top right of the window. This can serve as your browser based CLI.

> Note: you can [customize the terminal](https://github.com/redhat-na-ssa/demo-ai-gitops-catalog/tree/main/components/operators/web-terminal) with custom tooling and styles.

> You can `git clone` in the instance and complete the rest of the procedure.

```sh
# clone in the web terminal
git clone https://github.com/redhat-na-ssa/hobbyist-guide-to-rhoai.git

# change directory
cd hobbyist-guide-to-rhoai/

# make scratch dir
mkdir scratch
```

## Automation key (Catch up)

- From this repository's root directory, run below command
  - ```sh
      ./bootcamp/scripts/runstep.sh -s 2
    ```
