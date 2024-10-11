# Red Hat OpenShift AI BootCamp

[![Spelling](https://github.com/redhat-na-ssa/hobbyist-guide-to-rhoai/actions/workflows/spellcheck.yml/badge.svg)](https://github.com/redhat-na-ssa/hobbyist-guide-to-rhoai/actions/workflows/spellcheck.yml)

**Acronyms**:

- RHOCP = Red Hat OpenShift Container Platform
- RHOAI = Red Hat OpenShift AI
- ODH = Open Data Hub
- CR = Custom Resource

## About RHOAI

Red Hat OpenShift AI is a platform for data scientists and developers of artificial intelligence and machine learning applications.

OpenShift AI provides an environment to develop, train, serve, test, and monitor AI/ML models and applications on-premise or in the cloud. [More Info](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/2.13/html/introduction_to_red_hat_openshift_ai/index)

- Learn more about features and dependencies [(link)](/docs/info-features.md)

## Cluster Setup Steps

0. [Prerequisite](/docs/00-prerequisite.md)
1. [Add administrative user](/docs/01-add-administrative-user.md)
1. [(Optional) Install the web terminal](/docs/02-install-web-terminal.md)
1. [Enable GPU support for RHOAI](/docs/03-enable-gpu-support.md)
1. [(Optional) Run sample GPU application](/docs/04-run-sample-gpu-application.md)
1. [Configure GPU dashboards](/docs/05-configure-gpu-dashboards.md)
1. [Configure GPU sharing method](/docs/06-configure-gpu-sharing-method.md)
1. [Install RHOAI Kserve dependencies](/docs/07-install-kserve-dependencies.md)
1. [Install RHOAI Operator and Components](/docs/08-install-rhoai-operator.md)
1. [Configure RHOAI / Data Science Pipelines](/docs/09-configure-rhoai.md)
1. [Configure distributed workloads](/docs/10-configure-distributed-workloads.md)

### Automation Key

To run all steps, from this repo's root directory, run below command

```sh
./scripts/setup.sh -s 0
./scripts/setup.sh -s 10
```

> [!NOTE]
> Steps 9 - 10 are NOT fully automated, and might need manual configurations

> For more comprehensive gitops functionality, check out below repository:
> [**demo-ai-gitops-catalog**](https://github.com/redhat-na-ssa/demo-ai-gitops-catalog)

## Demo Instructions

1. [Distributed Workloads](/docs/11-demo-distributed_workloads.md)

1. [Fraud Detection](/docs/12-demo-fraud-detection.md)
