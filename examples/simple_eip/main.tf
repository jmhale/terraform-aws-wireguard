resource "aws_eip" "wireguard" {
  vpc = true
  tags = {
    Name = "wireguard"
  }
}

module "wireguard" {
  source        = "git@github.com:jmhale/terraform-wireguard.git"
  ssh_key_id    = "ssh-key-id-0987654"
  vpc_id        = "vpc-01234567"
  subnet_ids    = ["subnet-01234567"]
  use_eip       = true
  eip_id        = "${aws_eip.wireguard.id}"
  wg_server_net = "192.168.2.1/24" # client IPs MUST exist in this net
  wg_clients = [
    {
      name       = "example1"
      public_key = "QFX/DXxUv56mleCJbfYyhN/KnLCrgp7Fq2fyVOk/FWU="
      client_ip  = "192.168.2.2/32"
    },
    {
      name       = "example2"
      public_key = "+IEmKgaapYosHeehKW8MCcU65Tf5e4aXIvXGdcUlI0Q="
      client_ip  = "192.168.2.3/32"
    },
    {
      name       = "example3"
      public_key = "WO0tKrpUWlqbl/xWv6riJIXipiMfAEKi51qvHFUU30E="
      client_ip  = "192.168.2.4/32"
    },
  ]
}
