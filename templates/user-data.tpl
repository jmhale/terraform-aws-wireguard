#cloud-config
package_update: true
package_upgrade: true
apt_sources:
  - source: "ppa:wireguard/wireguard"
packages:
  - wireguard-dkms
  - wireguard-tools
  - awscli
write_files:
  - path: /etc/wireguard/wg0.conf
    content: |
      [Interface]
      Address = 192.168.2.1
      PrivateKey = ${wg_server_private_key}
      ListenPort = 51820
      PostUp   = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
      PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

      [Peer]
      PublicKey = ${wg_laptop_public_key}
      AllowedIPs = 192.168.2.2/32
runcmd:
  - export INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
  - export REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep -oP '\"region\"[[:space:]]*:[[:space:]]*\"\K[^\"]+')
  - aws --region $${REGION} ec2 associate-address --allocation-id ${eip_id} --instance-id $${INSTANCE_ID}
  - chown -R root:root /etc/wireguard/
  - chmod -R og-rwx /etc/wireguard/*
  - sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
  - sysctl -p
  - ufw allow ssh
  - ufw allow 51820/udp
  - ufw --force enable
  - systemctl enable wg-quick@wg0.service
  - systemctl start wg-quick@wg0.service
