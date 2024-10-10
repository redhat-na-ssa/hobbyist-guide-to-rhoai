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
  bin_check oc
  echo ""
}

validate_cluster(){
  ocp_check_login
  check_cluster_version
}

validate_setup(){
  echo ""
  echo "Validating requirements..."

  validate_cli
  validate_cluster
}

add_admin_user(){
  DEFAULT_USER="admin"
  DEFAULT_PASS=$(genpass)

  HT_USERNAME=${1:-${DEFAULT_USER}}
  HT_PASSWORD=${2:-${DEFAULT_PASS}}

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
  loginfo "        2       - (Optional) Install web terminal"
  loginfo "        3       - Enable gpu support"
  loginfo "        4       - Run sample gpu application"
  loginfo "        5       - Configure gpu dashboards"
  loginfo "        6       - Configure gpu sharing method"
  loginfo "        7       - Install kserve dependencies"
  loginfo "        8       - Install RHOAI operator"
  loginfo "        9       - Configure distributed workloads"
  loginfo "        10      - Configure rhoai / All"
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
  validate_setup || return 1
  
  logbanner "Install prerequisites"
  retry oc apply -f "${GIT_ROOT}"/configs/00
}

step_1(){
  logbanner "Add administrative user"
  loginfo "Creating user 'admin'"

  if [ -f "${DEFAULT_HTPASSWD}.txt" ]; then
    HT_PASSWORD=$(sed '/admin/ s/# .* - //' "${DEFAULT_HTPASSWD}.txt")
    
    htpasswd_validate_user "${HT_USERNAME}" "${HT_PASSWORD}"

    echo "Delete ${DEFAULT_HTPASSWD}.txt to recreate password
    "

    return
  else
    retry oc apply -f "${GIT_ROOT}"/configs/01
    add_admin_user admin    
  fi
}

step_2(){
  logbanner "(Optional) Install web terminal"
  loginfo "Web Terminal"
  retry oc apply -f "${GIT_ROOT}"/configs/02
}

step_3(){
  logbanner "Enable gpu support"
  loginfo "Create a GPU node with autoscaling"
  ocp_aws_cluster_autoscaling
  ocp_aws_taint_gpu_machineset
  ocp_scale_machineset
  ocp_control_nodes_not_schedulable
  retry oc apply -f "${GIT_ROOT}"/configs/03
}

step_4(){
  logbanner "Run sample gpu application"
  retry oc apply -f "${GIT_ROOT}"/configs/04
}

step_5(){
  logbanner "Configure gpu dashboards"
  retry oc apply -f "${GIT_ROOT}"/configs/05
  retry oc apply -k "${GIT_ROOT}"/configs/05/console-plugin
}

step_6(){
  logbanner "Configure gpu sharing method"
  retry oc apply -f "${GIT_ROOT}"/configs/06

}

step_7(){
  logbanner "Install kserve dependencies"
  retry oc apply -f "${GIT_ROOT}"/configs/07
}

step_8(){
  logbanner "Install RHOAI operator"
  retry oc apply -f "${GIT_ROOT}"/configs/08
}

step_9(){
  logbanner "Configure distributed workloads"
  retry oc apply -f "${GIT_ROOT}"/configs/09
}

step_10(){
  logbanner "Configure rhoai"
  retry oc apply -f "${GIT_ROOT}"/configs/10
}

workshop_uninstall(){
  logbanner "Uninstall Workshop"

  rm "${DEFAULT_HTPASSWD}"{,.txt}

  oc delete datasciencecluster default-dsc
  oc delete dscinitialization default-dsci
  oc delete -n istio-system --all servicemeshmemberrolls.maistra.io
  oc delete -n istio-system --all servicemeshcontrolplanes.maistra.io
  oc delete -A --all servicemeshmembers.maistra.io
  oc delete -n knative-serving knativeservings.operator.knative.dev knative-serving

  oc delete csv -A -l operators.coreos.com/authorino-operator.openshift-operators
  oc delete csv -A -l operators.coreos.com/devworkspace-operator.openshift-operators
  oc delete csv -A -l operators.coreos.com/servicemeshoperator.openshift-operators
  oc delete csv -A -l operators.coreos.com/web-terminal.openshift-operators

  oc delete -n openshift-operators deploy devworkspace-webhook-server 

  oc delete \
    -f "${GIT_ROOT}"/configs/00 \
    -f "${GIT_ROOT}"/configs/01 \
    -f "${GIT_ROOT}"/configs/02 \
    -f "${GIT_ROOT}"/configs/03 \
    -f "${GIT_ROOT}"/configs/04 \
    -f "${GIT_ROOT}"/configs/07 \
    -f "${GIT_ROOT}"/configs/08 \
    -f "${GIT_ROOT}"/configs/09 \
    -f "${GIT_ROOT}"/configs/10 \
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
