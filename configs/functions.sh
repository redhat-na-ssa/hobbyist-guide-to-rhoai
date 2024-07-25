#!/bin/bash

ocp_control_nodes_not_schedulable(){
  oc patch schedulers.config.openshift.io/cluster --type merge --patch '{"spec":{"mastersSchedulable": false}}'
}

ocp_control_nodes_schedulable(){
  oc patch schedulers.config.openshift.io/cluster --type merge --patch '{"spec":{"mastersSchedulable": true}}'
}

ocp_gpu_taint_nodes(){
  oc adm taint node -l node-role.kubernetes.io/gpu nvidia.com/gpu=:NoSchedule --overwrite
  oc adm drain -l node-role.kubernetes.io/gpu --ignore-daemonsets --delete-emptydir-data
  oc adm uncordon -l node-role.kubernetes.io/gpu
}

ocp_gpu_untaint_nodes(){
  oc adm taint node -l node-role.kubernetes.io/gpu nvidia.com/gpu=:NoSchedule-
}

ocp_gpu_label_nodes_from_nfd(){
  oc label node -l nvidia.com/gpu.machine node-role.kubernetes.io/gpu=''
}

ocp_aws_clone_worker_machineset(){
  [ -z "${1}" ] && \
  echo "
    usage: ocp_aws_clone_worker_machineset < instance type, default g4dn.4xlarge > < machine set name >
  "

  INSTANCE_TYPE=${1:-g4dn.4xlarge}
  SHORT_NAME=${2:-${INSTANCE_TYPE%.*}}

  MACHINE_SET_NAME=$(oc -n openshift-machine-api get machinesets.machine.openshift.io -o name | grep "${SHORT_NAME}" | head -n1)
  MACHINE_SET_WORKER=$(oc -n openshift-machine-api get machinesets.machine.openshift.io -o name | grep worker | head -n1)

  # check for an existing instance machine set
  if [ -n "${MACHINE_SET_NAME}" ]; then
    echo "Exists: machineset - ${MACHINE_SET_NAME}"
  else
    echo "Creating: machineset - ${SHORT_NAME}"
    oc -n openshift-machine-api \
      get "${MACHINE_SET_WORKER}" -o yaml | \
        sed '/machine/ s/-worker/-'"${INSTANCE_TYPE}"'/g
          /^  name:/ s/cluster-.*/'"${SHORT_NAME}"'/g
          /name/ s/-worker/-'"${SHORT_NAME}"'/g
          s/instanceType.*/instanceType: '"${INSTANCE_TYPE}"'/
          /cluster-api-autoscaler/d
          s/replicas.*/replicas: 0/' | \
      oc apply -f -
  fi

  # cosmetic pretty
  oc -n openshift-machine-api \
    patch "${MACHINE_SET_NAME}" \
    --type=merge --patch '{"spec":{"template":{"spec":{"metadata":{"labels":{"node-role.kubernetes.io/'"${SHORT_NAME}"'":""}}}}}}'
}

ocp_aws_cluster_autoscaling(){
  oc apply -k https://github.com/redhat-na-ssa/demo-ai-gitops-catalog/components/configs/cluster/autoscale/overlays/gpus-accelerator-label?ref=v0.04

  ocp_aws_create_gpu_machineset g4dn.4xlarge
  ocp_create_machineset_autoscale 0 3

  # scale workers to 1
  WORKER_MS="$(oc -n openshift-machine-api get machineset -o name | grep worker)"
  ocp_scale_machineset 1 "${WORKER_MS}"

  ocp_control_nodes_not_schedulable
}

ocp_aws_create_gpu_machineset(){
  # https://aws.amazon.com/ec2/instance-types/g4
  # single gpu: g4dn.{2,4,8,16}xlarge
  # multi gpu:  g4dn.12xlarge
  # practical:  g4ad.4xlarge
  # a100 (MIG): p4d.24xlarge
  # h100 (MIG): p5.48xlarge

  # https://aws.amazon.com/ec2/instance-types/dl1
  # 8 x gaudi:  dl1.24xlarge

  INSTANCE_TYPE=${1:-g4dn.4xlarge}

  ocp_aws_clone_worker_machineset "${INSTANCE_TYPE}"

  MACHINE_SET_TYPE=$(oc -n openshift-machine-api get machinesets.machine.openshift.io -o name | grep "${INSTANCE_TYPE%.*}" | head -n1)

  echo "Patching: ${MACHINE_SET_TYPE}"

  # cosmetic
  oc -n openshift-machine-api \
    patch "${MACHINE_SET_TYPE}" \
    --type=merge --patch '{"spec":{"template":{"spec":{"metadata":{"labels":{"node-role.kubernetes.io/gpu":""}}}}}}'

  # taint nodes for gpu-only workloads
  oc -n openshift-machine-api \
    patch "${MACHINE_SET_TYPE}" \
    --type=merge --patch '{"spec":{"template":{"spec":{"taints":[{"key":"nvidia.com/gpu","value":"","effect":"NoSchedule"}]}}}}'
  
  # should use the default profile
  # oc -n openshift-machine-api \
  #   patch "${MACHINE_SET_TYPE}" \
  #   --type=merge --patch '{"spec":{"template":{"spec":{"metadata":{"labels":{"nvidia.com/device-plugin.config":"no-time-sliced"}}}}}}'

  # should help auto provisioner
  oc -n openshift-machine-api \
    patch "${MACHINE_SET_TYPE}" \
    --type=merge --patch '{"spec":{"template":{"spec":{"metadata":{"labels":{"cluster-api/accelerator":"nvidia-gpu"}}}}}}'
  
  oc -n openshift-machine-api \
    patch "${MACHINE_SET_TYPE}" \
    --type=merge --patch '{"metadata":{"labels":{"cluster-api/accelerator":"nvidia-gpu"}}}'
  
  oc -n openshift-machine-api \
    patch "${MACHINE_SET_TYPE}" \
    --type=merge --patch '{"spec":{"template":{"spec":{"providerSpec":{"value":{"instanceType":"'"${INSTANCE_TYPE}"'"}}}}}}'
}

ocp_create_machineset_autoscale(){
  MACHINE_MIN=${1:-0}
  MACHINE_MAX=${2:-4}
  MACHINE_SETS=${3:-$(oc -n openshift-machine-api get machinesets.machine.openshift.io -o name | sed 's@.*/@@' )}

  for set in ${MACHINE_SETS}
  do
cat << YAML | oc apply -f -
apiVersion: "autoscaling.openshift.io/v1beta1"
kind: "MachineAutoscaler"
metadata:
  name: "${set}"
  namespace: "openshift-machine-api"
spec:
  minReplicas: ${MACHINE_MIN}
  maxReplicas: ${MACHINE_MAX}
  scaleTargetRef:
    apiVersion: machine.openshift.io/v1beta1
    kind: MachineSet
    name: "${set}"
YAML
  done
}

ocp_scale_machineset(){
  REPLICAS=${1:-1}
  MACHINE_SETS=${2:-$(oc -n openshift-machine-api get machineset -o name)}

  # scale workers
  echo "${MACHINE_SETS}" | \
    xargs \
      oc -n openshift-machine-api \
      scale --replicas="${REPLICAS}"
}
