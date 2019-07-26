# terraform-aws-wireguard

A Terraform module to deploy a WireGuard VPN server on AWS.

## Prerequisites
Before using this module, you'll need to generate a key pair for your server and client, and store the server's private key and client's public key in AWS SSM, which cloud-init will source and add to WireGuard's configuration.

- Install the WireGuard tools for your OS: https://www.wireguard.com/install/
- Generate a key pair for each client
  - `wg genkey | tee client1-privatekey | wg pubkey > client1-publickey`
- Generate a key pair for the server
  - `wg genkey | tee server-privatekey | wg pubkey > server-publickey`
- Add the server private key to the AWS SSM parameter: `/wireguard/wg-server-private-key`
  - `aws ssm put-parameter --name /wireguard/wg-server-private-key --type SecureString --value $ServerPrivateKeyValue`
- Add each client's public key, along with the next available IP address as a key:value pair to the wg_client_public_keys map. See Usage for details.

## Variables
| Variable Name | Type | Required |Description |
|---------------|-------------|-------------|-------------|
|`public_subnet_ids`|`list`|Yes|A list of subnets for the Autoscaling Group to use for launching instances. May be a single subnet, but it must be an element in a list.|
|`ssh_key_id`|`string`|Yes|A SSH public key ID to add to the VPN instance.|
|`vpc_id`|`string`|Yes|The VPC ID in which Terraform will launch the resources.|
|`ami_id`|`string`|No. Defaults to Ubuntu 16.04 AMI in us-east-1|The AMI ID to use.|
|`env`|`string`|No. Defaults "prod"|The name of environment for WireGuard. Used to differentiate multiple deployments.|
|`wg_client_public_keys`|`list`|Yes.|List of maps of client IPs and public keys. See Usage for details.|

## EIP/public subnet usage
```
resource "aws_eip" "wireguard" {
  vpc = true
  tags = {
    Name = "wireguard"
  }
}

module "wireguard" {
  source                = "git@github.com:jmhale/terraform-wireguard.git"
  ssh_key_id            = "ssh-key-id-0987654"
  vpc_id                = "vpc-01234567"
  subnet_ids            = ["subnet-01234567"]
  eip_id                = "${aws_eip.wireguard.id}"
  wg_server_net         = "192.168.2.1/24" # client_ips_must_exist_in_this_net
  wg_client_public_keys = [
    {"192.168.2.2/32" = "QFX/DXxUv56mleCJbfYyhN/KnLCrgp7Fq2fyVOk/FWU="},
    {"192.168.2.3/32" = "+IEmKgaapYosHeehKW8MCcU65Tf5e4aXIvXGdcUlI0Q="},
    {"192.168.2.4/32" = "WO0tKrpUWlqbl/xWv6riJIXipiMfAEKi51qvHFUU30E="},
  ]
}
```

## ELB/private subnet usage
```
module "wireguard" {
  source                = "git@github.com:jmhale/terraform-wireguard.git"
  ssh_key_id            = "ssh-key-id-0987654"
  vpc_id                = "vpc-01234567"
  subnet_ids            = ["subnet-01234567"]
  target_group_arns     = ["${aws_lb_target_group.wireguard.arn}"]
  associate_public_ip_address = false
  wg_server_net         = "192.168.2.1/24" # client_ips_must_exist_in_this_net
  wg_client_public_keys = [
    {"192.168.2.2/32" = "QFX/DXxUv56mleCJbfYyhN/KnLCrgp7Fq2fyVOk/FWU="},
    {"192.168.2.3/32" = "+IEmKgaapYosHeehKW8MCcU65Tf5e4aXIvXGdcUlI0Q="},
    {"192.168.2.4/32" = "WO0tKrpUWlqbl/xWv6riJIXipiMfAEKi51qvHFUU30E="},
  ]
}
```

## Outputs
| Output Name | Description |
|---------------|-------------|
|`vpn_ip`|The public IPv4 address of the AWS Elastic IP assigned to the instance.|
|`vpn_sg_id`|ID of the internal Security Group to associate with other resources needing to be accessed on VPN|

## Caveats

- I would strongly recommend forking this repo or cloning it locally and change the `source` definition to be something that you control. You really don't want your infra to be at the mercy of my changes.


## To-do

- Support multiple clients.
