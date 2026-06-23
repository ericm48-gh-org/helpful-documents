# NKP [ 2.17.1 ] Ubuntu Air-gapped Install

Change Log:
- 16-Jun-2026:
  - Added 2.17.1 Updates.


### JumpBox/Bastion Server Requirements (Minimum):
  - 4 Core CPU
  - 16G Memory
  - 250G Disk

### Upload the NKP Rocky or Ubuntu image to Prism Central

### Install NKP CLI

For the download-links below, you will need to navigate to the [Nutanix Portal](https://portal.nutanix.com/page/downloads?product=nkp) 
login, and receive temporary link to download.


Setup Staging Directory [ /data/inet ]:
```
mkdir -p /data/inet
cd /data/inet
```

Download CLI:
```
curl -L -o nkp_v2.17.1_linux_amd64.tar.gz 'https://nkp-cli-download-link'
```

Unzip CLI:
```
tar -xvf nkp_v2.17.1_linux_amd64.tar.gz
```

Download NKP Bundle
```
curl -L -o nkp-bundle_v2.17.1_linux_amd64.tar.gz 'https://nkp-bundle-download-link'
```

Unzip bundle:
```
tar -xvf nkp-bundle_v2.17.1_linux_amd64.tar.gz
```

Download NKP Air-Gapped Bundle:
```
curl -L -o nkp-air-gapped-bundle_v2.17.1_linux_amd64.tar.gz 'https://nkp-air-gapped-bundle-download-link'
```

Unzip Air-gapped Bundle:
```
tar -xvf nkp-air-gapped-bundle_v2.17.1_linux_amd64.tar.gz
```

### Install Docker

Add Docker's official GPG key:
```
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
```

Set permissions:
```
sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

Add apt repo:
```
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

Update:
```
sudo apt-get -y update
```

Install Docker:
```
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Handle Groups:
```
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker
```

Enable Docker:
```
sudo systemctl enable docker.service
sudo systemctl enable docker.socket
sudo systemctl enable containerd.service
```

Start Docker:
```
sudo systemctl start docker.service
sudo systemctl start docker.socket
sudo systemctl start containerd.service
```

### Install Kubectl

Download:
```
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
```

Install:
```
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

Check Version:
```
kubectl version --client
```
### Install Kind cli

Download:
```
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.30.0/kind-linux-amd64
```

Set Permissions:
```
sudo chmod +x /usr/local/bin/kind
```

### Generate ssh key:
```
ssh-keygen
```

### Deploy NKP Management Cluster

Navigate to folder:
```
cd /data/inet/nkp-2.17.1/
```

Load bootstrap image:
```
docker load -i /data/inet/nkp-2.17.1/konvoy-bootstrap-image-v2.17.1.tar
```

Verify it exists:
```
docker images
```

Export Variables:
```
export NUTANIX_USER='pc-user'                                                                  # Ex: 'admin'
export NUTANIX_PASSWORD='pc-password'                                                          # Ex: 'thePassword1234'
export NUTANIX_IMAGE='nkp-image-name'                                                          # Ex: nkp-ubuntu-24.04-release-cis-1.34.1-20251206061851.qcow2
export NUTANIX_SUBNET='PC subnet to deploy ControlPlaneNodes and WorkLoadNodes into'.          # Ex: 'primary-PHX-POC236'
export NUTANIX_CLUSTER_NAME='nkp-cluster-name'                                                 # Ex: 'nkp-mgmt'. ** Note: This must match license-name.
export NUTANIX_CONTROLPLANE_VIP='single IP from subnet above that is outside of DHCP range'.   # Ex: '10.1.1.5'
export NUTANIX_METALLB_IP_RANGE='range of IPs from subnet above that is outside of DHCP range. # Ex: '10.1.1.6-10.1.1.10'
export NUTANIX_ENDPOINT='https://prism-central-url:port'.                                      # Ex: 'https://x.x.x.7:9440'
export NUTANIX_PE_CLUSTER='pe-cluster-name'                                                    # Ex: 'PHX-POC236'
export NUTANIX_STORAGE_CONTAINER='storage-container-name'                                      # Ex: 'SelfServiceContainer'
export NUTANIX_SSH_PUBLIC_KEY='path-to-ssh-pub-key'                                            # Ex: '/home/ubuntu/.ssh/id_ed25519.pub'
export NUTANIX_VERSION='target-nkp-version'                                                    # Ex: 'v2.17.1'
```

Create Management Cluster:
```
nkp create cluster nutanix \
  --cluster-name=${NUTANIX_CLUSTER_NAME} \
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
  --bundle='container-images/*.tar' \
  --insecure=true \
  --self-managed \
  --airgapped=true \
  -v5 2>&1 | tee -a ./nkp-create-mgmt-cluster-log.txt
```

Once Management Cluster is created successfully, extract the base-credential:
```
nkp get dashboard --kubeconfig='./nkp.conf'
```

