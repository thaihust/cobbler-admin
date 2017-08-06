#!/bin/bash

source env

echo "#### Install essential packages and back up configuration ####"
yum update -y
yum install -y epel-release 
yum install -y cobbler cobbler-web dnsmasq syslinux pykickstart xinetd net-tools iptables-services debmirror byobu crudini
cp ${COBBLER_SETTINGS} ${COBBLER_SETTINGS}.orig
cp ${COBBLER_MODULES} ${COBBLER_MODULES}.orig
cp ${DNS_TEMP} ${DNS_TEMP}.orig
cp ${DHCP_TEMP} ${DHCP_TEMP}.orig
cp ${XINETD} ${XINETD}.orig
cat ${COBBLER_SETTINGS}.orig | egrep -v "^$|^#" > ${COBBLER_SETTINGS}
cat ${COBBLER_MODULES}.orig | egrep -v "^$|^#" > ${COBBLER_MODULES}
cat ${DNS_TEMP}.orig | egrep -v "^$|^#" > ${DNS_TEMP}
cat ${DHCP_TEMP}.orig | egrep -v "^$|^#" > ${DHCP_TEMP}
cat ${XINETD}.orig | egrep -v "^$|^#" > ${XINETD}

echo "#### Config cobbler and dependencies components ####"
DEFAULT_NEW_ENCRYPT=$(openssl passwd -1 ${DEFAULT_NEW_PASS})
sed -i "s|${DEFAULT_OLD_ENCRYPT}|${DEFAULT_NEW_ENCRYPT}|g" ${COBBLER_SETTINGS}
sed -i "s/manage_dhcp: 0/manage_dhcp: 1/g" ${COBBLER_SETTINGS}
sed -i "s/manage_dns: 0/manage_dns: 1/g" ${COBBLER_SETTINGS}
sed -i "s/pxe_just_once: 0/pxe_just_once: 1/g" ${COBBLER_SETTINGS}
sed -i "s/server: 127.0.0.1/server: ${COBBLER_IP}/g" ${COBBLER_SETTINGS}
sed -i "s/next_server: 127.0.0.1/next_server: ${COBBLER_IP}/g" ${COBBLER_SETTINGS}

crudini --set --existing ${COBBLER_MODULES} dns module manage_dnsmasq
crudini --set --existing ${COBBLER_MODULES} dhcp module manage_dnsmasq

sed -i "s/dhcp-range=192.168.1.5,192.168.1.200/dhcp-range=${DHCP_START},${DHCP_END}/g" ${DNS_TEMP}
sed -i "s/range dynamic-bootp        192.168.1.100 192.168.1.254;/range dynamic-bootp        ${DHCP_START} ${DHCP_END};/g" ${DHCP_TEMP}
sed -i "s/disable\s\{1,\}= yes/disable                 = no/g" ${XINETD}

echo "### restart services and config iptables rules"
systemctl enable dnsmasq
systemctl enable tftp
systemctl enable httpd
systemctl enable cobblerd
systemctl enable xinetd
systemctl disable firewalld
systemctl enable iptables

systemctl start iptables
systemctl start cobblerd 
systemctl restart httpd
systemctl restart cobblerd
systemctl restart xinetd
cobbler get-loaders
systemctl restart cobblerd 
cobbler sync

iptables -D INPUT -j REJECT --reject-with icmp-host-prohibited
iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 69 -j ACCEPT
iptables -A INPUT -m state --state NEW -m udp -p udp --dport 69 -j ACCEPT
iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 25151 -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables-save
/usr/libexec/iptables/iptables.init save

echo "Downloading CenOS iso..."
curl -fSL http://centos-hn.viettelidc.com.vn/7/isos/x86_64/CentOS-7-x86_64-Minimal-1611.iso -o ~/CentOS-7-x86_64-Minimal-1611.iso
echo "Import iso to cobbler"
mkdir -p /mnt/iso
mount -t iso9660 -o loop ~/CentOS-7-x86_64-Minimal-1611.iso /mnt/iso
cobbler import --name=CentOS-7.1 --arch=x86_64 --path=/mnt/iso

echo "Config snippets and kickstarts"
ssh-keygen -t rsa -N "" -f /root/.ssh/cobbler-key
touch /var/lib/cobbler/snippets/publickey_root
cat << EOF > /var/lib/cobbler/snippets/publickey_root
cd /root
mkdir --mode=700 .ssh
cat >> .ssh/authorized_keys << "PUBLIC_KEY"
$(cat /root/.ssh/cobbler-key.pub)
PUBLIC_KEY
chmod 600 .ssh/authorized_keys
EOF

cp /var/lib/cobbler/kickstarts/sample_end.ks /var/lib/cobbler/kickstarts/sample_end.ks.orig
sed -i "s/\$SNIPPET('kickstart_done')/\
\$SNIPPET('publickey_root') \\
\$SNIPPET('kickstart_done')/g" /var/lib/cobbler/kickstarts/sample_end.ks

cobbler sync
