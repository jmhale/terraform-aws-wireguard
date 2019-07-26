output "vpn_sg_id" {
  value = "${aws_security_group.sg_wireguard_admin.id}"
  description = "ID of the internal Security Group to associate with other resources needing to be accessed on VPN."
}

output "vpn_asg_name" {
  value = "${aws_autoscaling_group.wireguard_asg.name}"
  description = "ID of the internal Security Group to associate with other resources needing to be accessed on VPN."
}
