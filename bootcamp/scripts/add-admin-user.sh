#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
PARENT_DIR="${SCRIPT_DIR%/*}"
source ${PARENT_DIR}/scripts/logging.sh
source ${PARENT_DIR}/scripts/util.sh

USERNAME=$1
PASSWORD=$2
LOG_FILE="add-admin-user_$(date +"%Y%m%d:%H%M").log"

RESOURCE_FILE="$PARENT_DIR/configs/01/htpasswd-cr.yaml"
PWD_FILENAME="users.htpasswd"
SECRET_NAME="htpasswd-secret"


logbanner "Begin adding administrative user"
loginfo "Log file: '$LOG_FILE'"

create_htpasswd_file() {
    loginfo "Create htpasswd file for user $USERNAME"
    htpasswd -c -B -b scratch/$PWD_FILENAME $USERNAME $PASSWORD 2>&1 | tee -a $LOG_FILE
}

create_secret(){
    if oc get secrets -A | grep $SECRET_NAME; then
        logwarning "Secret $SECRET_NAME already exists, update secret"
        oc create secret generic $SECRET_NAME --from-file=htpasswd=scratch/$PWD_FILENAME --dry-run=client -o yaml -n openshift-config | oc replace -f - 2>&1 | tee -a $LOG_FILE
    else
        loginfo "Create secret ${SECRET_NAME}"
        oc create secret generic $SECRET_NAME --from-file=htpasswd=scratch/$PWD_FILENAME -n openshift-config 2>&1 | tee -a $LOG_FILE
    fi
}

apply_htpasswd_provider(){
    loginfo "Add htpasswd provider"
    oc apply -f $RESOURCE_FILE 2>&1 | tee -a $LOG_FILE
}

apply_cluster_admin(){
    loginfo "Add cluster-admin to user $USERNAME"
    oc adm policy add-cluster-role-to-user cluster-admin $USERNAME 2>&1 | tee -a $LOG_FILE
}

notify_user_creation(){
    logwarning "User won't be created till you run 'oc login -u <username>'" 
}

validate_user(){
    loginfo "Validate user $USERNAME"
    if oc get user | grep $USERNAME; then
        loginfo "$USERNAME created successfully"
    else
        logerror "User $USERNAME not created"
    fi
}

create_htpasswd_file
create_secret
apply_htpasswd_provider
apply_cluster_admin
notify_user_creation

