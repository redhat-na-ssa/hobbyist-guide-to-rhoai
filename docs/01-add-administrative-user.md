# 1. Add an administrative user

### Objectives

- Creating an admin user, with cluster-admin RB using HTpasswd as the IdP.

### Rationale

- Only users with cluster administrator privileges can install and configure RHOAI.

### Takeaways

- Customers care about RBAC and IdP for their data science users and tools; not all ISVs integrate (i.e. Run.ai)
- kubeadmin should not be used as a best practice
- You can patch the CRB
- Once you have a new account delete kubeadmin
- RHOAI stipulates 'Access to the cluster as a user with the cluster-admin role; the kubeadmin user is not allowed.'

> You may be logged into the cluster as user `kubeadmin`, which is an automatically generated temporary user that should not be used as a best practice. See \_APPENDIX.md for more details on best practices and patching if needed.

For this bootcamp, we are using HTpasswd as the Identity Provider (IdP). To learn more about supported IDPs refer [Here](https://docs.redhat.com/en/documentation/openshift_container_platform/4.15/html/authentication_and_authorization/understanding-identity-provider#supported-identity-providers).

![](/assets/user-auth.gif)

## Steps

- [ ] Create an htpasswd file to store the user and password information

```sh
htpasswd -c -B -b scratch/users.htpasswd <username> <password>
```

```sh
# expected output

Adding password for user <username>
```

- [ ] Create a secret to represent the htpasswd file

```sh
oc create secret generic htpasswd-local --from-file=htpasswd=scratch/users.htpasswd -n openshift-config
```

```sh
# expected output

secret/htpasswd-local created
```

- [ ] Verify you created a `secret/htpasswd-local` object in `openshift-config` project

```sh
oc get secret/htpasswd-local -n openshift-config
```

```sh
# expected output

NAME              TYPE     DATA   AGE
htpasswd-local   Opaque   1      4m46s
```

- [ ] Apply the resource to the default OAuth configuration to add the identity provider

```sh
oc apply -f configs/01/htpasswd-cr.yaml
```

```sh
# expected output

oauth.config.openshift.io/cluster configured
```

- [ ] Verify the identity provider

```sh
oc get oauth/cluster -o yaml
```

- [ ] Watch for the cluster operator to cycle

```sh
oc get co authentication -w
```

> [!WARNING]
> Ensure that you wait for the authentication ClusterOperator to become degraded, and then show Available with the "SINCE" column in a period of time related to you applying the OAuth configuration.

```sh
# expected output

NAME             VERSION   AVAILABLE   PROGRESSING   DEGRADED   SINCE   MESSAGE
authentication   4.16.6    True        False         False      0s
```

- [ ] As kubeadmin, assign the cluster-admin role to perform administrator level tasks

```sh
oc adm policy add-cluster-role-to-user cluster-admin <username>
```

```sh
# expected output

clusterrole.rbac.authorization.k8s.io/cluster-admin added: "<username>"
```

- [ ] Log in to the cluster as a user from your identity provider, entering the password when prompted.

```sh
oc cluster-info
```

> [!NOTE]
> You may need to add the parameter `--insecure-skip-tls-verify=true` if your clusters api endpoint does not have a trusted cert.

```sh
oc login https://api.cluster-<id>.<id>.sandbox.opentlc.com:6443 --insecure-skip-tls-verify=true -u <username> -p <password>
```

> [!NOTE]
> The remainder of the procedure should be completed with the new cluster-admin `<username>`.

## Validation

![](/assets/01-validation.gif)

## Automation key (catch up)

- [ ] From this repository's root directory, run below command

```sh
./scripts/setup.sh -s 1
```
