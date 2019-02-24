data "aws_ssm_parameter" "wg_server_private_key" {
  name = "/wireguard/wg-server-private-key"
}

data "aws_ssm_parameter" "wg_laptop_public_key" {
  name = "/wireguard/wg-laptop-public-key"
}
