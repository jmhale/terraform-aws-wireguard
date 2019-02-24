output "vpn_ip" {
  value = "${aws_eip.wireguard_eip.public_ip}"
}

output "vpn_sg_id" {
  value = "${aws_security_group.sg_wireguard_admin.id}"
}
