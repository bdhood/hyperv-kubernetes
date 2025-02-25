#!/bin/bash

expectedNodeCount="$1"
if [ -z "$expectedNodeCount" ]; then
  echo "Usage: $0 <expected-node-count>"
  exit 1
fi

# Check if kube config file exists
if [ ! -f "$HOME/.kube/config" ]; then
  echo "Kube config file not found"
  exit 1
fi

# Check if kube-apiserver is accessible
echo "Waiting for kube-apiserver to become available..."
success=false
set +e
for i in {1..30}; do
  if kubectl version --request-timeout=2s &>/dev/null; then
    echo "kube-apiserver is now available!"
    success=true
    break
  fi
  echo "Attempt $i/30 failed. Retrying in 2 second..."
  sleep 2
done
set -e

if [ "$success" = false ]; then
  echo "Failed: kubectl did not become available after 10 attempts."
  exit 1
fi


# Timeout variables
END_TIME=$((SECONDS + 120))
READY_NODE_FOUND=false

echo "Checking if nodes are ready..."

while [ $SECONDS -lt $END_TIME ]; do

  # Get nodes with 'Ready' status
  READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -w 'Ready' | wc -l)

  if [ "$READY_NODES" -ge "$expectedNodeCount" ]; then
    READY_NODE_FOUND=true
    break
  else 
    echo "$READY_NODES of $expectedNodeCount Nodes Ready"
    sleep 2
  fi
done

if [ "$READY_NODE_FOUND" = false ]; then
  echo "Timeout waiting for nodes to be ready"
  exit 1
fi

# Check if all pods are Ready with 2 minute timeout
echo "Checking if all pods are Ready..."

END_TIME=$((SECONDS + 120))
ALL_PODS_READY=false
while [ $SECONDS -lt $END_TIME ]; do
  # Get pods with 'Ready' status
  PODS_NOT_READY=$(kubectl get pods -o jsonpath='{range .items[?(@.status.containerStatuses[0].ready==false)]}{.metadata.name} ' -A)
  NOT_READY_POD_COUNT=$(echo $PODS_NOT_READY | wc -w)
  if [ "$NOT_READY_POD_COUNT" -eq 0 ]; then
    sleep 1
    PODS_NOT_READY=$(kubectl get pods -o jsonpath='{range .items[?(@.status.containerStatuses[0].ready==false)]}{.metadata.name} ' -A)
    NOT_READY_POD_COUNT=$(echo $PODS_NOT_READY | wc -w)
    if [ "$NOT_READY_POD_COUNT" -eq 0 ]; then
      ALL_PODS_READY=true
      break
    fi
  fi
  echo "$NOT_READY_POD_COUNT Pods not ready: ${PODS_NOT_READY}"
  sleep 2
done

if [ "$ALL_PODS_READY" = false ]; then
  echo "Timeout waiting for all pods to be Ready"
  exit 1
fi

echo "Success: Cluster is ready"
