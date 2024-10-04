#!/bin/bash

# shellcheck disable=SC1091

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
PARENT_DIR="${SCRIPT_DIR%/*}"
PROJECT_DIR="${PARENT_DIR%/*}"

source "${PARENT_DIR}"/scripts/logging.sh
source "${PARENT_DIR}"/scripts/util.sh
source "${PARENT_DIR}"/scripts/functions.sh

help() {
    loginfo "This script installs RHOAI and other dependencies"
    loginfo "Usage: $(basename "$0")"
    loginfo "Options:"
    loginfo " -h, --help                  Show usage"
    loginfo " -u, --add-admin-user        Add an administrative user"
    loginfo " -o, --install-operators     Install all necessary operators"
    loginfo " -g, --create-gpu-node       Create a GPU node with autoscaling"
    loginfo " -a, --all-setup             Perform full setup"
    exit 0
}

# Default values
add_admin_user=false
install_operators=false
create_gpu_node=false
all_setup=false

while getopts ":h:u:o:g:a" opt; do
  case $opt in
    h) help ;;
    u) add_admin_user=$OPTARG ;;
    o) install_operators=$OPTARG ;;
    g) create_gpu_node=$OPTARG ;;
    a) all_setup=$OPTARG ;;
    \?) echo "Invalid option: -$OPTARG" >&1; exit 1 ;;
  esac
done

create_log_file() {
  LOG_FILE="cluster-setup_$(date +"%Y%m%d:%H%M").log"
  echo "Log file: ${LOG_FILE}"
  if [ ! -d "logs" ]; then
  loginfo "Creating logs directory"
  mkdir logs
  fi
  touch logs/"${LOG_FILE}"
}

setup(){

  create_log_file
  if [ "$all_setup" = true ]; then
    logbanner "Performing full setup on the cluster"
    add_admin_user=true
    create_gpu_node=true
    install_operators=true
  fi

  if [ "$add_admin_user" = true ]; then
    logbanner "Adding administrative user"
    USER="admin1"
    PASSWORD="openshift1"
    loginfo "User: ${USER}"
    loginfo "Password: ${PASSWORD}"
    # source "$SCRIPT_DIR/add-admin-user.sh" ${USER} ${PASSWORD}
  fi

  if [ "$create_gpu_node" = true ]; then
    logbanner "Creating a GPU node with autoscaling"
    ocp_aws_cluster_autoscaling
    ocp_scale_machineset
  fi

  if [ "$install_operators" = true ]; then
    logbanner "Installing all necessary operators"
    loginfo "Admin user"
    until oc apply -f "${PROJECT_DIR}"/bootcamp/configs/01; do : ; done
    loginfo "Web Terminal"
    until oc apply -f "${PROJECT_DIR}"/bootcamp/configs/02; do : ; done
    loginfo "Authorino, Serverless, Servicemesh"
    until oc apply -f "${PROJECT_DIR}"/bootcamp/configs/03; do : ; done
    until oc apply -f "${PROJECT_DIR}"/bootcamp/configs/04; do : ; done
    until oc apply -f "${PROJECT_DIR}"/bootcamp/configs/07; do : ; done
    until oc apply -f "${PROJECT_DIR}"/bootcamp/configs/08; do : ; done
    until oc apply -f "${PROJECT_DIR}"/bootcamp/configs/09; do : ; done
    until oc apply -f "${PROJECT_DIR}"/bootcamp/configs/10; do : ; done
    until oc apply -f "${PROJECT_DIR}"/bootcamp/configs/11; do : ; done
    until oc apply -f "${PROJECT_DIR}"/bootcamp/configs/12; do : ; done
    until oc apply -f "${PROJECT_DIR}"/bootcamp/configs/13; do : ; done
    fi
}

setup