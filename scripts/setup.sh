#!/bin/bash

# shellcheck disable=SC1091

################# standard init #################

# 8 seconds is usually enough time for the average user to realize they foobar
export SLEEP_SECONDS=8

check_shell(){
  [ -n "$BASH_VERSION" ] && return
  echo -e "${ORANGE}WARNING: These scripts are ONLY tested in a bash shell${NC}"
  sleep "${SLEEP_SECONDS:-8}"
}

check_git_root(){
  if [ -d .git ] && [ -d scripts ]; then
    GIT_ROOT=$(pwd)
    export GIT_ROOT
    echo "GIT_ROOT:   ${GIT_ROOT}"
  else
    echo "Please run this script from the root of the git repo"
    exit
  fi
}

get_script_path(){
  SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
  echo "SCRIPT_DIR: ${SCRIPT_DIR}"
}

check_shell
check_git_root
get_script_path

# shellcheck source=/dev/null
. "${SCRIPT_DIR}/functions.sh"

################# standard init #################

DEFAULT_HTPASSWD=scratch/htpasswd-local
DEFAULT_ADMIN_PASS=scratch/password.txt

check_cluster_version(){
  OCP_VERSION=$(oc version | sed -n '/Server Version: / s/Server Version: //p')
  AVOID_VERSIONS=()
  TESTED_VERSIONS=("4.14.37" "4.16.14")

  echo "Current OCP version: ${OCP_VERSION}"
  echo "Tested OCP version(s): ${TESTED_VERSIONS[*]}"
  echo ""

  # shellcheck disable=SC2076
  if [[ " ${AVOID_VERSIONS[*]} " =~ " ${OCP_VERSION} " ]]; then
    echo "OCP version ${OCP_VERSION} is known to have issues with this demo"
    echo ""
    echo 'Recommend: "oc adm upgrade --to-latest=true"'
    echo ""
  fi
}

validate_cli(){
  echo ""
  echo "Validating command requirements..."
  bin_check oc
  bin_check helm
  bin_check jq
  echo ""
}

validate_cluster(){
  ocp_check_login
  check_cluster_version
}

add_admin_user(){
  DEFAULT_USER="admin"
  DEFAULT_PASS=$(genpass)

  HT_USERNAME=${1:-${DEFAULT_USER}}
  HT_PASSWORD=${2:-${DEFAULT_PASS}}

  echo "${HT_PASSWORD}" > "${DEFAULT_ADMIN_PASS}"

  htpasswd_ocp_get_file
  htpasswd_add_user "${HT_USERNAME}" "${HT_PASSWORD}"
  htpasswd_ocp_set_file
  htpasswd_validate_user "${HT_USERNAME}" "${HT_PASSWORD}"
}

help(){
  loginfo "This script installs RHOAI and other dependencies"
  loginfo "Usage: $(basename "$0") -s <step-number>"
  loginfo "Options:"
  loginfo " -h, --help   usage"
  loginfo " -s, --step   step number (required)"
  loginfo "        0       - Install prerequisites"
  loginfo "        1       - Add administrative user"
  loginfo "        2       - Enable gpu support"
  loginfo "        3       - Run sample gpu application"
  loginfo "        4       - Configure gpu dashboards"
  loginfo "        5       - Configure gpu sharing method"
  loginfo "        6       - Install kserve dependencies"
  loginfo "        7       - Install RHOAI operator"
  loginfo "        8       - Configure distributed workloads"
  loginfo "        9       - Configure rhoai / All"
  return 0
}

while getopts ":h:s:" flag; do
  case $flag in
    h) help ;;
    s) s=$OPTARG ;;
    \?) echo "Invalid option: -$OPTARG" >&1; exit 1 ;;
  esac
done

step_0(){
  logbanner "Install prerequisites"

  validate_cluster || return 1

  retry oc apply -f "${GIT_ROOT}"/configs/00

  validate_cli || return 1
}

step_1(){
  logbanner "Add administrative user"
  loginfo "Creating user 'admin'"

  if [ -f "${DEFAULT_ADMIN_PASS}" ]; then
    HT_PASSWORD=$(cat "${DEFAULT_ADMIN_PASS}")

    loginfo "Delete ${DEFAULT_ADMIN_PASS} to create a NEW password
    "

    htpasswd_validate_user "${HT_USERNAME}" "${HT_PASSWORD}"

    return
  else
    retry oc apply -f "${GIT_ROOT}"/configs/01
    add_admin_user admin
  fi
}

