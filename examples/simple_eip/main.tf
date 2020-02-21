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
  eip_id        = "${aws_eip.wireguard.id}"
  wg_server_net = "192.168.2.1/24" # client IPs MUST exist in this net
  wg_client_public_keys = [
    { "192.168.2.2/32" = "QFX/DXxUv56mleCJbfYyhN/KnLCrgp7Fq2fyVOk/FWU=" }, # make sure these are correct
    { "192.168.2.3/32" = "+IEmKgaapYosHeehKW8MCcU65Tf5e4aXIvXGdcUlI0Q=" }, # wireguard is sensitive
    { "192.168.2.4/32" = "WO0tKrpUWlqbl/xWv6riJIXipiMfAEKi51qvHFUU30E=" }, # to bad configuration
  ]
}
