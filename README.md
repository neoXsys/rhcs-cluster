###  RHCS Cluster On KVM Infra Via kcli - Hybrid Infra Management Tool
![RHCS Cluster Colocated Cephadm Deployment Architecture HLD](https://github.com/neoXsys/rhcs-cluster/blob/75144192c3c88507cde297cd5a34fdf0759e5538/RHCS-Cluster-Colocated-Cephadm-Deployment-Architecture-HLD.png)
#### Baremetal Node Information | Hypervisor Host (TESTED):
* Dell R440 | 40 Core Cpu | 256 GB Ram
* HOST OS: RHEL 9.4
* Red Hat CEPH Storage (RHCS)
* Reference: 
  * <https://github.com/karmab/kcli>
  * <https://kcli.readthedocs.io/en/latest/>
* **NOTE: Tested using root permisions only.**
* **NOTE: kcli plan can be used for other cloud infra provider**
#### Register Baremetal RHEL Node:
```
subscription-manager register --username _RHN_USERNAME_
```
#### Update the RHEL node with latest updates, basic utility packages & ssh key gneration: 
```
dnf update -y
dnf install tmux mc podman-docker bash-completion vim jq tar git yum-utils  -y
ssh-keygen
```
#### Install libvirt (KVM Virtualization):
```
yum -y install libvirt libvirt-daemon-driver-qemu qemu-kvm
usermod -aG qemu,libvirt $(id -un)
newgrp libvirt
systemctl enable --now libvirtd
systemctl status libvirtd
```
#### Install Local NTP Server:
```
dnf install chrony -y
```
#### Configure NTP Server (chrony):
```
cat <<EOF> /etc/chrony.conf
server 0.rhel.pool.ntp.org iburst
server 1.rhel.pool.ntp.org iburst
server 2.rhel.pool.ntp.org iburst
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
keyfile /etc/chrony.keys
leapsectz right/UTC
logdir /var/log/chrony
bindcmdaddress ::
allow all
EOF
```
#### Enable Local NTP Service:
```
systemctl enable --now chronyd
systemctl status chronyd
chronyc tracking
```
#### Install [kcli](https://kcli.readthedocs.io/en/latest/) - Hybrid Infra Management Toolchain:
```
ssh-keygen  # Ignore if already created root SSH key pair
dnf -y copr enable karmab/kcli
dnf -y install kcli
```
#### Check if reboot requires or not
```
needs-restarting -r
```
- **NOTE: # More information: https://access.redhat.com/solutions/27943**

#### Configure default pool for kcli:
```
kcli create pool -p /var/lib/libvirt/images default 
```
#### Create RHCS Cluster - Colocated
```
kcli create plan -f rhcs-cluster.redhat.lab.kcli -P "plan=rhcs-cluster" -P "nodes=4" -P "ip_offset=10" \
		 -P image_url="_RHEL_IMAGE_URL_" \
		 -P  rhnuser="_RHN_USER_" \
		 -P rhnpassword="_RHN_PASSWORD_"
```
#### After Few Minutes Later, Access RHCS Cluster Dashboard Credentials
- **NOTE: By Default node-0 is Bootstrap & Admin Node**
```
kcli ssh rhcs-cluster-node-0.redhat.lab 'sudo cat /root/rhcs-cluster-dashboard.cred'
Cluster fsid: bb1b27be-871b-11ef-9a25-525400456f2b
             URL: https://rhcs-cluster-node-0.redhat.lab:8443/
            User: admin
        Password: redhat
```
#### Example Expected Output From Hypervisor Host
```
# kcli list pools && kcli list images && kcli list network && kcli list dns redhat.lab && kcli list vms
+--------------+--------------------------------------+
| Pool         |                 Path                 |
+--------------+--------------------------------------+
| default      |       /var/lib/libvirt/images        |
| rhcs-cluster | /var/lib/libvirt/images/rhcs-cluster |
+--------------+--------------------------------------+
+--------------------------------------+
| Images                               |
+--------------------------------------+
| /var/lib/libvirt/images/rhcs-cluster |
| /var/lib/libvirt/images/rhel94       |
+--------------------------------------+
Listing Networks...
+---------------+--------+------------------+-------+------------+------+
| Network       |  Type  |       Cidr       |  Dhcp |   Domain   | Mode |
+---------------+--------+------------------+-------+------------+------+
| storage       | routed |  172.18.0.0/24   | False | redhat.lab | nat  |
| storageMgmt   | routed |  172.20.0.0/24   | False | redhat.lab | nat  |
+---------------+--------+------------------+-------+------------+------+
+--------------------------------+------+-----+-----------------------+
|             Entry              | Type | TTL |          Data         |
+--------------------------------+------+-----+-----------------------+
|  dns-rhcs-cluster.redhat.lab   |  A   |  0  |  172.18.0.1 (storage) |
| rhcs-cluster-node-0.redhat.lab |  A   |  0  | 172.18.0.10 (storage) |
| rhcs-cluster-node-1.redhat.lab |  A   |  0  | 172.18.0.11 (storage) |
| rhcs-cluster-node-2.redhat.lab |  A   |  0  | 172.18.0.12 (storage) |
| rhcs-cluster-node-3.redhat.lab |  A   |  0  | 172.18.0.13 (storage) |
+--------------------------------+------+-----+-----------------------+
+--------------------------------+--------+-------------+--------+--------------+-------------------------------+
|              Name              | Status |      Ip     | Source |     Plan     |            Profile            |
+--------------------------------+--------+-------------+--------+--------------+-------------------------------+
| rhcs-cluster-node-0.redhat.lab |   up   | 172.18.0.10 | rhel94 | rhcs-cluster | rhel94-rhcs-cluster-c4m16d100 |
| rhcs-cluster-node-1.redhat.lab |   up   | 172.18.0.11 | rhel94 | rhcs-cluster | rhel94-rhcs-cluster-c4m16d100 |
| rhcs-cluster-node-2.redhat.lab |   up   | 172.18.0.12 | rhel94 | rhcs-cluster | rhel94-rhcs-cluster-c4m16d100 |
| rhcs-cluster-node-3.redhat.lab |   up   | 172.18.0.13 | rhel94 | rhcs-cluster | rhel94-rhcs-cluster-c4m16d100 |
+--------------------------------+--------+-------------+--------+--------------+-------------------------------+
```
### Post Deployment RHCS Service Layout
```
NAME                       PORTS        RUNNING  REFRESHED  AGE  PLACEMENT
alertmanager               ?:9093,9094      1/1  5s ago     89m  count:1
ceph-exporter                               4/4  7m ago     89m  *
crash                                       4/4  7m ago     89m  *
grafana                    ?:3000           1/1  5s ago     89m  count:1
mds.rhodf-cephfs-backend                    2/2  7m ago     88m  count:2;label:mds
mgr                                         3/3  6m ago     88m  count:3
mon                                         3/3  7m ago     88m  count:3
node-exporter              ?:9100           4/4  7m ago     89m  *
node-proxy                                  0/0  -          83m  *
osd.all-available-devices                     8  7m ago     88m  label:osd
prometheus                 ?:9095           1/1  5s ago     89m  count:1
rgw.rhodf-rgw-backend      ?:8888           4/4  6m ago     85m  count-per-host:2;label:rgw
```
![RHCS Cluster 4 VM(s) / Node(s) Colocated Deployment Example With Service Layout](https://github.com/neoXsys/rhcs-cluster/blob/a8f86047533c5623a93cf040e94064c652e3535b/RHCS-Cluster-4-Nodes-Colocated-Example-Architecture.png)
### Explore kcli plan for more customization
REF: https://docs.redhat.com/en/documentation/red_hat_ceph_storage/7
