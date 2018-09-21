# terraform-wireguard

A Terraform module to deploy a Wireguard VPN server on AWS.

Beware! Work in progress! Use at your own peril! Here be dragons!

### Required variables
The following variables need to be passed to the module:

- `ssh_key_id`: A SSH public key ID to add to the VPN instance.
- `dns_zone_id`: The Route53 zone ID to create a record for the VPN instance EIP.
- `vpc_id`: The VPC ID in which Terraform will launch the resources.
- `subnets`: A list of subnets for the Autoscaling Group to use for launching instances. May be a single subnet, but it must be an element in a list.

Example module init:
```
module "wireguard" {
  source      = "github.com/jmhale/terraform-wireguard"
  dns_zone_id = "XXXXZZZZZZZYYY"
  ssh_key_id  = "ssh-key-id-0987654"
  vpc_id      = "vpc-01234567"
  subnets     = ["subnet-01234567"]
}
```

### Caveats

- I would strongly recommend forking this repo or cloning it locally and change the `source` definition to be something that you control. You really don't want your infra to be at the mercy of my changes.

- Right now, the Route53 zone is required. If you don't have a zone in R53 or don't want to create a DNS entry for the Wireguard server, you'll need to dig the Route53 resources out of the Terraform definitions, so you can omit the variable in the module init. I'll try to make this more flexible in the future.


### To-do

- Make the creation of Route53 resources conditional, based on the presence of a ZoneID. If absent, then just skip.
- Add the mechanism to attach the EIP to the instance, via cloud-init.
