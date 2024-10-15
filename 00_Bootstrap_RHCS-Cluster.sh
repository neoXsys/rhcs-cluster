#!/usr/bin/env bash

set -eux

# Enable repository for RHCS Cluster Deployment Tools
subscription-manager repos --enable=rhceph-7-tools-for-rhel-9-x86_64-rpms
dnf install cephadm-ansible cephadm -y

# Prepare all host for RHCS Cluster Deployment
cd /usr/share/cephadm-ansible
ansible-playbook 	-i /root/{{ plan }}.inventory cephadm-preflight.yml \
       			--extra-vars "ceph_origin=rhcs" \
			| tee -a /root/cephadm-ansible.log
cd /root

# Bootstrap RHCS Cluster
cephadm bootstrap 	--cluster-network {{ storage_backend_network_domain_cidr }} \
			--mon-ip {{ storage_frontend_network_domain_cidr_3 }}.{{ ip_offset }} \
			--registry-json /root/RedHatRegistryCredentials.json \
			--allow-fqdn-hostname \
			--initial-dashboard-user admin \
			--initial-dashboard-password redhat \
			--dashboard-password-noupdate \
			--cleanup-on-failure \
			--apply-spec /root/{{ plan }}-service-config-spec.yaml \
			| tee -a /root/cephadm.log

# Set default mon deamon count from 5 to 3
ceph orch apply mon  --placement=3

# Set default mgr deamon count from 2 To 3
ceph orch apply mgr  --placement=3

# Disable pool delete restrictions
ceph tell mon.\* injectargs '--mon-allow-pool-delete=true'

# Create & attach rbd pool with 2 replicaiton count rbd Block Service
ceph osd pool create rhodf-rbd-backend replicated --size 2 --autoscale_mode on
ceph osd pool application enable rhodf-rbd-backend rbd
rbd pool init -p rhodf-rbd-backend

# Create & attach rbd pool with 2 replication count for CephFS File Service
ceph osd pool create rhodf-cephfs-backend-meta-pool replicated --size 2 --autoscale_mode on
ceph osd pool create rhodf-cephfs-backend-data-pool replicated --size 2 --autoscale_mode on
ceph fs new rhodf-cephfs-backend rhodf-cephfs-backend-meta-pool rhodf-cephfs-backend-data-pool

grep "Cluster fsid\|URL\|User\|Password" /root/cephadm.log > /root/{{ plan }}-dashboard.cred

# Export RHCS Cluster json file for integration with RHOCP::RHODF
#python3 ./ceph-external-cluster-details-exporter.py	--rbd-data-pool-name rhodf-rbd-backend \
#							--rgw-endpoint rhcs-cluster-node-0.redhat.lab:8888 --rgw-skip-tls true 
#							--cephfs-filesystem-name rhodf-cephfs-backend \
#							--cephfs-metadata-pool-name rhodf-cephfs-backend-meta-pool \
#							--cephfs-data-pool-name rhodf-cephfs-backend-data-pool \
#							> ceph-external-cluster-details-exporter.json

exit 0
