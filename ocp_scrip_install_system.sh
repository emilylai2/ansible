#!/bin/bash

DASH_LINE=$(printf "%0.s-" {1..90})
EQUAL_LINE=$(printf "%0.s=" {1..90})

#Variant>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
OCP_PACKAGE_PATH="/root"
OCP_VERSION="4.12.30"
OCP_CLUSTER_NAME="ocp"
BASE_DOMAIN="osys.com"
OCP_INSTALL_PATH="/opt/install"
CONNECTION_NAME="ens192"
ARPA="9.4.10"
DNS_IP="10.4.9.50"
BASTION_IP="10.4.9.50"
LOADBLANCER_IP="10.4.9.50"
BOOTSTRAP_IP="10.4.9.51"
MASTER0_IP="10.4.9.52"
MASTER1_IP="10.4.9.53"
MASTER2_IP="10.4.9.54"
WORKER0_IP="10.4.9.55"
WORKER1_IP="10.4.9.56"

#Config firewalld & SELinux disable>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
systemctl stop firewalld
systemctl disable firewalld
sed -i 's/^SELINUX=.*$/SELINUX=disabled/g' /etc/selinux/config

#Install OCP Command>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
echo -e "Installing OpenShift necessary CLI"
#find $OCP_PACKAGE_PATH -name "openshift-client-linux-$OCP_VERSION.tar.gz" -type f -exec tar xvf {} -C $OCP_PACKAGE_PATH \;
#find $OCP_PACKAGE_PATH -name "openshift-install-linux-$OCP_VERSION.tar.gz" -type f -exec tar xvf {} -C $OCP_PACKAGE_PATH \; 
#find $OCP_PACKAGE_PATH -name "oc-mirror.tar.gz" -type f -exec tar xvf {} -C $OCP_PACKAGE_PATH \; 
tar xvf /root/openshift-client-linux-$OCP_VERSION.tar.gz
tar xvf /root/openshift-install-linux-$OCP_VERSION.tar.gz
chmod +x openshift-install oc kubectl
mv openshift-install oc kubectl /usr/local/bin

cat >> /root/.bashrc << EOF
source <(oc completion bash)
source <(kubectl completion bash)
source <(openshift-install completion bash)
EOF

source /root/.bashrc
echo -e "OpenShift necessary CLI install done."
echo -e $EQUAL_LINE

#Install NTP>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#echo -e "Set the timezone to UTC"
#yum -y localinstall $OCP_PACKAGE_PATH/chrony/*.rpm --allowerasing --nobest --skip-broken
#systemctl enable chronyd --now
#sed -i 's/pool.*/server '$NTP_SERVER_IP' iburst/' /etc/chrony.conf
#systemctl restart chronyd
#chronyc sources -v
#
#cp /usr/share/zoneinfo/UTC{,.bak}
#timedatectl set-timezone UTC
#rm -rf /etc/localtime
#cp /usr/share/zoneinfo/Asia/Taipei /etc/localtime
#timedatectl
#echo -e "Set up."
#echo -e $EQUAL_LINE

#Install DNS>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
echo -e "Set the DNS server"
yum -y install bind bind-utils haproxy
systemctl enable named --now

cp /etc/named.rfc1912.zones{,.bak}
cp /etc/named.conf{,.bak}

sed -i 's/listen-on port.*/listen-on port 53 { any; };/' /etc/named.conf
sed -i 's/listen-on-v6 port.*/listen-on-v6 port 53 { ::1; };/' /etc/named.conf
sed -i 's/allow-query.*/allow-query { any; };/' /etc/named.conf
sed -i 's/dnssec-enable.*/dnssec-enable no;/' /etc/named.conf
sed -i 's/dnssec-validation.*/dnssec-validation no;/' /etc/named.conf

cat >> /etc/named.rfc1912.zones << EOF

zone "$OCP_CLUSTER_NAME.$BASE_DOMAIN" IN {
        type master;
        file "$OCP_CLUSTER_NAME.$BASE_DOMAIN.zone";
};

zone "$ARPA.in-addr.arpa" IN {
        type master;
        file "$ARPA.zone";
};
EOF
echo -e "DNS setup is completed."
echo -e $DASH_LINE

