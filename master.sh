#!/bin/bash
curl -sSL https://get.daocloud.io/docker | sh
apt-get install -y htop git bridge-utils wget supervisor
wget http://git.oschina.net/lijianying10/k8s-install/raw/master/pac.tar
tar xf pac.tar
cp pac/* /bin/
rm -rf pac*

export FLANNEL_IFACE=eth0
export FLANNEL_IPMASQ=true
cat >> /etc/supervisor/supervisord.conf << EOF
[program:etcd]
command=etcd  --listen-client-urls=http://0.0.0.0:4001 --advertise-client-urls=http://0.0.0.0:4001 --data-dir=/var/etcd/data             
process_name=etcd
numprocs=1                    
directory=/tmp                
autostart=true                
autorestart=true

[program:flannel]
command=flanneld --ip-masq=true --iface=eth0
process_name=flannel
numprocs=1
directory=/tmp
autostart=true
autorestart=true
EOF

supervisorctl reload

etcdctl set /coreos.com/network/config '{ "Network": "10.1.0.0/16" }'
cat /run/flannel/subnet.env >> /etc/default/docker

echo DOCKER_OPTS=\"--bip=\${FLANNEL_SUBNET} --mtu=\${FLANNEL_MTU}\" >> /etc/default/docker

ifconfig docker0 down
sudo brctl delbr docker0
service docker restart

docker pull index.alauda.cn/googlecontainer/hyperkube-amd64:v1.2.4
docker pull index.alauda.cn/googlecontainer/pause:2.0
docker tag index.alauda.cn/googlecontainer/hyperkube-amd64:v1.2.4 gcr.io/google_containers/hyperkube-amd64:v1.2.4
docker tag index.alauda.cn/googlecontainer/pause:2.0 gcr.io/google_containers/pause:2.0
docker rmi index.alauda.cn/googlecontainer/hyperkube-amd64:v1.2.4
docker rmi index.alauda.cn/googlecontainer/pause:2.0

sudo docker run \
    --volume=/:/rootfs:ro \
    --volume=/sys:/sys:ro \
    --volume=/var/lib/docker/:/var/lib/docker:rw \
    --volume=/var/lib/kubelet/:/var/lib/kubelet:rw \
    --volume=/var/run:/var/run:rw \
    --net=host \
    --privileged=true \
    --pid=host \
    -d \
    gcr.io/google_containers/hyperkube-amd64:v1.2.4 \
    /hyperkube kubelet \
        --allow-privileged=true \
        --api-servers=http://localhost:8080 \
        --v=2 \
        --address=0.0.0.0 \
        --enable-server \
        --hostname-override=127.0.0.1 \
        --config=/etc/kubernetes/manifests-multi \
        --containerized \
        --cluster-dns=10.0.0.10 \
        --cluster-domain=cluster.local


