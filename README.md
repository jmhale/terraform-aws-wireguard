# terraform-aws-wireguard

A Terraform module to deploy a WireGuard VPN server on AWS. Can also used to run one or more servers behind a loadbalancer, for redundancy.

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
|`additional_security_group_ids`|`list`|Optional - empty| Used to allow added access to reach the WG server or allow loadbalanced tests.|
|`asg_min_size`|`integer`|Optional|Number of VPN servers to permit minimum, only makes sense in loadbalanced scenario.|
|`asg_desired_capacity`|`integer`|Optional|Number of VPN servers to maintain, only makes sense in loadbalanced scenario.|
|`asg_max_size`|`integer`|Optional|Number of VPN servers to permit maximum, only makes sense in loadbalanced scenario.|
|`instance_type`|`string`|Optional|Size of VPN server, defaults to t2.micro|
|`wg_server_net`|`cidr range`|Yes|The server net - all wg_client_public_keys entries need to be within this net .|
|`wg_client_public_keys`|`list`|Yes|List of maps of client IPs and public keys. See Usage for details.|
|`wg_persistent_keepalive`|`integer`|Optional|Regularity of Keepalives, useful for NAT stability. Defaults to 25.|

Please see the following examples to understand usage with the relevant options..

## Simple EIP/public subnet usage
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
  wg_server_net         = "192.168.2.1/24" # client IPs MUST exist in this net
  wg_client_public_keys = [
    {"192.168.2.2/32" = "QFX/DXxUv56mleCJbfYyhN/KnLCrgp7Fq2fyVOk/FWU="}, # make sure these are correct, wireguard is sensitive to bad config
    {"192.168.2.3/32" = "+IEmKgaapYosHeehKW8MCcU65Tf5e4aXIvXGdcUlI0Q="},
    {"192.168.2.4/32" = "WO0tKrpUWlqbl/xWv6riJIXipiMfAEKi51qvHFUU30E="},
  ]
}
```

## Complex ELB/private subnet usage
```
module "wireguard" {
  source                        = "git@github.com:jmhale/terraform-wireguard.git"
  ssh_key_id                    = "ssh-key-id-0987654"
  vpc_id                        = "vpc-01234567"
  additional_security_group_ids = [aws_security_group.wireguard_ssh_check.id] # for ssh health checks, see below
  subnet_ids                    = ["subnet-76543210"] # You'll want a NAT gateway on this, but we don't document that.
  target_group_arns             = ["arn:aws:elasticloadbalancing:eu-west-1:123456789:targetgroup/wireguard-prod/123456789"]
  asg_min_size                  = 1 # a sensible minimum, which is also the default
  asg_desired_capacity          = 2 # we want two servers running most of the time
  asg_max_size                  = 5 # this cleanly permits us to allow rolling updates, growing and shrinking
  associate_public_ip_address   = false # we don't want eip, we want all our traffic out of a single NAT for whitelisting simplicity
  wg_server_net                 = "192.168.2.1/24" # client IPs MUST exist in this net
  wg_client_public_keys = [
    {"192.168.2.2/32" = "QFX/DXxUv56mleCJbfYyhN/KnLCrgp7Fq2fyVOk/FWU="}, # make sure these are correct, wireguard is sensitive to bad config
    {"192.168.2.3/32" = "+IEmKgaapYosHeehKW8MCcU65Tf5e4aXIvXGdcUlI0Q="},
    {"192.168.2.4/32" = "WO0tKrpUWlqbl/xWv6riJIXipiMfAEKi51qvHFUU30E="},
  ]
}

resource "aws_lb" "wireguard" {
  name                             = "wireguard"
  load_balancer_type               = "network"
  internal                         = false
  subnets                          = ["subnet-876543210"] # typically a public subnet
}

resource "aws_security_group" "wireguard_ssh_check" {
  name   = "wireguard_ssh_check"
  vpc_id = "vpc-01234567"

  # SSH access from the CIDR, which allows our healthcheck to complete
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = 192.168.1.0/24 # range that covers public subnet_ids, aws_lb will check the hosts from these ranges
  }
}

resource "aws_lb_target_group" "wireguard" {
  name_prefix          = "wireguard"
  port                 = 51820
  protocol             = "UDP"
  vpc_id               = "vpc-01234567"

  health_check {
    port     = 22 # make sure to add additional_security_group_ids with a rule to allow ssh from the loadbalancer range so this test passes.
    protocol = "TCP"
  }

}

resource "aws_lb_listener" "wireguard" {
  load_balancer_arn = aws_lb.wireguard.arn
  port              = 51820
  protocol          = "UDP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wireguard.arn
  }
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
