output "vpn_ip" {
  value       = aws_eip.wireguard_eip.public_ip
  description = "The public IPv4 address of the AWS Elastic IP assigned to the instance."
}

output "vpn_sg_id" {
  value       = aws_security_group.sg_wireguard_admin.id
  description = "ID of the internal Security Group to associate with other resources needing to be accessed on VPN."
}

