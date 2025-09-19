#!/bin/bash

POD_NAME="spring-petclinic-rest"
CONTAINER_NAME="petclinic-rest-api"

wait_for_resize_to_finish() {
    local local_expected_mem=$1
    echo "Waiting for container '$CONTAINER_NAME' in pod '$POD_NAME' to have mem request of '$expected_mem'..."
     
    while true; do
        actual_mem=$(kubectl get pod "$POD_NAME" --output=json | jq -r "if .kind == \"Pod\" then . else .object end | .status.containerStatuses[]? | select(.name == \"$CONTAINER_NAME\") | .resources.requests.memory? // \"query_failed\"")
        if [ "$actual_mem" = "$local_expected_mem" ]; then
            echo "Watching pod '$POD_NAME' for container '$CONTAINER_NAME' to have mem request of '$local_expected_mem'."
            echo "---------------------------------------------------------"
            echo "Current Time: $(date)"
            echo "SUCCESS: Container resources are updated."
            echo "Pod: $POD_NAME"
            echo "Container: $CONTAINER_NAME"
            echo "Expected mem: $local_expected_mem"
            echo "Actual mem:   $actual_mem"
            echo "---------------------------------------------------------"
            break # Exit the 'while read' loop
        else
            echo "Watching pod '$POD_NAME' for container '$CONTAINER_NAME' to have mem request of '$local_expected_mem'."
            echo "Press [Ctrl+C] to stop..."
            echo "---------------------------------------------------------"
            echo "Current Time: $(date)"
            echo "STATUS: Waiting for resource update..."
            echo "Pod: $POD_NAME"
            echo "Container: $CONTAINER_NAME"
            echo "Expected mem: $local_expected_mem"
            echo "Actual mem:   $actual_mem (Waiting...)"
        fi
    done
    
    echo "Watch finished for $POD_NAME."
}

for i in {1..3} 
do

    echo "increasing mem 2Gi -> 3Gi"
    kubectl patch pod "$POD_NAME" \
    -p '{"spec":{"containers":[{"name":"'"$CONTAINER_NAME"'","resources":{"requests":{"memory":"3Gi"},"limits":{"memory":"3Gi"}}}]}}' --subresource=resize

    echo "waiting for resize to succeed"
    start_ns=$(date +%s%N)
    wait_for_resize_to_finish "3Gi"
    end_ns=$(date +%s%N)
    duration_ns=$((end_ns - start_ns))
    duration_ms=$((duration_ns / 1000000))
    echo "upscale resize succeeded after $duration_ms ms"

    echo "decreasing mem 3Gi -> 2Gi"
    kubectl patch pod "$POD_NAME" \
    -p '{"spec":{"containers":[{"name":"'"$CONTAINER_NAME"'","resources":{"requests":{"memory":"2Gi"},"limits":{"memory":"2Gi"}}}]}}' --subresource=resize

    echo "waiting for resize to succeed"
    start_ns=$(date +%s%N)
    wait_for_resize_to_finish "2Gi"
    end_ns=$(date +%s%N)
    duration_ns=$((end_ns - start_ns))
    duration_ms=$((duration_ns / 1000000))
    echo "downscale resize succeeded after $duration_ms ms"
done
