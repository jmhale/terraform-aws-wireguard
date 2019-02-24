data "template_file" "user_data" {
  template = "${file("${path.module}/templates/user-data.tpl")}"

  vars {
    wg_server_private_key = "${data.aws_ssm_parameter.wg_server_private_key.value}"
    wg_laptop_public_key  = "${data.aws_ssm_parameter.wg_laptop_public_key.value}"
    eip_id                = "${aws_eip.wireguard_eip.id}"
  }
}

data "template_cloudinit_config" "config" {
  part {
    content_type = "text/cloud-config"
    content      = "${data.template_file.user_data.rendered}"
  }
}

resource "aws_eip" "wireguard_eip" {
  vpc = true
}

resource "aws_launch_configuration" "wireguard_launch_config" {
  name_prefix                 = "wireguard-lc-"
  image_id                    = "${var.ami_id}"
  instance_type               = "t2.micro"
  key_name                    = "${var.ssh_key_id}"
  iam_instance_profile        = "${aws_iam_instance_profile.wireguard_profile.name}"
  user_data                   = "${data.template_cloudinit_config.config.rendered}"
  security_groups             = ["${aws_security_group.sg_wireguard_external.id}"]
  associate_public_ip_address = true

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "wireguard_asg" {
  name_prefix          = "wireguard-asg-"
  max_size             = 1
  min_size             = 1
  launch_configuration = "${aws_launch_configuration.wireguard_launch_config.name}"
  vpc_zone_identifier  = ["${var.public_subnet_ids}"]
  health_check_type    = "EC2"
  termination_policies = ["OldestInstance"]

  lifecycle {
    create_before_destroy = true
  }

  tags = [
    {
      key                 = "Name"
      value               = "wireguard"
      propagate_at_launch = true
    },
    {
      key                 = "Project"
      value               = "wireguard"
      propagate_at_launch = true
    },
    {
      key                 = "tf-managed"
      value               = "True"
      propagate_at_launch = true
    },
  ]
}
