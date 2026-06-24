#!/bin/bash


export NUTANIX_USER='pc-user'                                                                   # Ex: 'admin'
export NUTANIX_PASSWORD='pc-password'                                                           # Ex: 'thePassword1234'
export NUTANIX_IMAGE='nkp-image-name'                                                           # Ex: nkp-ubuntu-24.04-release-cis-1.34.1-20251206061851.qcow2
export NUTANIX_SUBNET='PC subnet to deploy ControlPlaneNodes and WorkLoadNodes into'.           # Ex: 'primary-PHX-POC236'
export NUTANIX_MGMT_CLUSTER_NAME='nkp-cluster-name'                                             # Ex: 'nkp-mgmt'. ** Note: This must match license-name.
export NUTANIX_CONTROLPLANE_VIP='single IP from subnet above that is outside of DHCP range.'    # Ex: '10.1.1.5'
export NUTANIX_METALLB_IP_RANGE='range of IPs from subnet above that is outside of DHCP range.' # Ex: '10.1.1.6-10.1.1.10'
export NUTANIX_ENDPOINT='https://prism-central-url:port'.                                       # Ex: 'https://x.x.x.7:9440'
export NUTANIX_PE_CLUSTER='pe-cluster-name'                                                     # Ex: 'PHX-POC236'
export NUTANIX_STORAGE_CONTAINER='storage-container-name'                                       # Ex: 'SelfServiceContainer'
export NUTANIX_SSH_PUBLIC_KEY='path-to-ssh-pub-key'                                             # Ex: '/home/nutanix/.ssh/id_ed25519.pub'
export NUTANIX_VERSION='target-nkp-version'                                                     # Ex: 'v2.17.1'

