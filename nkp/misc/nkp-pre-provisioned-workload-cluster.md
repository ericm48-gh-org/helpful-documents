# Before You Begin / Assumed
- 1× Jumpbox (has kubectl access to NKP management cluster)
- 1x Existing NKP Management Cluster
- 7 preprovisioned servers: 3 control plane nodes, 4 worker nodes
  - IMPORTANT note: all 7 should have different hostnames set, and `/etc/hosts` file updated to reflect 127.0.0.1 to that hostname.
- If preprovision nodes are VM's, highly recommend adding an auto-grow script for LVM ([example](https://gist.github.com/ryandotclair/aad9a4a5c450a3ca6473935b6e4eb214))
- If network firewall is involved, ensure [proper ports](https://portal.nutanix.com/page/documents/ports-and-protocols?productType=Nutanix%20Kubernetes%20Platform) are open.
- Instructions assumes Ubuntu 24.04 LTS installed on all nodes
- Static IP addresses configured (for VIP and MetalLB)
- SSH access configured on all nodes
- Storage per worker (Excluding Boot Drive): 4× 120GB mounted filesystems (for Platform apps) + 2× 55GB raw block devices (if rook-ceph is to be used).

# Set Env Vars
Copy and paste these commands into your jumpbox:
```bash
# Set these on your operator machine
export CLUSTER_NAME="nkp-cluster"
export SSH_USERNAME="nutanix"
export CONTROL_PLANE_1_ADDRESS="<CP1_IP>"
export CONTROL_PLANE_2_ADDRESS="<CP2_IP>"
export CONTROL_PLANE_3_ADDRESS="<CP3_IP>"
export WORKER_1_ADDRESS="<W1_IP>"
export WORKER_2_ADDRESS="<W2_IP>"
export WORKER_3_ADDRESS="<W3_IP>"
export WORKER_4_ADDRESS="<W4_IP>"
export CONTROL_PLANE_VIP="<VIP_IP>"
export METALLB_START_IP="<START_IP>"
export METALLB_END_IP="<END_IP>"
export VIP_INTERFACE="<INTERFACE_NAME>"

# Verify all variables are set
echo "Cluster: $CLUSTER_NAME"
echo "SSH Username: $SSH_USERNAME"
echo "Control Planes: $CONTROL_PLANE_1_ADDRESS, $CONTROL_PLANE_2_ADDRESS, $CONTROL_PLANE_3_ADDRESS"
echo "Workers: $WORKER_1_ADDRESS, $WORKER_2_ADDRESS, $WORKER_3_ADDRESS, $WORKER_4_ADDRESS"
echo "VIP: $CONTROL_PLANE_VIP on $VIP_INTERFACE"
echo "MetalLB: $METALLB_START_IP-$METALLB_END_IP"
```

# Verify VIP Interface
```bash
# Run after setting environment variables in Step 3
for ip in $CONTROL_PLANE_1_ADDRESS $CONTROL_PLANE_2_ADDRESS $CONTROL_PLANE_3_ADDRESS; do
echo "Node $ip:"
ssh $SSH_USERNAME@$ip "ip -br link show | grep UP"
done

echo "All three must return same interface name, and match:"
echo $VIP_INTERFACE
```

# Copy the ssh keys over
```bash
# Copy SSH key to all 7 nodes
for NODE_IP in $CONTROL_PLANE_1_ADDRESS $CONTROL_PLANE_2_ADDRESS $CONTROL_PLANE_3_ADDRESS $WORKER_1_ADDRESS $WORKER_2_ADDRESS $WORKER_3_ADDRESS $WORKER_4_ADDRESS; do
ssh-copy-id -i ~/.ssh/id_rsa.pub nutanix@${NODE_IP}
done

# Verify passwordless SSH works
for NODE_IP in $CONTROL_PLANE_1_ADDRESS $CONTROL_PLANE_2_ADDRESS $CONTROL_PLANE_3_ADDRESS $WORKER_1_ADDRESS $WORKER_2_ADDRESS $WORKER_3_ADDRESS $WORKER_4_ADDRESS; do
echo "Testing $NODE_IP:"
ssh -o BatchMode=yes -o ConnectTimeout=5 nutanix@$NODE_IP "echo OK"
done
```

# Optional: Disable auto-update

Auto-updates can interfere with Kubernetes installation by locking package files or updating packages mid-deployment. This step ensures clean installations.
```
# Run on all nodes
for node in $CONTROL_PLANE_1_ADDRESS $CONTROL_PLANE_2_ADDRESS $CONTROL_PLANE_3_ADDRESS \
            $WORKER_1_ADDRESS $WORKER_2_ADDRESS $WORKER_3_ADDRESS $WORKER_4_ADDRESS; do
  echo "Disabling auto-updates on $node..."
  ssh $SSH_USERNAME@$node 'bash -s' <<'ENDSSH'
sudo systemctl stop unattended-upgrades apt-daily.timer apt-daily-upgrade.timer 2>/dev/null
sudo systemctl disable unattended-upgrades apt-daily.timer apt-daily-upgrade.timer 2>/dev/null
sudo killall apt apt-get 2>/dev/null || true
sudo rm -f /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock* 2>/dev/null
ENDSSH
done
```

# Configure all nodes
```bash
for NODE_IP in $CONTROL_PLANE_1_ADDRESS $CONTROL_PLANE_2_ADDRESS $CONTROL_PLANE_3_ADDRESS $WORKER_1_ADDRESS $WORKER_2_ADDRESS $WORKER_3_ADDRESS $WORKER_4_ADDRESS; do
echo "Configuring $NODE_IP..."
ssh $SSH_USERNAME@$NODE_IP 'bash -s' <<'ENDSSH'
if ! id nutanix &>/dev/null; then
sudo useradd -m -s /bin/bash nutanix
sudo usermod -aG sudo nutanix
echo "nutanix ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/nutanix
fi
sudo swapoff -a
sudo sed -i "/ swap / s/^/#/" /etc/fstab
sudo modprobe overlay
sudo modprobe br_netfilter
echo "overlay" | sudo tee /etc/modules-load.d/k8s.conf
echo "br_netfilter" | sudo tee -a /etc/modules-load.d/k8s.conf
echo "net.bridge.bridge-nf-call-iptables = 1" | sudo tee /etc/sysctl.d/k8s.conf
echo "net.bridge.bridge-nf-call-ip6tables = 1" | sudo tee -a /etc/sysctl.d/k8s.conf
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.d/k8s.conf
sudo sysctl --system &>/dev/null
sudo ufw disable
sudo apt-get remove -y kubelet kubeadm kubectl kubernetes-cni >/dev/null 2>&1 || true
sudo rm -f /etc/apt/sources.list.d/kubernetes*.list
sudo apt-get update >/dev/null
ENDSSH
echo "$NODE_IP configured"
done
```

# Configure Worker Node Storage
For Rook, Prometheus, Grafana, OpenCost and Loki. 
```bash
for WORKER_IP in $WORKER_1_ADDRESS $WORKER_2_ADDRESS $WORKER_3_ADDRESS $WORKER_4_ADDRESS; do
echo "Configuring storage on $WORKER_IP..."
ssh $SSH_USERNAME@$WORKER_IP 'bash -s' <<'ENDSSH'
sudo mkdir -p /mnt/disks/disk{1,2,3,4}
for dev in sdb sdc sdd sde; do
if ! sudo blkid /dev/$dev | grep -q ext4; then
sudo mkfs.ext4 -q /dev/$dev
fi
done
sudo mount /dev/sdb /mnt/disks/disk1 2>/dev/null || true
sudo mount /dev/sdc /mnt/disks/disk2 2>/dev/null || true
sudo mount /dev/sdd /mnt/disks/disk3 2>/dev/null || true
sudo mount /dev/sde /mnt/disks/disk4 2>/dev/null || true
grep -q "/dev/sdb" /etc/fstab || echo "/dev/sdb /mnt/disks/disk1 ext4 defaults 0 0" | sudo tee -a /etc/fstab
grep -q "/dev/sdc" /etc/fstab || echo "/dev/sdc /mnt/disks/disk2 ext4 defaults 0 0" | sudo tee -a /etc/fstab
grep -q "/dev/sdd" /etc/fstab || echo "/dev/sdd /mnt/disks/disk3 ext4 defaults 0 0" | sudo tee -a /etc/fstab
grep -q "/dev/sde" /etc/fstab || echo "/dev/sde /mnt/disks/disk4 ext4 defaults 0 0" | sudo tee -a /etc/fstab
ENDSSH
echo "$WORKER_IP storage configured"
done
```

# Veryify Connection
If not using Rook, no need for the 2x 55G raw devices.

```bash
# Verify storage on all workers
for ip in $WORKER_1_ADDRESS $WORKER_2_ADDRESS $WORKER_3_ADDRESS $WORKER_4_ADDRESS; do
echo "=== Worker $ip ==="
ssh $SSH_USERNAME@$ip 'df -h /mnt/disks/disk* 2>/dev/null; echo "---"; lsblk | grep "sd[fg]"'
done

# Expected: 4 mounted filesystems + 2 raw block devices per worker
```

# Workspace
Ensure you have a workspace to add this to.

```bash
kubectl get workspace
```

Use the namespace of the workspace to create the cluster in.
```bash
export WORKSPACE_NAMESPACE=<name>
```

# Create Inventory
```bash
cat <<EOF > preprovisioned_inventory.yaml
---
apiVersion: infrastructure.cluster.konvoy.d2iq.io/v1alpha1
kind: PreprovisionedInventory
metadata:
  name: $CLUSTER_NAME-control-plane
  namespace: $WORKSPACE_NAMESPACE
  labels:
    cluster.x-k8s.io/cluster-name: $CLUSTER_NAME
    clusterctl.cluster.x-k8s.io/move: ""
spec:
  hosts:
    - address: $CONTROL_PLANE_1_ADDRESS
    - address: $CONTROL_PLANE_2_ADDRESS
    - address: $CONTROL_PLANE_3_ADDRESS
  sshConfig:
    port: 22
    user: nutanix
    privateKeyRef:
      name: $CLUSTER_NAME-ssh-key
      namespace: $WORKSPACE_NAMESPACE
---
apiVersion: infrastructure.cluster.konvoy.d2iq.io/v1alpha1
kind: PreprovisionedInventory
metadata:
  name: $CLUSTER_NAME-md-0
  namespace: $WORKSPACE_NAMESPACE
  labels:
    cluster.x-k8s.io/cluster-name: $CLUSTER_NAME
    clusterctl.cluster.x-k8s.io/move: ""
spec:
  hosts:
    - address: $WORKER_1_ADDRESS
    - address: $WORKER_2_ADDRESS
    - address: $WORKER_3_ADDRESS
    - address: $WORKER_4_ADDRESS
  sshConfig:
    port: 22
    user: nutanix
    privateKeyRef:
      name: $CLUSTER_NAME-ssh-key
      namespace: $WORKSPACE_NAMESPACE
EOF

cat preprovisioned_inventory.yaml
```

# Workload Cluster
```bash
nkp create cluster preprovisioned \
  --cluster-name ${CLUSTER_NAME} \
  --control-plane-endpoint-host ${CONTROL_PLANE_VIP} \
  --virtual-ip-interface ${VIP_INTERFACE} \
  --pre-provisioned-inventory-file preprovisioned_inventory.yaml \
  --ssh-private-key-file ~/.ssh/id_rsa \
  --ssh-username nutanix \
  --timeout 60m \
  --namespace ${WORKSPACE_NAMESPACE}

# This takes 15-20 minutes
```
> Optional flags (but REQUIRED for airgap environments): 
> 
>  `--registry-mirror-url="https://<Registry>/<nkp-bundle>"`
>  
>  `--registry-mirror-username="<username>"`
>  
>  `--registry-mirror-password='<password>'`
>  
>  `--registry-mirror-cacert=<path/to/ca.crt>`


# Configure MLB
Once cluster is fully up, switch your kubectl context to the cluster (a .conf file should have been generated from above command in local directory), and configure the MLB.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default
  namespace: metallb-system
spec:
  addresses:
  - ${METALLB_START_IP}-${METALLB_END_IP}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
  - default
EOF

kubectl get ipaddresspools -n metallb-system
kubectl get l2advertisements -n metallb-system
```

# Optional Rook-Ceph steps

Grab the hostnames.
```bash
kubectl get nodes -o wide | grep -i worker
```

set hostnames
```bash
export NKP_HOSTNAME_1=blah1
export NKP_HOSTNAME_2=blah2
export NKP_HOSTNAME_3=blah3
export NKP_HOSTNAME_4=blah4

```

Apply
```bash
cat <<EOF | kubectl apply -f -
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-pv-sdf-worker-1
spec:
  capacity:
    storage: 55Gi
  volumeMode: Block
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: localvolumeprovisioner
  local:
    path: /dev/sdf
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - ${NKP_HOSTNAME_1}
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-pv-sdg-worker-1
spec:
  capacity:
    storage: 55Gi
  volumeMode: Block
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: localvolumeprovisioner
  local:
    path: /dev/sdg
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - ${NKP_HOSTNAME_1}
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-pv-sdf-worker-2
spec:
  capacity:
    storage: 55Gi
  volumeMode: Block
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: localvolumeprovisioner
  local:
    path: /dev/sdf
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - ${NKP_HOSTNAME_2}
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-pv-sdg-worker-2
spec:
  capacity:
    storage: 55Gi
  volumeMode: Block
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: localvolumeprovisioner
  local:
    path: /dev/sdg
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - ${NKP_HOSTNAME_2}
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-pv-sdf-worker-3
spec:
  capacity:
    storage: 55Gi
  volumeMode: Block
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: localvolumeprovisioner
  local:
    path: /dev/sdf
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - ${NKP_HOSTNAME_3}
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-pv-sdg-worker-3
spec:
  capacity:
    storage: 55Gi
  volumeMode: Block
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: localvolumeprovisioner
  local:
    path: /dev/sdg
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - ${NKP_HOSTNAME_3}
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-pv-sdf-worker-4
spec:
  capacity:
    storage: 55Gi
  volumeMode: Block
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: localvolumeprovisioner
  local:
    path: /dev/sdf
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - ${NKP_HOSTNAME_4}
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-pv-sdg-worker-4
spec:
  capacity:
    storage: 55Gi
  volumeMode: Block
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: localvolumeprovisioner
  local:
    path: /dev/sdg
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - ${NKP_HOSTNAME_4}
EOF
```

Verify.
```bash
kubectl get pv | grep -v block

# Should show 8 PVs with Status: Available
```

Enable rook-ceph / rook-ceph cluster in the NKP UI.

# Scaling
1. Ensure your context is pointed at the NKP Management Cluster
2. Prep the new node(s) with above steps
3. Edit the existing `PreprovisionedInventory` object, adding the IP address of the new node(s)
4. Find the machine deployment name (`kubectl get md -n $WORKSPACE_NAMESPACE`)
5. Scale the machine deployment (`kubectl scale md <machine-deployment-name> -n $WORKSPACE_NAMESPACE --replicas=6`)
    > In above example, node count was 5 and we are scaling to 6... use whatever number is applicable to your situation
7. Verify new node(s) come fully online (`watch kubectl machines -n $WORKSPACE_NAMESPACE` where PHASE = Pending/Provisioning/Running)

# Adding a new Node Pool
1. Ensure your context is pointed at the NKP Management Cluster
2. Prep the new node(s) with above steps
3. Create a new `PreprovisionedInventory` object, adding the IP address of the new node(s)
4. Trigger the onboarding of the node(s) with `nkp create nodepool <same-nodepool-name-in-inventory-object> -c $CLUSTER_NAME -n $WORKSPACE_NAMESPACE`, note that command also supports the mirror-registry flags. If you're ussing an internal registry (ex: airgap), you MUST use those flags.
5. Verify new node(s) come fully online (`watch kubectl machines -n $WORKSPACE_NAMESPACE` where PHASE = Pending/Provisioning/Running)

# Troubleshooting Tips
First identifying which node is causing issues
```bash
kubectl get machines -n $WORKSPACE_NAMESPACE
```
   > Healthy expected PHASE is `Running`. Status can get stuck on Provisioning or Pending (and even Deleting, typically due to missing `PreprovisionedInventory` object, add it back and should clear after a minute).

Check the logs of the provision job that's running. This should be a pod in your $WORKSPACE_NAMESPACE. Example:
```bash
kubectl logs $CLUSTER_NAME-control-plane-fzdkh-provision-jlb9h -n $WORKSPACE_NAMESPACE -f
```
   > Note: If you see logs stream by, it likely isn't finished. The moment it finishes (or you can ctrl+c to exit out), it should summarize if there are any failed tasks.

Another area you can check is the `cappp-controller-manager-xxx` pod in the `cappp-system` namespace. Example:
```bash
kubectl logs cappp-controller-manager-dfc49968b-plsgn -n cappp-system --since=1h -f
```
   > Note: your pod name will be different. Also, this reconciles on a loop, so wait for new logs to appear before "calling it". 

# Recommended Next Steps
- Get the kubeconfig file (`nkp get kubeconfig -c $CLUSTER_NAME -n $WORKSPACE_NAMESPACE`)
- [Nutanix CSI Driver install](https://gist.github.com/ryandotclair/b830dd32e48f3f1b05f982d835e45590) (Requires `nfs-utils` package on worker nodes for NFS and `open-iscsi` package for Block)