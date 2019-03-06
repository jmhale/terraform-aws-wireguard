variable "ssh_key_id" {
  description = "A SSH public key ID to add to the VPN instance."
}

variable "vpc_id" {
  description = "The VPC ID in which Terraform will launch the resources."
}

variable "ami_id" {
  default = "ami-da05a4a0"
  description = "The AMI ID to use."
}

variable "public_subnet_ids" {
  type = "list"
  description = "A list of subnets for the Autoscaling Group to use for launching instances. May be a single subnet, but it must be an element in a list."
}

variable "wg_client_public_keys" {
  type = "list"
  description = "List of maps of client IPs and public keys. See Usage in README for details."
}

variable "env" {
  default = "prod"
  description = "The name of environment for WireGuard. Used to differentiate multiple deployments"
}
