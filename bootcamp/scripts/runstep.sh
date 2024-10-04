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
    loginfo "Usage: $(basename "$0") -s <step-number>"
    loginfo "Options:"
    loginfo " -h, --help                  Show usage"
    loginfo " -s, --step                  step number (required)"
    loginfo "                             1     - Add administrative user"
    loginfo "                             2     - (Optional) Install web terminal"
    loginfo "                             3     - Install kserve dependencies"
    loginfo "                             4     - Install RHOAI operator"
    loginfo "                             5     - Add CA bundle"
    loginfo "                             6     - Configure operator logger"
    loginfo "                             7     - Enable gpu support"
    loginfo "                             8     - Run sample gpu application"
    loginfo "                             9     - Configure gpu dashboards"
    loginfo "                             10    - Configure gpu sharing method"
    loginfo "                             11    - Configure distributed workloads"
    loginfo "                             12    - Configure rhoai"
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

create_log_file() {
    LOG_FILE="runstep_$(date +"%Y%m%d:%H%M").log"
    echo "Log file: ${LOG_FILE}"
    if [ ! -d "logs" ]; then
        loginfo "Creating logs directory"
        mkdir logs
    fi
    touch logs/"${LOG_FILE}"
}

step_1() {
    logbanner "Adding administrative user"
    USER="admin1"
    PASSWORD="openshift1"
    source "$SCRIPT_DIR/add-admin-user.sh" "${USER}" "${PASSWORD}"
}

step_2() {
    logbanner "(Optional) Install web terminal"
    loginfo "Web Terminal"
    until oc apply -f "${PROJECT_DIR}"/bootcamp/configs/02; do : ; done
}

step_3() {
    logbanner "Install kserve dependencies"
    until oc apply -f "${PROJECT_DIR}"/bootcamp/configs/03; do : ; done
}

step_4() {
    logbanner "Install RHOAI operator"
    until oc apply -f "${PROJECT_DIR}"/bootcamp/configs/04; do : ; done
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
    until oc apply -f "${PROJECT_DIR}"/bootcamp/configs/07; do : ; done
}

step_8() {
    logbanner "Run sample gpu application"
    until oc apply -f "${PROJECT_DIR}"/bootcamp/configs/08; do : ; done
}

step_9() {
    logbanner "Configure gpu dashboards"
    until oc apply -f "${PROJECT_DIR}"/bootcamp/configs/09; do : ; done
}

step_10() {
    logbanner "Configure gpu sharing method"
    until oc apply -f "${PROJECT_DIR}"/bootcamp/configs/10; do : ; done
}

step_11() {
    logbanner "Configure distributed workloads"
    until oc apply -f "${PROJECT_DIR}"/bootcamp/configs/11; do : ; done
}

step_12() {
    logbanner "Configure codeflare operator"
    until oc apply -f "${PROJECT_DIR}"/bootcamp/configs/12; do : ; done
}

step_13() {
    logbanner "Configure rhoai"
    until oc apply -f "${PROJECT_DIR}"/bootcamp/configs/13; do : ; done
}

setup(){

    if [ -z "$s" ]; then
        logerror "Step number is required"
        help
    fi

    create_log_file

    for (( i=1; i <= s; i++ ))
    do
        echo "Running step $i"
        eval "step_$i"
    done
}

setup