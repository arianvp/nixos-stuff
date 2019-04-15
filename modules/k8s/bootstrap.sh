#!/bin/sh
mkdir -p certs

# TODO set --apiserver-advertise-addres to whatever nixos tells us

# For this, make sure hostname=apiservername because CA is generated for domain
kubeadm init phase certs all --cert-dir=$PWD/certs

# I am not sure about this one?
# kubeadm init phase kubeconfig admin

# This one we should configure through the nixos module instead, I Think
# kubeadm init phase kubeconfig kubelet

kubeadm init phase kubeconfig controller-manager
kubeadm init phase kubeconfig scheduler

# Generates all static Pod manifest files necessary to establish the control plane
# TODO in the future move these to k8s?
# TODO: make sure /etc/kubernetes/manifests is writeable and not a symlink to /nix/store
kubeadm init phase control-plane  all
kubeadm init phase etcd local

kubeadm init phase upload-config all
kubeadm init phase upload-certs   all
kubeadm init phase  mark-control-plane
kubeadm init phase bootstrap-token
kubeadm init phase addon coredns
kubeadm init phase addon kube-proxy
