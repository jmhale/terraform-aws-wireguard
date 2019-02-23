# terraform-wireguard

A Terraform module to deploy a Wireguard VPN server on AWS.

Beware! Work in progress! Use at your own peril! Here be dragons!

### Required variables
The following variables need to be passed to the module:

- `ssh_key_id`: A SSH public key ID to add to the VPN instance.
- `vpc_id`: The VPC ID in which Terraform will launch the resources.
- `public_subnet_ids`: A list of subnets for the Autoscaling Group to use for launching instances. May be a single subnet, but it must be an element in a list.

### Example module init
```
module "wireguard" {
  source            = "git@github.com:jmhale/terraform-wireguard.git"
  ssh_key_id        = "ssh-key-id-0987654"
  vpc_id            = "vpc-01234567"
  public_subnet_ids = ["subnet-01234567"]
}
```

### Caveats

- I would strongly recommend forking this repo or cloning it locally and change the `source` definition to be something that you control. You really don't want your infra to be at the mercy of my changes.


### To-do

- Add the mechanism to attach the EIP to the instance, via cloud-init.
