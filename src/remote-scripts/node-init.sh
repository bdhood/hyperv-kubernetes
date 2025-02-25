#!/bin/bash

set -e 

function usage() {
  echo "Usage: $0 <hostname> <total-nodes>"
  exit 1
}

if [ "$#" -lt 2 ]; then
  echo "Error: Missing arguments"
  usage
fi

nodename="$1"
node_count="$2"

# validate cli args

if ! [[ "$node_count" =~ ^[0-9]+$ ]]; then
  echo "$nodename: Error: <total-nodes> should be a number"
  usage
fi

if [ "$node_count" -lt 1 ]; then
  echo "$nodename: Error: <total-nodes> should be greater than 0"
  usage
fi

if [ -z "$nodename" ]; then
  echo "$nodename: Error: <hostname> should not be empty"
  usage
fi

# set hostname

if [ "$(hostname)" == "$nodename" ]; then
  echo "$nodename: Hostname already set to $nodename"
else
  hostnamectl set-hostname "$nodename"
  if [ "$(hostname)" == "$nodename" ]; then
    echo "$nodename: Hostname set to $nodename"
  else
    echo "$nodename: Error: Failed to set hostname to $nodename, current hostname: $(hostname)"
    exit 1
  fi
fi

# generate array of node names, node-01, node-02, ..., node-n
node_names=()
for node in $(seq -f "node-%02g" 1 $node_count); do
  echo "$nodename: Testing ping $nodename -> $node"
  ping -c 1 -W 5 $node > /dev/null
done

echo "Success: node-init.sh completed"
