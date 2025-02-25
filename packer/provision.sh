#!/bin/bash

set -e

echo "Starting Kubernetes cluster setup on Debian 12..."

# Step 1: Update system packages
echo "Updating system packages..."
apt update && apt upgrade -y

# Authorize SSH Key
mkdir -p /home/node/.ssh
chmod 700 /home/node/.ssh
cat /tmp/id_rsa.pub >> /home/node/.ssh/authorized_keys
chmod 600 /home/node/.ssh/authorized_keys
chown -R node:node /home/node/.ssh

# Step 2: Disable Swap
echo "Disabling swap..."
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# Step 3: Enable Kernel Modules and Set Sysctl Parameters
echo "Enabling kernel modules and setting sysctl parameters..."
modprobe overlay
modprobe br_netfilter

echo "br_netfilter" | tee /etc/modules-load.d/br_netfilter.conf
cat <<EOF | tee /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# Step 4: Install containerd
echo "Installing containerd..."
apt install -y apt-transport-https ca-certificates curl
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list
apt update
apt install -y containerd.io
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/^\(\s*\)SystemdCgroup *= *.*/\1SystemdCgroup = true/' /etc/containerd/config.toml

systemctl restart containerd

# Step 5: Install Kubernetes Components
echo "Adding Kubernetes APT repository..."
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
apt update
apt install -y kubeadm kubelet kubectl
apt-mark hold kubeadm kubelet kubectl

kubeadm config images pull
ctr --namespace k8s.io images pull docker.io/calico/cni:v3.25.0
ctr --namespace k8s.io images pull docker.io/calico/kube-controllers:v3.25.0
ctr --namespace k8s.io images pull docker.io/calico/node:v3.25.0
curl https://calico-v3-25.netlify.app/archive/v3.25/manifests/calico.yaml -o /etc/kubernetes/calico.yaml
