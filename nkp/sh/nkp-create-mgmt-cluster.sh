#!/bin/bash

# Mgmt Cluster Full Size:

nkp create cluster nutanix \
  --cluster-name=${NUTANIX_MGMT_CLUSTER_NAME} \
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
  --bundle='/data/inet/nkp-v2.17.1/container-images/*.tar' \
  --insecure=true \
  --self-managed \
  --airgapped=true \
  -v5 2>&1 | tee -a /data/txt/nkp-create-mgmt-cluster-full-size-log.txt
