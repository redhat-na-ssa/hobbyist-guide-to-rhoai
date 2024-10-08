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
    echo "GIT_ROOT: ${GIT_ROOT}"
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

################# standard init #################

# shellcheck source=/dev/null
. "${SCRIPT_DIR}/functions.sh"

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

help() {
    loginfo "This script installs RHOAI and other dependencies"
    loginfo "Usage: $(basename "$0") -s <step-number>"
    loginfo "Options:"
    loginfo " -h, --help                  Show usage"
    loginfo " -s, --step                  step number (required)"
    loginfo "                             0     - Install prerequisites"
    loginfo "                             1     - Add administrative user"
    loginfo "                             2     - (Optional) Install web terminal"
    loginfo "                             3     - Install kserve dependencies"
    loginfo "                             4     - Install RHOAI operator"
    loginfo "                             5     - Add CA bundle"
    loginfo "                             6     - (Optional) Configure operator logger"
    loginfo "                             7     - Enable gpu support"
    loginfo "                             8     - Run sample gpu application"
    loginfo "                             9     - Configure gpu dashboards"
    loginfo "                             10    - Configure gpu sharing method"
    loginfo "                             11    - Configure distributed workloads"
    loginfo "                             12    - Configure codeflare operator"
    loginfo "                             13    - Configure rhoai"
    loginfo "                             14    - All setup"
    exit 0
}

# Default values
# add_admin_user=false
# install_operators=false
# create_gpu_node=false
# all_setup=false

while getopts ":h:s:" flag; do
    case $flag in
        h) help ;;
        s) s=$OPTARG ;;
        \?) echo "Invalid option: -$OPTARG" >&1; exit 1 ;;
    esac
done

step_0() {
    logbanner "Install prerequisites"
    until oc apply -f "${GIT_ROOT}"/configs/00; do : ; done
}

step_1() {
    logbanner "Adding administrative user"
    USER="admin1"
    PASSWORD="openshift1"
    loginfo "User: ${USER}"
    loginfo "Password: ${PASSWORD}"
    source "$SCRIPT_DIR/add-admin-user.sh" "${USER}" "${PASSWORD}"
}

step_2() {
    logbanner "(Optional) Install web terminal"
    loginfo "Web Terminal"
    until oc apply -f "${GIT_ROOT}"/configs/02; do : ; done
}

step_3() {
    logbanner "Install kserve dependencies"
    until oc apply -f "${GIT_ROOT}"/configs/03; do : ; done
}

step_4() {
    logbanner "Install RHOAI operator"
    until oc apply -f "${GIT_ROOT}"/configs/04; do : ; done
}

step_5() {
    logbanner "Add CA bundle"
    logwarning "Automation not implemented"
}

step_6() {
    logbanner "(Optional) Configure operator logger"
    oc patch dsci default-dsci -p '{"spec":{"devFlags":{"logmode":"development"}}}' --type=merge
}

step_7() {
    logbanner "Enable gpu support"
    loginfo "Create a GPU node with autoscaling"
    ocp_aws_cluster_autoscaling
    ocp_scale_machineset
    until oc apply -f "${GIT_ROOT}"/configs/07; do : ; done
}

step_8() {
    logbanner "Run sample gpu application"
    until oc apply -f "${GIT_ROOT}"/configs/08; do : ; done
}

step_9() {
    logbanner "Configure gpu dashboards"
    until oc apply -f "${GIT_ROOT}"/configs/09; do : ; done
}

step_10() {
    logbanner "Configure gpu sharing method"
    until oc apply -f "${GIT_ROOT}"/configs/10; do : ; done
}

step_11() {
    logbanner "Configure distributed workloads"
    until oc apply -f "${GIT_ROOT}"/configs/11; do : ; done
}

step_12() {
    logbanner "Configure codeflare operator"
    until oc apply -f "${GIT_ROOT}"/configs/12; do : ; done
}

step_13() {
    logbanner "Configure rhoai"
    until oc apply -f "${GIT_ROOT}"/configs/13; do : ; done
}

setup(){

    if [ -z "$s" ]; then
        logerror "Step number is required"
        help
    fi

    # create_log_file

    if [ "$s" -eq 0 ] ; then
        loginfo "Running step 0"
        step_0
        exit 0
    fi

    for (( i=1; i <= s; i++ ))
    do
        echo "Running step $i"
        eval "step_$i"
    done
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

validate_setup || return 1
setup