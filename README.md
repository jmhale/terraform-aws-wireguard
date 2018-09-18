# terraform-wireguard (Work in progress!)

A Terraform module to deploy a Wireguard VPN server on AWS.

### Required variables.
The following variables need to be passed to the module:

- ssh_key_id: A SSH public key ID to add to the VPN instance.
- dns_zone_id: The Route53 zone ID to create a record for the VPN instance EIP.
- vpc_id: The VPC ID in which Terraform will launch the resources.
- subnets: A list of subnets for the Autoscaling Group to use for launching instances. May be a single subnet, but it must be an element in a list.