#Forward DNS Config>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
echo -e "Creating DNS forwarding file."
cat > /var/named/$OCP_CLUSTER_NAME.$BASE_DOMAIN.zone << EOF
\$TTL 1W
@           IN  SOA     $HOSTNAME. root.$OCP_CLUSTER_NAME.$BASE_DOMAIN. (
                        $(date +%Y%m%d)01 ; serial
                        1D ; refresh
                        1H ; retry
                        1W ; expire
                        3H ) ; minimum
@           IN   NS    $HOSTNAME.
@           IN   A     $DNS_IP
api         IN   A     $LOADBLANCER_IP
api-int     IN   A     $LOADBLANCER_IP
*.apps      IN   A     $LOADBLANCER_IP
haproxy     IN   A     $LOADBLANCER_IP
bastion     IN   A     $BASTION_IP
bootstrap   IN   A     $BOOTSTRAP_IP
master0     IN   A     $MASTER0_IP
master1     IN   A     $MASTER1_IP
master2     IN   A     $MASTER2_IP
worker0     IN   A     $WORKER0_IP
worker1     IN   A     $WORKER1_IP


EOF
echo -e "Created DNS forwarding file." 
echo -e $DASH_LINE

#Reverse DNS Config>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
echo -e "Creating DNS reversing file."
cat > /var/named/$ARPA.zone << EOF
\$TTL 1W
@           IN  SOA     $HOSTNAME. root.$OCP_CLUSTER_NAME.$BASE_DOMAIN. (
                        $(date +%Y%m%d)01 ; serial
                        1D ; refresh
                        1H ; retry
                        1W ; expire
                        3H ) ; minimum
@           IN   NS    $HOSTNAME.
@           IN   A     $DNS_IP
$(echo $LOADBLANCER_IP | awk -F'.' '{printf $NF}')  IN  PTR api.$OCP_CLUSTER_NAME.$BASE_DOMAIN.
$(echo $LOADBLANCER_IP | awk -F'.' '{printf $NF}')  IN  PTR api-int.$OCP_CLUSTER_NAME.$BASE_DOMAIN.
$(echo $LOADBLANCER_IP | awk -F'.' '{printf $NF}')  IN  PTR haproxy.$OCP_CLUSTER_NAME.$BASE_DOMAIN.
$(echo $BOOTSTRAP_IP | awk -F'.' '{printf $NF}')  IN  PTR bootstrap.$OCP_CLUSTER_NAME.$BASE_DOMAIN.
$(echo $BASTION_IP | awk -F'.' '{printf $NF}')  IN  PTR bastion.$OCP_CLUSTER_NAME.$BASE_DOMAIN.
$(echo $MASTER0_IP | awk -F'.' '{printf $NF}')  IN  PTR master0.$OCP_CLUSTER_NAME.$BASE_DOMAIN.
$(echo $MASTER1_IP | awk -F'.' '{printf $NF}')  IN  PTR master1.$OCP_CLUSTER_NAME.$BASE_DOMAIN.
$(echo $MASTER2_IP | awk -F'.' '{printf $NF}')  IN  PTR master2.$OCP_CLUSTER_NAME.$BASE_DOMAIN.
$(echo $WORKER0_IP | awk -F'.' '{printf $NF}')  IN  PTR worker0.$OCP_CLUSTER_NAME.$BASE_DOMAIN.
$(echo $WORKER1_IP | awk -F'.' '{printf $NF}')  IN  PTR worker1.$OCP_CLUSTER_NAME.$BASE_DOMAIN.



EOF
echo -e "Created DNS reversing file." 
echo -e $EQUAL_LIN

#Restart DNS>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
echo -e "Restarting the DNS service"
nmcli connection modify $CONNECTION_NAME ipv4.dns $DNS_IP
systemctl restart NetworkManager
systemctl restart named
rndc reload
echo -e "Restartd the DNS service"
echo -e $EQUAL_LINE

#DNS Check>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
echo -e "Testing the DNS forwarding and reversing."
for DNS_FORWARDING in $(sed -n '10,22p' /var/named/$ARPA.zone | awk '{printf $NF " "}')
do
  echo -e $DASH_LINE
  echo -e "Testing domain name Forwarding."
  echo -e "$DNS_FORWARDING=> $(dig $DNS_FORWARDING +short)"
done

