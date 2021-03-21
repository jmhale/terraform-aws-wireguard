%{ for keypair in client_pub_keys }
%{ for ip, pub_key in keypair }
[Peer]
PublicKey = ${pub_key}
AllowedIPs = ${ip}
PersistentKeepalive = ${persistent_keepalive}
%{ endfor ~}
%{ endfor ~}
