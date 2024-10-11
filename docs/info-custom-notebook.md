## Create and add a custom notebook image

It is possible to take an existing supported RHOAI notebook image and add OS and Python packages. By launching a custom notebook image, users don't have to download custom packages every time they launch a notebook.

> [!NOTE]
> Red Hat supports the base notebook image, whereas the additional packages are the customer's responsibility.

In this example, we'll take the existing RHOAI `Minimal Python` notebook image and add OS and Python packages for ODBC database connections.

We will use the `2024.1` image tag of the `Minimal Python` base image and its corresponding Git commit files to modify the image.

Set environment variables.

```sh
BASE_IMAGE=`oc get istag s2i-minimal-notebook:2024.1 -n redhat-ods-applications -o jsonpath='{.image.dockerImageReference}'`
BUILD_COMMIT=`oc get is s2i-minimal-notebook -n redhat-ods-applications -o jsonpath='{.spec.tags[?(@.name=="2024.1")].annotations.opendatahub\.io\/notebook-build-commit}'`
BASE_REPO=https://github.com/red-hat-data-services/notebooks/tree/${BUILD_COMMIT}/jupyter/minimal
```

Navigate to the repo for the commit `${BUILD_COMMIT}` that was used to create the image.

```sh
echo $BASE_REPO
```

Download the raw versions of the Pipfile and Pipfile lock files.

```sh
curl -o Pipfile https://raw.githubusercontent.com/red-hat-data-services/notebooks/${BUILD_COMMIT}/jupyter/minimal/ubi9-python-3.9/Pipfile
curl -o Pipfile.lock https://raw.githubusercontent.com/red-hat-data-services/notebooks/${BUILD_COMMIT}/jupyter/minimal/ubi9-python-3.9/Pipfile.lock
```

Add Python package `pyodbc` to the Pipfile and Pipfile lock.

```sh
pipenv upgrade "pyodbc~=5.1.0"
```

Now create a Containerfile. In the Containerfile, add the OS package `unixODBC` which is required for the `pyodbc` module.

```sh
cat > Containerfile <<EOF
FROM $BASE_IMAGE

# Install OS packages
USER 0

RUN INSTALL_PKGS="unixODBC" && \
    yum install -y --setopt=tsflags=nodocs \$INSTALL_PKGS && \
    yum -y clean all --enablerepo='*'

USER 1001

# Install Python packages
COPY Pipfile.lock ./

RUN echo "Installing softwares and packages" && \
    micropipenv install && \
    rm -f ./Pipfile.lock && \
    chmod -R g+w /opt/app-root/lib/python3.9/site-packages && \
    fix-permissions /opt/app-root -P
EOF
```

Create an Image Stream for the custom notebook image

```sh
oc create is custom-notebook-image -n redhat-ods-applications
```

Create a Build Config for the custom notebook image

```sh
oc create -n redhat-ods-applications -f - <<EOF
apiVersion: build.openshift.io/v1
kind: BuildConfig
metadata:
  name: custom-notebook-image
  labels:
    name: custom-notebook-image
spec:
  triggers:
    - type: ConfigChange
  source:
    git:
      uri: 'https://github.com/red-hat-data-services/notebooks.git'
    type: Git
  strategy:
    type: Docker
    dockerStrategy:
      dockerfilePath: "Containerfile"
  output:
    to:
      kind: ImageStreamTag
      name: 'custom-notebook-image:v1.0'
EOF
```

Start a new build using the local directory contents

```sh
oc start-build custom-notebook-image -n redhat-ods-applications --from-dir . --follow
```

Get a reference to the custom image registry

```sh
CUSTOM_IMAGE_REGISTRY=$(oc get is custom-notebook-image -n redhat-ods-applications -o jsonpath='{.status.dockerImageRepository}'):v1.0
echo $CUSTOM_IMAGE_REGISTRY
```

The custom notebook image can now be imported to RHOAI.

Navigate to the RHOAI dashboard -> `Settings` -> `Notebook images` -> `Import new image`

Specify your image repository in the Image location. Give it a name and add displayed content if you would like.

The custom notebook image can now be launched in a workbench.
