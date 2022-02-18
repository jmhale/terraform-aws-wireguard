#!/bin/bash -v
export DEBIAN_FRONTEND=noninteractive

add-apt-repository "ppa:wireguard/wireguard"
apt-get update -y
apt-get upgrade -y -o Dpkg::Options::="--force-confnew"
apt-get install -y wireguard-dkms wireguard-tools python3-pip

# aws cli
pip3 install --upgrade --user rsa awscli==1.20.54
export PATH=/root/.local/bin:$PATH
mkdir /root/.aws/
touch /root/.aws/config
cat << 'EOF' > /root/.aws/config
[profile wireguard]
role_arn = ${role_arn}
source_profile = default

[default]
region=${region}
EOF

# fetch the VPN server private key
wg_server_private_key=$(aws ssm get-parameter \
    --name "${wg_server_private_key_param}" \
    --with-decryption \
    --query 'Parameter.Value' \
    --output text)

cat << EOF > /etc/wireguard/wg0.conf
[Interface]
Address = ${wg_server_net}
PrivateKey = $wg_server_private_key
ListenPort = ${wg_server_port}
PostUp   = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

EOF

echo "${peers_recreate}" > /dev/null #Forces user_data replacement
# fetch peers file and concatenate to wg0.conf
aws s3 cp s3://${peers_bucket}/peers.txt /tmp/peers.txt
cat /tmp/peers.txt >> /etc/wireguard/wg0.conf

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
# Splunk forwarder setup for wireguard logs
wget -O /etc/splunkforwarder-8.2.4-87e2dda940d1-Linux-x86_64.tgz 'https://download.splunk.com/products/universalforwarder/releases/8.2.4/linux/splunkforwarder-8.2.4-87e2dda940d1-Linux-x86_64.tgz'
cd /etc && tar xzf splunkforwarder-8.2.4-87e2dda940d1-Linux-x86_64.tgz
aws s3 cp s3://${peers_bucket}/wireguard-log-parser_011.tgz /etc/splunkforwarder/etc/apps/wireguard-log-parser_011.tgz
aws s3 cp s3://${peers_bucket}/splunkclouduf.spl /etc/splunkforwarder/etc/apps/splunkclouduf.spl
cd /etc/splunkforwarder/etc/apps/ && tar -xzf wireguard-log-parser_011.tgz
/etc/splunkforwarder/bin/splunk start --accept-license --answer-yes --no-prompt --seed-passwd ${splunk_pwd}
/etc/splunkforwarder/bin/splunk install app /etc/splunkforwarder/etc/apps/splunkclouduf.spl -auth admin:${splunk_pwd}
mkdir -p /etc/splunkforwarder/etc/apps/journald_input/local && aws s3 cp s3://${peers_bucket}/inputs.conf /etc/splunkforwarder/etc/apps/journald_input/local/inputs.conf
export SPLUNK_HOME=/etc/splunkforwarder && $SPLUNK_HOME/bin/splunk restart
# Wirelogd setup
git clone https://github.com/smartcontractkit/wirelogd.git /etc/wirelogd
cd /etc/wirelogd && make deb
dpkg -i dist/wirelogd-0.1.3-1.deb
# Start wireguard
systemctl enable wg-quick@wg0.service
systemctl start wg-quick@wg0.service
