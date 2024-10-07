## Prerequisite

> Intended commands to be executed from the root directory of this repository. The majority of the configurations to be applied are already created, with the exception of the ones that prompts you for specifics that are either created in the command or dumped to a `scratch` dir that is ignored in the `.gitignore`.

- [ ] Git clone this repository
- [ ] Have `cluster-admin` access to an OpenShift 4.14+ cluster
  - or [create an OpenShift 4.14+ cluster](/docs/info-create-openshift-cluster.md)
- [ ] [Install OpenShift CLI](https://docs.openshift.com/container-platform/4.16/cli_reference/openshift_cli/getting-started-cli.html)
  - Have `oc` in your `$PATH`

```sh
# git clone repo
git clone https://github.com/redhat-na-ssa/hobbyist-guide-to-rhoai.git

# checkout sa-bootcamp branch
git checkout sa-bootcamp
```

Create scratch directory

```sh
mkdir scratch
```

Login to the cluster via terminal

```sh
oc login <openshift_cluster_url> -u <admin_username> -p <password>
```

> Refer [Here](/docs/info-create-openshift-cluster.md#get-cluster-url-and-admin-username-and-password) to see how to get user, password, and cluster url

Run prerequisites (from this repository's root directory, run below command)

```sh
./scripts/runstep.sh -s 0
```
