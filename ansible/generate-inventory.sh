#!/bin/bash
set -e

cd ../infra

MASTER_IP=$(terraform output -raw k8s_master_external_ip)
WORKER1_IP=$(terraform output -raw k8s_worker_1_external_ip)
WORKER2_IP=$(terraform output -raw k8s_worker_2_external_ip)

cd ../ansible

cat > inventory.ini <<EOL
[k8s_master]
k8s-master ansible_host=${MASTER_IP} ansible_user=ubuntu

[k8s_workers]
k8s-worker-1 ansible_host=${WORKER1_IP} ansible_user=ubuntu
k8s-worker-2 ansible_host=${WORKER2_IP} ansible_user=ubuntu

[k8s_cluster:children]
k8s_master
k8s_workers
EOL
