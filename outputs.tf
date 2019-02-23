output "vpn_ip" {
  value = "${aws_eip.wireguard_eip.public_ip}"
}

output "cloud-init-cruft" {
  value = "${data.template_cloudinit_config.config.rendered}"
}