for IP_REVERSING in $(sed -n '10,23p' /var/named/$OCP_CLUSTER_NAME.$BASE_DOMAIN.zone | awk '{printf $NF " "}')
do
  echo -e $DASH_LINE
  echo -e "Testing IP reversing."
  echo -e "$IP_REVERSING=> $(dig -x $IP_REVERSING +short)"
done
echo -e "Test done."
echo -e $EQUAL_LINE

#Install & Config HAproxy>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
echo -e "Setting up a load balancer with HAproxy"
#yum -y localinstall $OCP_PACKAGE_PATH/haproxy/*.rpm --allowerasing --nobest --skip-broken
systemctl enable --now haproxy
cp /etc/haproxy/haproxy.cfg{,.bak}

cat > /etc/haproxy/haproxy.cfg << EOF
global
    log         127.0.0.1 local2
    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    maxconn     4000
    user        haproxy
    group       haproxy
    daemon

    # turn on stats unix socket
    stats socket /var/lib/haproxy/stats

    # utilize system-wide crypto-policies
    ssl-default-bind-ciphers PROFILE=SYSTEM
    ssl-default-server-ciphers PROFILE=SYSTEM

defaults
    mode                    http
    log                     global
    option                  httplog
    option                  dontlognull
    option http-server-close
    option forwardfor       except 127.0.0.0/8
    option                  redispatch
    retries                 3
    timeout http-request    10s
    timeout queue           1m
    timeout connect         10s
    timeout client          1m
    timeout server          1m
    timeout http-keep-alive 10s
    timeout check           10s
    maxconn                 3000

# Enable HAProxy stats
listen stats
	bind :9000
	mode http
	stats enable
	stats uri /
    monitor-uri /healthz

# OpenShift API server
frontend openshift-api-server
	bind *:6443
	default_backend openshift-api-server
	mode tcp
	option tcplog

backend	openshift-api-server
	balance source
	mode tcp
	server bootstrap $BOOTSTRAP_IP:6443 check
	server master0	$MASTER0_IP:6443 check
	server master1	$MASTER1_IP:6443 check
	server master2	$MASTER2_IP:6443 check

# OpenShift Machine config server
frontend machine-config-server
	bind *:22623
	default_backend machine-config-server
	mode tcp
	option tcplog

backend machine-config-server
	balance source
	mode tcp
	server bootstrap $BOOTSTRAP_IP:22623 check
	server master0	$MASTER0_IP:22623 check
	server master1	$MASTER1_IP:22623 check
	server master2	$MASTER2_IP:22623 check

# OpenShift Ingress
frontend ingress-http
	bind *:80
	default_backend ingress-http
	mode tcp
	option tcplog

backend ingress-http
	balance source
	mode tcp
	server worker0 $WORKER0_IP:80 check
	server worker1 $WORKER1_IP:80 check

frontend ingress-https
	bind *:443
	default_backend ingress-https
	mode tcp
	option tcplog

backend ingress-https
	balance source
	mode tcp
	server worker0	$WORKER0_IP:443 check
	server worker1	$WORKER1_IP:443 check
	
EOF

setsebool -P haproxy_connect_any=1
systemctl restart haproxy
echo -e $EQUAL_LINE

#Setup firewall allow policy>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# echo -e "Setup firewall allow policy"
# FIREWALLD_STATUS=$(systemctl is-active firewalld)
# if [[ $FIREWALLD_STATUS == "active" ]] ; then
#   firewall-cmd --add-service={dns,http,https} --permanent
#   firewall-cmd --add-port={6443/tcp,22623/tcp,9000/tcp} --permanent
#   firewall-cmd --reload
#   echo -e "Setup done."
# else
#   echo -e "Service firewalld is inactive"
# fi
# echo -e $EQUAL_LINE

#Generate SSH Key>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
echo -e "Generating the SSH key"
ssh-keygen -t rsa -b 4096 -P '' -f ~/.ssh/id_rsa
echo -e $EQUAL_LINE

#Copy registry CA from Quay to Bastion>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#echo -e "Getting the registry root CA"
#scp root@${QUAY_IP}:${QUAY_CA_PATH}/rootCA.crt /etc/pki/ca-trust/source/anchors/ca.crt
#scp root@${QUAY_IP}:/root/pull-secret /root/pull-secret
#update-ca-trust extract
#echo -e $EQUAL_LINE

