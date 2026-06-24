#!/bin/bash

# Workload Cluster Full Size:

nkp create cluster nutanix \
  --cluster-name=${NUTANIX_WORKLOAD_CLUSTER_NAME} \
  --control-plane-prism-element-cluster=${NUTANIX_PE_CLUSTER} \
  --worker-prism-element-cluster=${NUTANIX_PE_CLUSTER} \
  --control-plane-subnets=${NUTANIX_SUBNET} \
  --worker-subnets=${NUTANIX_SUBNET} \
  --control-plane-endpoint-ip=${NUTANIX_CONTROLPLANE_VIP} \
  --csi-storage-container=${NUTANIX_STORAGE_CONTAINER} \
  --endpoint=${NUTANIX_ENDPOINT} \
  --control-plane-vm-image=${NUTANIX_IMAGE} \
  --worker-vm-image=${NUTANIX_IMAGE} \
  --kubernetes-service-load-balancer-ip-range=${NUTANIX_METALLB_IP_RANGE} \
  --ssh-public-key-file=${NUTANIX_SSH_PUBLIC_KEY} \
  --insecure=true \
  -v5 2>&1 | tee -a /home/nutanix/nkp-create-workload-cluster-1-full-size-log2.txt &
