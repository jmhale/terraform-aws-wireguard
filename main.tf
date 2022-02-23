data "aws_region" "current" {}

data "template_file" "user_data" {
  template = file("${path.module}/templates/userdata.sh")

  vars = {
    region                      = data.aws_region.current.name
    role_arn                    = aws_iam_role.wireguard_role.arn
    wg_server_private_key_param = data.aws_ssm_parameter.wg_server_private_key.name
    wg_server_net               = var.wg_server_net
    wg_server_port              = var.wg_server_port
    eip_id                      = var.eip_id
    peers_recreate              = sha1(join("\n", data.template_file.wg_client_data_json.*.rendered)) # var to force user_data replacement
    splunk_pwd                  = random_password.splunk_pwd.result
    peers_bucket                = var.peers_bucket
  }
}

data "template_file" "wg_client_data_json" {
  template = file("${path.module}/templates/client-data.tpl")
  count    = length(var.wg_client_public_keys)

  vars = {
    client_pub_key       = element(values(var.wg_client_public_keys[count.index]), 0)
    client_ip            = element(keys(var.wg_client_public_keys[count.index]), 0)
    persistent_keepalive = var.wg_persistent_keepalive
  }
}

# We're using ubuntu images - this lets us grab the latest image for our region from Canonical
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

# turn the sg into a sorted list of string
locals {
  sg_wireguard_external = sort([aws_security_group.sg_wireguard_external.id])
}

# clean up and concat the above wireguard default sg with the additional_security_group_ids
locals {
  security_groups_ids = compact(concat(var.additional_security_group_ids, local.sg_wireguard_external))
}

# Work around user_data length limit:
module "s3_peers_bucket" {
  source = "git@github.com:smartcontractkit/infra-modules.git//aws/s3b?ref=b8fc82e20386fee4bb5680cc8482e875bda7b013"
  name   = var.peers_bucket
  region = data.aws_region.current.name
  vpcs   = var.peers_bucket_access_vpcs
}

resource "aws_s3_object" "peers_file" {
  bucket  = var.peers_bucket
  key     = "peers.txt"
  content = join("\n", data.template_file.wg_client_data_json.*.rendered)
}

resource "random_password" "splunk_pwd" {
  length           = 10
  special          = false
}

resource "aws_launch_configuration" "wireguard_launch_config" {
  name_prefix                 = "wireguard-${var.env}-"
  image_id                    = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.ssh_key_id
  iam_instance_profile        = aws_iam_instance_profile.wireguard_profile.name
  user_data                   = data.template_file.user_data.rendered
  security_groups             = local.security_groups_ids
  associate_public_ip_address = true

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "wireguard_asg" {
  name                 = aws_launch_configuration.wireguard_launch_config.name
  launch_configuration = aws_launch_configuration.wireguard_launch_config.name
  min_size             = var.asg_min_size
  desired_capacity     = var.asg_desired_capacity
  max_size             = var.asg_max_size
  vpc_zone_identifier  = var.subnet_ids
  health_check_type    = "EC2"
  termination_policies = ["OldestLaunchConfiguration", "OldestInstance"]
  target_group_arns    = var.target_group_arns

  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = aws_launch_configuration.wireguard_launch_config.name
    propagate_at_launch = true
  }
  tag {
    key                 = "Project"
    value               = "wireguard"
    propagate_at_launch = true
  }
  tag {
    key                 = "env"
    value               = var.env
    propagate_at_launch = true
  }
  tag {
    key                 = "tf-managed"
    value               = "True"
    propagate_at_launch = true
  }
}
