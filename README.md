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
|`subnet_ids`|`list`|Yes|A list of subnets for the Autoscaling Group to use for launching instances. May be a single subnet, but it must be an element in a list.|
|`ssh_key_id`|`string`|Yes|A SSH public key ID to add to the VPN instance.|
|`vpc_id`|`string`|Yes|The VPC ID in which Terraform will launch the resources.|
|`env`|`string`|No. Defaults to "prod"|The name of environment for WireGuard. Used to differentiate multiple deployments.|
|`eip_id`|`string`|Optional|The EIP ID to which the vpn server will attach.|
|`target_group_arns`|`string`|Optional|The Loadbalancer Target Group to which the vpn server ASG will attach.|
|`associate_public_ip_address`|`boolean`|Optional - defaults to `true`|Whether or not to associate a public ip.|
|`wg_server_net`|`cidr range`|Yes|The server net - all wg_client_public_keys entries need to be within this net .|
|`wg_client_public_keys`|`list`|Yes.|List of maps of client IPs and public keys. See Usage for details.|

Please see the following examples to understand usage with the relevant options..

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
  wg_server_net         = "192.168.2.1/24" # client IPs must exist in this net
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
  source                      = "git@github.com:jmhale/terraform-wireguard.git"
  ssh_key_id                  = "ssh-key-id-0987654"
  vpc_id                      = "vpc-01234567"
  subnet_ids                  = ["subnet-76543210"]
  target_group_arns           = ["arn:aws:elasticloadbalancing:eu-west-1:123456789:targetgroup/wireguard-prod/123456789"]
  associate_public_ip_address = false
  wg_server_net               = "192.168.2.1/24" # client IPs must exist in this net
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
|`vpn_asg_name`|The name of the wireguard Auto Scaling Group|
|`vpn_sg_admin_id`|ID of the internal Security Group to associate with other resources needing to be accessed on VPN.|
|`vpn_sg_external_id`|ID of the external Security Group to associate with the VPN.|

## Caveats

- I would strongly recommend forking this repo or cloning it locally and change the `source` definition to be something that you control. You really don't want your infra to be at the mercy of my changes.
