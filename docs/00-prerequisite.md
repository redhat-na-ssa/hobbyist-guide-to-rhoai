# 0. Prerequisite

<p align="center">
<a href="/README.md">Prev</a>
&nbsp;&nbsp;&nbsp;
<a href="/docs/01-add-administrative-user.md">Next</a>
</p>

> Intended commands to be executed from the root directory of this repository. The majority of the configurations to be applied are already created, with the exception of the ones that prompts you for specifics that are either created in the command or dumped to a `scratch` dir that is ignored in the `.gitignore`.

- [ ] Have `cluster-admin` access to an OpenShift 4.14+ cluster
  - [Create an OpenShift 4.14+ cluster](/docs/info-create-openshift-cluster.md)
- [ ] Open a `bash` terminal on your local machine
- [ ] Git clone this repository

```sh
# git clone repo
git clone https://github.com/redhat-na-ssa/hobbyist-guide-to-rhoai.git

# change into the repo directory
cd hobbyist-guide-to-rhoai
```

- [ ] Create scratch directory

```sh
mkdir -p scratch
```

- [ ] Login to the cluster via terminal

```sh
oc login <openshift_cluster_url> -u <admin_username> -p <password>
```

> Refer [Here](/docs/info-create-openshift-cluster.md#get-cluster-url-and-admin-username-and-password) to see how to get user, password, and cluster url

> [!IMPORTANT]
> Don't forget to run below step

- [ ] Run prerequisites (from this repository's root directory)

```sh
./scripts/setup.sh -s 0
```

> [!NOTE]
> This will automatically setup the [web terminal](/docs/info-install-web-terminal.md).  
> You will have to manually 'Refresh' the console page to be able to invoke the web terminal.  
> For running the remaining steps you can:
>
> - Use the `bash` terminal on your local machine
> - Invoke web terminal (Refer below image)

![](/assets/00-web-terminal.gif)

<p align="center">
<a href="/README.md">Prev</a>
&nbsp;&nbsp;&nbsp;
<a href="/docs/01-add-administrative-user.md">Next</a>
</p>
