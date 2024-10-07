#!/bin/bash

retry(){
    echo "Running:" "${@}"
    echo "Retry times: 12"
    echo "Delay: 20 sec"
    local n=1
    local max=12
    local delay=20
    # until "${@}" 1>&2
    until "${@}"
    do
        if [[ $n -lt $max ]]; then
            ((n++))
            echo "Retry after $delay sec"
            sleep $delay
        else
            echo "Failed after $n attempts."
            return 1
        fi
    done
    echo "[OK]"
}

apply_kustomize(){
    if [ ! -f "$1/kustomization.yaml" ]; then
        echo "'kustomization.yaml' not found in $1"
        return 1
    fi

    retry oc apply -k "$1" 2>/dev/null
}

apply_config(){
    retry oc apply -f "$1" 2>/dev/null
}