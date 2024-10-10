# 2. (Optional) Install the web terminal

### Objectives

- Subscribing the Web Terminal Operator

### Rationale

- Provide a consistent terminal experience for those using Microsoft OS or MacOS
- Minimize context switching

### Takeaways

- Many times we are shoulder surfing during deployments and this minimizes issues with different OSs (bash, zsh, etc.)
- You can [customize the terminal](https://github.com/redhat-na-ssa/demo-ai-gitops-catalog/tree/main/components/operators/web-terminal) with custom tooling and styles
- You can do the rest of this deployment in the terminal with your new user

> [!NOTE]
> We could not do this sooner as `kubeadmin` is able to install the Web Terminal Operator, however unable to create web terminal instances. [More info](https://github.com/redhat-developer/web-terminal-operator/issues/162).

## Steps

- [ ] Apply the subscription object

```sh
# Install web terminal operator
oc apply -f configs/02/web-terminal-subscription.yaml

# CRDs may take a few minutes to get setup by the operator
# Re-run the following command until it completes successfully
oc apply -f configs/02/web-terminal-tooling.yaml
```

> From the OCP Web Console, Refresh the browser and click the `>_` icon in the top right of the window. This can serve as your browser based CLI.

> Note: you can [customize the terminal](https://github.com/redhat-na-ssa/demo-ai-gitops-catalog/tree/main/components/operators/web-terminal) with custom tooling and styles.

> You can `git clone` in the instance and complete the rest of the procedure.

```sh
# change to home dir
cd ~

# clone in the web terminal
git clone https://github.com/redhat-na-ssa/hobbyist-guide-to-rhoai.git

# change directory
cd hobbyist-guide-to-rhoai/

# checkout below branch
git checkout hshishir-25ba6c

# make scratch dir
mkdir scratch
```

## Validation

![ ](/assets/02-validation.gif)

## Automation key (Catch up)

- [ ] From this repository's root directory, run below command

```sh
./scripts/setup.sh -s 2
```