step_2(){
  logbanner "Enable gpu support"
  loginfo "Create a GPU machineset"
  ocp_aws_create_gpu_machineset
  # ocp_aws_cluster_autoscaling
  ocp_aws_taint_gpu_machineset
  ocp_scale_machineset
  # ocp_control_nodes_not_schedulable
  retry oc apply -f "${GIT_ROOT}"/configs/02
}

step_3(){
  logbanner "Run sample gpu application"
  retry oc apply -f "${GIT_ROOT}"/configs/03
}

step_4(){
  logbanner "Configure gpu dashboards"
  retry oc apply -f "${GIT_ROOT}"/configs/04
}

step_5(){
  logbanner "Configure gpu sharing method"
  retry oc apply -f "${GIT_ROOT}"/configs/05

}

step_6(){
  logbanner "Install kserve dependencies"
  retry oc apply -f "${GIT_ROOT}"/configs/06
}

step_7(){
  logbanner "Install RHOAI operator"
  retry oc apply -f "${GIT_ROOT}"/configs/07
}

step_8(){
  logbanner "Configure rhoai"
  retry oc apply -f "${GIT_ROOT}"/configs/08/minio
  retry oc apply -f "${GIT_ROOT}"/configs/08
}

step_9(){
  logbanner "Configure distributed workloads"
  retry oc apply -f "${GIT_ROOT}"/configs/09
}


workshop_uninstall(){
  logbanner "Uninstall Workshop"

  oc -n kube-system get secret/kubeadmin || return 1

  rm "${DEFAULT_HTPASSWD}"{,.txt} "${DEFAULT_ADMIN_PASS}"

  oc delete datasciencecluster default-dsc
  oc delete dscinitialization default-dsci

  sleep 8

  oc -n istio-system delete --all servicemeshcontrolplanes.maistra.io
  oc -n istio-system delete --all servicemeshmemberrolls.maistra.io
  oc delete --all -A servicemeshmembers.maistra.io

  oc -n knative-serving delete knativeservings.operator.knative.dev knative-serving
  oc delete consoleplugin console-plugin-nvidia-gpu
  oc -n pipeline-test delete --all datasciencepipelinesapplications

  oc delete csv -A -l operators.coreos.com/authorino-operator.openshift-operators
  oc delete csv -A -l operators.coreos.com/devworkspace-operator.openshift-operators
  oc delete csv -A -l operators.coreos.com/servicemeshoperator.openshift-operators
  oc delete csv -A -l operators.coreos.com/web-terminal.openshift-operators

  GPU_MACHINE_SET=$(oc -n openshift-machine-api get machinesets -o name | grep -E 'gpu|g4dn' | head -n1)
  for set in ${GPU_MACHINE_SET}
  do
    oc -n openshift-machine-api delete "$set"
  done

  oc delete -n openshift-operators deploy devworkspace-webhook-server

  oc delete \
    -f "${GIT_ROOT}"/configs/00 \
    -f "${GIT_ROOT}"/configs/01 \
    -f "${GIT_ROOT}"/configs/02 \
    -f "${GIT_ROOT}"/configs/03 \
    -f "${GIT_ROOT}"/configs/04 \
    -f "${GIT_ROOT}"/configs/05 \
    -f "${GIT_ROOT}"/configs/06 \
    -f "${GIT_ROOT}"/configs/07 \
    -f "${GIT_ROOT}"/configs/08 \
    -f "${GIT_ROOT}"/configs/08/minio \
    -f "${GIT_ROOT}"/configs/09 \
    -f "${GIT_ROOT}"/configs/uninstall

  oc apply \
    -f "${GIT_ROOT}"/configs/restore

}

setup(){

  if [ -z "$s" ]; then
      logerror "Step number is required"
      help
  fi

  if [ "$s" = "0" ] ; then
      loginfo "Running step 0"
      step_0
      exit 0
  fi

  for (( i=1; i <= s; i++ ))
  do
      loginfo "Running step $i"
      echo ""
      eval "step_$i"
  done
}

is_sourced || setup
