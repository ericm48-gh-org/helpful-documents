#!/bin/bash


export NUTANIX_USER='admin'
export NUTANIX_PASSWORD='thePassWord'

export NUTANIX_IMAGE='nkp-rocky-9.7-release-cis-1.34.3-20260316170119.qcow2'
export NUTANIX_SUBNET='primary-PHX-POC169'
export NUTANIX_MGMT_CLUSTER_NAME='nkp-mgmt-eric1'

export NUTANIX_CONTROLPLANE_VIP='10.42.169.75'
export NUTANIX_METALLB_IP_RANGE='10.42.169.76-10.42.169.78'

export NUTANIX_ENDPOINT='https://10.42.169.7:9440/'
export NUTANIX_PE_CLUSTER='PHX-POC169'

export NUTANIX_STORAGE_CONTAINER='SelfServiceContainer'
export NUTANIX_SSH_PUBLIC_KEY='/home/nutanix/.ssh/id_ed25519.pub'
export NUTANIX_VERSION='v2.17.1'
