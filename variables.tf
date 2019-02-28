variable "ssh_key_id" {}

variable "vpc_id" {}

variable "ami_id" {
  default = "ami-da05a4a0"
}

variable "public_subnet_ids" {
  type = "list"
}

variable "wg_client_public_keys" {
  type = "list"

  default = [
    {
      "192.168.2.2/32" = "ABCDEFG"
    },
    {
      "192.168.2.3/32" = "ABCDEFG"
    },
    {
      "192.168.2.4/32" = "ABCDEFG"
    },
  ]
}
