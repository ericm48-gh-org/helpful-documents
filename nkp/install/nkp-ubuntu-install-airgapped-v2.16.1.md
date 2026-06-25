# NKP [ 2.16.1 ] Ubuntu Air-gapped Install

Change Log:
- 23-Jan-2026: 
  - Added 2.16.1 Updates.

### JumpBox/Bastion Server Requirements (Minimum):
  - 4 Core CPU
  - 16G Memory
  - 250G Disk
  
### Upload the NKP Rocky or Ubuntu image to Prism Central

### Install NKP CLI

For the download-links below, you will need to navigate to the [Nutanix Portal](https://portal.nutanix.com/page/downloads?product=nkp) 
login, and receive temporary link to download.


Download CLI:
```
curl -L -o nkp_v2.16.1_linux_amd64.tar.gz 'https://nkp-cli-download-link'
```

Unzip CLI:
```
tar -xvf nkp_v2.16.1_linux_amd64.tar.gz
```

Download NKP Bundle
```
curl -L -o nkp-bundle_v2.16.1_linux_amd64.tar.gz 'https://nkp-bundle-download-link'
```

Unzip bundle:
```
tar -xvf nkp-bundle_v2.16.1_linux_amd64.tar.gz
```

Download NKP Air-Gapped Bundle:
```
curl -L -o nkp-air-gapped-bundle_v2.16.1_linux_amd64.tar.gz 'https://nkp-air-gapped-bundle-download-link'
```

Unzip Air-gapped Bundle:
```
tar -xvf nkp-air-gapped-bundle_v2.16.1_linux_amd64.tar.gz
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
sudo apt-get update
```

Install Docker:
```
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
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
cd nkp-v2.16.1/
```

Load bootstrap image:
```
docker load -i konvoy-bootstrap-image-v2.16.1.tar
```

Verify it exists:
```
docker images
```

Export Variables:
```
export NUTANIX_USER='pc-user'
export NUTANIX_PASSWORD='pc-password'
export IMAGE='nkp-image-name'
export SUBNET='name of subnet in PC that you will be deploying CP and worker nodes into'
export CLUSTER_NAME='nkp-cluster-name'
export CONTROLPLANE_VIP='single IP from subnet above that is outside of DHCP range'
export METALLB_IP_RANGE='range of IPs from subnet above that is outside of DHCP range, example 10.1.1.5-10.1.1.10'
export NUTANIX_ENDPOINT='https://prism-central-url:port'
export CLUSTER='pe-cluster-name'
export STORAGE_CONTAINER='storage-container-name'
export SSH_PUBLIC_KEY='path-to-ssh-pub-key'
```

Create Management Cluster:
```
nkp create cluster nutanix \
  --cluster-name=${CLUSTER_NAME} \
  --control-plane-prism-element-cluster=${CLUSTER} \
  --worker-prism-element-cluster=${CLUSTER} \
  --control-plane-subnets=${SUBNET} \
  --worker-subnets=${SUBNET} \
  --control-plane-endpoint-ip=${CONTROLPLANE_VIP} \
  --csi-storage-container=${STORAGE_CONTAINER} \
  --endpoint=${NUTANIX_ENDPOINT} \
  --control-plane-vm-image=${IMAGE} \
  --worker-vm-image=${IMAGE} \
  --kubernetes-service-load-balancer-ip-range=${METALLB_IP_RANGE} \
  --ssh-public-key-file=${SSH_PUBLIC_KEY} \
  --bundle='container-images/*.tar' \
  --insecure=true \
  --self-managed \
  --airgapped=true \
  -v5 2>&1 | tee -a ./nkp-create-mgmt-cluster-log.txt
```
