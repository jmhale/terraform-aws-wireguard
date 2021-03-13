variable "ssh_key_id" {
  description = "A SSH public key ID to add to the VPN instance."
}

variable "instance_type" {
  default     = "t2.micro"
  description = "The machine type to launch, some machines may offer higher throughput for higher use cases."
}

variable "asg_min_size" {
  default     = 1
  description = "We may want more than one machine in a scaling group, but 1 is recommended."
}

variable "asg_desired_capacity" {
  default     = 1
  description = "We may want more than one machine in a scaling group, but 1 is recommended."
}

variable "asg_max_size" {
  default     = 1
  description = "We may want more than one machine in a scaling group, but 1 is recommended."
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
  description = "IP range for vpn server - make sure your Client ips are in this range but not the specific ip i.e. not .1"
}

variable "wg_server_port" {
  default     = 51820
  description = "Port for the vpn server."
}

variable "wg_persistent_keepalive" {
  default     = 25
  description = "Persistent Keepalive - useful for helping connection stability over NATs."
}

variable "use_eip" {
  type        = bool
  default     = false
  description = "Whether to enable Elastic IP switching code in user-data on wg server startup. If true, eip_id must also be set to the ID of the Elastic IP."
}

variable "eip_id" {
  type        = string
  description = "ID of the Elastic IP to use, when use_eip is enabled."
}

variable "additional_security_group_ids" {
  type        = list(string)
  default     = [""]
  description = "Additional security groups if provided, default empty."
}

variable "target_group_arns" {
  type        = list(string)
  default     = null
  description = "Running a scaling group behind an LB requires this variable, default null means it won't be included if not set."
}

variable "env" {
  default     = "prod"
  description = "The name of environment for WireGuard. Used to differentiate multiple deployments."
}

variable "wg_server_private_key_param" {
  default     = "/wireguard/wg-server-private-key"
  description = "The SSM parameter containing the WG server private key."
}

variable "ami_id" {
  default     = null # we check for this and use a data provider since we can't use it here
  description = "The AWS AMI to use for the WG server, defaults to the latest Ubuntu 16.04 AMI if not specified."
}

variable "wg_server_interface" {
  default     = "eth0"
  description = "The default interface to forward network traffic to."
}
