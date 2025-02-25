#!/bin/bash

set -e

if kubectl version --request-timeout=2s 2>&1; then
  echo "Kubernetes cluster already initialized"
else
  kubeadm init \
    --pod-network-cidr="192.168.0.0/16" \
    --control-plane-endpoint="node-01:6443"
  mkdir -p $HOME/.kube
  cp -i /etc/kubernetes/super-admin.conf $HOME/.kube/config
  chown $(id -u):$(id -g) $HOME/.kube/config
  kubectl apply -f /etc/kubernetes/calico.yaml
fi

echo "Success: master-init.sh completed"
