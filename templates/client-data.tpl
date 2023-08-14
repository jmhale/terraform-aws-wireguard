%{ for peer in wg_client_public_keys ~}%{ for client_ip, client_pub_key in peer }
[Peer]
PublicKey = ${client_pub_key}
AllowedIPs = ${client_ip}
PersistentKeepalive = 25
%{ endfor ~}
%{ endfor ~}