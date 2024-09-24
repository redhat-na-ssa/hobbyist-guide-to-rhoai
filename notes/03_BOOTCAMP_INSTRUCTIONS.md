# RHOAI BootCamp Installation Instructions

## Pre-reqs
>Intended commands to be executed from the root directory of the hobbyist-guide. The majority of the configurations to be applied are already created, with the exception of the ones that prompts you for specifics that are either created in the command or dumped to a `scratch` dir that is ignored in the `.gitignore`.

- Have an OpenShift cluster ready with recommended config
- Install OpenShift CLI [Link](https://docs.openshift.com/container-platform/4.16/cli_reference/openshift_cli/getting-started-cli.html)
- Login to the cluster via terminal
    - ```sh
        oc login <openshift_cluster_url> -u <admin_username> -p <password>
        ```
- Git clone this repository
    - ```sh
        git clone https://github.com/redhat-na-ssa/hobbyist-guide-to-rhoai.git
        ```
    - ```sh
        # checkout sa-bootcamp branch
        git checkout sa-bootcamp
        ```
- Create scratch directory
    - ```sh
        mkdir scratch
        ```

## Intallation Steps

1. [Add administrative user](/bootcamp/steps/01-add-administrative-user.md)
1. [(Optional) Install the web terminal](/bootcamp/steps/02-install-web-terminal.md)
1. [Install RHOAI Kserve dependencies](/bootcamp/steps/03-install-kserve-dependencies.md)
1. [Install RHOAI Operator and Components](/bootcamp/steps/04-install-rhoai-operator.md)
1. [Add a CA bundle](/bootcamp/steps/05-add-ca-bundle.md)
1. [(Optional) Configure RHOAI Operator logger](/bootcamp/steps/06-configure-operator-logger.md)
1. [Enable GPU support for RHOAI](/bootcamp/steps/07-enable-gpu-support.md)
1. [(Optional) Run sample GPU application](/bootcamp/steps/08-run-sample-gpu-application.md)
1. [Configure GPU dashboards](/bootcamp/steps/09-configure-gpu-dashboards.md)
1. [Configure GPU sharing method](/bootcamp/steps/10-configure-gpu-sharing-method.md)
1. [Configure distributed workloads](/bootcamp/steps/11-configure-distributed-workloads.md)
1. [(Optional) Configure Codeflare operator](/bootcamp/steps/12-configure-codeflare-operator.md)
1. [Configure RHOAI](/bootcamp/steps/13-configure-rhoai.md)

## Automation Key

> You can avail automation to bring yourself upto speed.
> Automation has 4 different options:
- **Option 1** (Fix KubeAdmin bindings and add administrative user)
    - ```sh
        make add-admin-user
        ```
- **Option 2** (Install RHOAI and all necessary operators)
    - ```sh
        make install-operators
        ```
- **Option 3** (Enable GPU support and add GPU nodes)
    - ```sh
        make create-gpu-node
        ```

- **Option 4** (Perform full cluster setup, which covers above options as well)
    - ```sh
        make setup-cluster
        ```

> NOTE: `Steps 10 - 13 needs to be done manually for now`