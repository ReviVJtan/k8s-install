#!/bin/bash
echo -e "\033[44;37;5m DOCKER INSTALL \033[0m"
curl -sSL https://get.daocloud.io/docker -o dockerinstall.sh
sh dockerinstall.sh
rm dockerinstall.sh
echo -e "\033[44;37;5m UTIL INSTALL \033[0m"
apt-get install -y htop git bridge-utils wget supervisor
echo -e "\033[44;37;5m Package Download \033[0m"
wget http://git.oschina.net/lijianying10/k8s-install/raw/master/pac.tar
echo -e "\033[44;37;5m Package install and clean\033[0m"
tar xf pac.tar
cp pac/* /bin/
rm -rf pac*


echo -e "\033[44;37;5m AUTO config supervisord \033[0m"
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
autorestart=true
EOF

echo -e "\033[44;37;5m Start ETCD flannel\033[0m"
supervisorctl reload

echo -e "\033[44;37;5m Waiting for etcd start \033[0m"
sleep 2

echo -e "\033[44;37;5m REG Network\033[0m"
etcdctl set /coreos.com/network/config '{ "Network": "10.1.0.0/16" }'

echo -e "\033[44;37;5m restart flannel \033[0m"
supervisorctl restart flannel


echo -e "\033[44;37;5m AUTO Config docker\033[0m"
cat /run/flannel/subnet.env >> /etc/default/docker

echo DOCKER_OPTS=\"--bip=\${FLANNEL_SUBNET} --mtu=\${FLANNEL_MTU}\" >> /etc/default/docker

echo -e "\033[44;37;5m Delete Docker0\033[0m"
ifconfig docker0 down
sudo brctl delbr docker0
service docker restart

echo -e "\033[44;37;5m Install K8S\033[0m"
docker pull index.alauda.cn/googlecontainer/hyperkube-amd64:v1.2.4
docker pull index.alauda.cn/googlecontainer/pause:2.0
docker tag index.alauda.cn/googlecontainer/hyperkube-amd64:v1.2.4 gcr.io/google_containers/hyperkube-amd64:v1.2.4
docker tag index.alauda.cn/googlecontainer/pause:2.0 gcr.io/google_containers/pause:2.0
docker rmi index.alauda.cn/googlecontainer/hyperkube-amd64:v1.2.4
docker rmi index.alauda.cn/googlecontainer/pause:2.0

echo -e "\033[44;37;5m RUN k8s\033[0m"
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


