#!/bin/bash

POD_NAME="spring-petclinic-rest"
CONTAINER_NAME="petclinic-rest-api"

wait_for_resize_to_finish() {
    local local_expected_cpu=$1
    echo "Waiting for container '$CONTAINER_NAME' in pod '$POD_NAME' to have CPU request of '$expected_cpu'..."
     
    while true; do
        actual_cpu=$(kubectl get pod "$POD_NAME" --output=json | jq -r "if .kind == \"Pod\" then . else .object end | .status.containerStatuses[]? | select(.name == \"$CONTAINER_NAME\") | .resources.requests.cpu? // \"query_failed\"")
        if [ "$actual_cpu" = "$local_expected_cpu" ]; then
            echo "Watching pod '$POD_NAME' for container '$CONTAINER_NAME' to have CPU request of '$local_expected_cpu'."
            echo "---------------------------------------------------------"
            echo "Current Time: $(date)"
            echo "SUCCESS: Container resources are updated."
            echo "Pod: $POD_NAME"
            echo "Container: $CONTAINER_NAME"
            echo "Expected CPU: $local_expected_cpu"
            echo "Actual CPU:   $actual_cpu"
            echo "---------------------------------------------------------"
            break # Exit the 'while read' loop
        else
            echo "Watching pod '$POD_NAME' for container '$CONTAINER_NAME' to have CPU request of '$local_expected_cpu'."
            echo "Press [Ctrl+C] to stop..."
            echo "---------------------------------------------------------"
            echo "Current Time: $(date)"
            echo "STATUS: Waiting for resource update..."
            echo "Pod: $POD_NAME"
            echo "Container: $CONTAINER_NAME"
            echo "Expected CPU: $local_expected_cpu"
            echo "Actual CPU:   $actual_cpu (Waiting...)"
        fi
    done
    
    echo "Watch finished for $POD_NAME."
}

for i in {1..3} 
do

    echo "increasing CPU 1000m -> 1150m"
    kubectl patch pod "$POD_NAME" \
    -p '{"spec":{"containers":[{"name":"'"$CONTAINER_NAME"'","resources":{"requests":{"cpu":"1150m"},"limits":{"cpu":"1150m"}}}]}}' --subresource=resize

    echo "waiting for resize to succeed"
    start_ns=$(date +%s%N)
    wait_for_resize_to_finish "1150m"
    end_ns=$(date +%s%N)
    duration_ns=$((end_ns - start_ns))
    duration_ms=$((duration_ns / 1000000))
    echo "upscale resize succeeded after $duration_ms ms"

    echo "decreasing CPU 1150m -> 1000m"
    kubectl patch pod "$POD_NAME" \
    -p '{"spec":{"containers":[{"name":"'"$CONTAINER_NAME"'","resources":{"requests":{"cpu":"1000m"},"limits":{"cpu":"1000m"}}}]}}' --subresource=resize

    echo "waiting for resize to succeed"
    start_ns=$(date +%s%N)
    wait_for_resize_to_finish "1"
    end_ns=$(date +%s%N)
    duration_ns=$((end_ns - start_ns))
    duration_ms=$((duration_ns / 1000000))
    echo "downscale resize succeeded after $duration_ms ms"
done