#Generate install-config.yaml>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
echo -e "Creating install-config.yaml"
if [[ -d $OCP_INSTALL_PATH ]] ; then
  rm -rf $OCP_INSTALL_PATH
  mkdir -p $OCP_INSTALL_PATH
else
  mkdir -p $OCP_INSTALL_PATH
fi

cd $OCP_INSTALL_PATH
cat > $OCP_INSTALL_PATH/install-config.yaml << EOF
apiVersion: v1
baseDomain: $BASE_DOMAIN
compute:
- hyperthreading: Enabled
  name: worker
  replicas: 0
controlPlane:
  hyperthreading: Enabled
  name: master
  replicas: 3
metadata:
  name: $OCP_CLUSTER_NAME
networking:
  clusterNetwork:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  networkType: OVNKubernetes
  serviceNetwork:
  - 172.30.0.0/16
platform:
  none: {}
fips: false
pullSecret: |
$( cat /root/pull-secret | sed 's/^/   /g' )
sshKey: |
$( cat /root/.ssh/id_rsa.pub | sed 's/^/   /g' )

EOF

cp $OCP_INSTALL_PATH/install-config.yaml /tmp/install-config.yaml.bak
echo -e $EQUAL_LINE

#Generate Manifest and Ignition Files>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#echo -e "Generating manifests and ignition files"
#openshift-install create manifests --dir $OCP_INSTALL_PATH
#sed -i 's/mastersSchedulable: true/mastersSchedulable: false/' $OCP_INSTALL_PATH/manifests/cluster-scheduler-02-config.yml

#cat > $OCP_INSTALL_PATH/openshift/99-worker-custom.bu << EOF
#variant: openshift
#version: 4.12.0
#metadata:
#  name: 99-worker-chrony 
#  labels:
#    machineconfiguration.openshift.io/role: worker 
#storage:
#  files:
#  - path: /etc/chrony.conf
#    mode: 0644 
#    overwrite: true
#    contents:
#      inline: |
#        server $NTP_SERVER_IP iburst 
#        driftfile /var/lib/chrony/drift
#        makestep 1.0 3
#        rtcsync
#        logdir /var/log/chrony
#EOF
#
#cat > $OCP_INSTALL_PATH/openshift/99-master-custom.bu << EOF
#variant: openshift
#version: 4.12.0
#metadata:
#  name: 99-master-chrony 
#  labels:
#    machineconfiguration.openshift.io/role: master 
#storage:
#  files:
#  - path: /etc/chrony.conf
#    mode: 0644 
#    overwrite: true
#    contents:
#      inline: |
#        server $NTP_SERVER_IP iburst 
#        driftfile /var/lib/chrony/drift
#        makestep 1.0 3
#        rtcsync
#        logdir /var/log/chrony
#EOF
#butane 99-worker-custom.bu -o $OCP_INSTALL_PATH/openshift/99-worker-custom.yaml
#butane 99-master-custom.bu -o $OCP_INSTALL_PATH/openshift/99-master-custom.yaml
#openshift-install create ignition-configs --dir $OCP_INSTALL_PATH
#echo -e $EQUAL_LINE

#Install Apache Server>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# echo -e "Setup Apache service"
# yum -y install httpd
# systemctl enable --now httpd
# sed -i 's/Listen 80/Listen 0.0.0.0:8080/' /etc/httpd/conf/httpd.conf
# if [[ $FIREWALLD_STATUS == "active" ]] ; then
#   firewall-cmd --add-port=8080/tcp --permanent
#   firewall-cmd --reload
# else
#   echo -e "Service firewalld is inactive"
# fi
# echo -e "Setup done"
# mkdir -p /var/www/html/install
# cp $OCP_INSTALL_PATH/*.ign /var/www/html/install
# cp $OCP_PACKAGE_PATH/ocp-install.sh /var/www/html/install
# chmod 777 -R /var/www/html/install
# systemctl restart httpd
# echo -e $EQUAL_LINE

#Check SELiunx Status>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# CHECK_SELINUX=$(cat /etc/selinux/config | grep SELINUX | grep disabled | awk -F"=" '{printf $2}')
# if [[ $CHECK_SELINUX == "disabled" ]] ; then
#   echo -e "All prerequites done and SELinux is disabled, the machine will be reboot after 15s."
#   sleep 15 ; reboot
# else
#   echo -e "All prerequites done."
# fi
