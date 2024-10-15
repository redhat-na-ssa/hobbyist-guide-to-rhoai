## Create OpenShift cluster for bootcamp

Your cluster must have at least **2 worker nodes with at least 8 CPUs and 32 GiB RAM available for OpenShift AI** to use when you install the Operator. To ensure that OpenShift AI is usable, additional cluster resources are required beyond the minimum requirements.

### Steps

- Go to redhat demo site and order **"AWS with OpenShift Open Environment"** [LINK](https://demo.redhat.com/catalog?category=Open_Environments&item=babylon-catalog-prod%2Fsandboxes-gpte.sandbox-ocp.prod)

- Choose below options:

  - Activity = Practice/Enablement
  - Purpose = Conduct internal training/enablement
  - Control Plane Instance Type = m6a.4xlarge

![](/assets/create-openshift-cluster.gif)

- Wait for cluster to be provisioned. It takes approximately 45 minutes, so please be patient :)

### Get cluster URL and admin username and password

- After cluster is provisioned, go to **Services** page on Red Hat demo platform page that shows your service information
- **OPTIONAL**: It may make sense to SSH into the bastion host specified here, before working with the username and password for the cluster, if you're unable to manage or install command line tools in your environment.
- Get

![](/assets/oc-url-user.png)
