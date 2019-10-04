variable "ssh_key_id" {
  description = "A SSH public key ID to add to the VPN instance."
}

variable "vpc_id" {
  description = "The VPC ID in which Terraform will launch the resources."
}

variable "subnet_ids" {
  type        = list(string)
  description = "A list of subnets for the Autoscaling Group to use for launching instances. May be a single subnet, but it must be an element in a list."
}

variable "wg_client_public_keys" {
# type        = map(string)
  description = "List of maps of client IPs and public keys. See Usage in README for details."
}

variable "wg_server_net" {
  default     = "192.168.2.1/24"
  description = "IP range for vpn server - make sure your Client ids are in this range"
}

variable "wg_server_port" {
  default     = 51820
  description = "Port for the vpn server"
}

variable "eip_id" {
  default     = "disabled"
  description = "If we detect the default 'disabled' we avoid the EIP switching code in user-data on wg server startup, if an EIP ID is provided the instance will attempt to switch EIP."
}

variable "associate_public_ip_address" {
  default     = true
  description = "get a public address or not, use with eip, but set false if the vpn server sits on a private net behidn elb"
}

variable "additional_security_group_ids" {
  type        = list(string)
  default     = [""]
  description = "Additional security groups if provided, default empty"
}

variable "target_group_arns" {
  type        = list(string)
  default     = null
  description = "Running a scaling group behind an LB requires this variable, default null means it won't be included if not set"
}

variable "env" {
  default     = "prod"
  description = "The name of environment for WireGuard. Used to differentiate multiple deployments"
}
