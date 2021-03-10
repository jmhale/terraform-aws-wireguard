#!/bin/bash -v
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -o Dpkg::Options::="--force-confnew"
apt-get install -y wireguard-dkms wireguard-tools awscli

cat > /etc/wireguard/wg0.conf <<- EOF
[Interface]
Address = ${wg_server_net}
PrivateKey = ${wg_server_private_key}
ListenPort = ${wg_server_port}
PostUp   = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o ${wg_server_interface} -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o ${wg_server_interface} -j MASQUERADE

${peers}
EOF

# we go with the eip if it is provided
if [ "${eip_id}" != "disabled" ]; then
  export INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
  export REGION=$(curl -fsq http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/[a-z]$//')
  aws --region $${REGION} ec2 associate-address --allocation-id ${eip_id} --instance-id $${INSTANCE_ID}
fi

chown -R root:root /etc/wireguard/
chmod -R og-rwx /etc/wireguard/*
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sysctl -p
ufw allow ssh
ufw allow ${wg_server_port}/udp
ufw --force enable
systemctl enable wg-quick@wg0.service
systemctl start wg-quick@wg0.service
