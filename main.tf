data "aws_ssm_parameter" "wg_server_private_key" {
  name = "/wireguard/wg-server-private-key"
}

data "aws_ssm_parameter" "wg_laptop_public_key" {
  name = "/wireguard/wg-laptop-public-key"
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

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

data "aws_iam_policy_document" "wireguard_policy_doc" {
  statement {
    actions = [
      "ec2:AssociateAddress",
    ]

    resources = ["*"] ## TODO: See if we can scope this to wireguard_eip
  }
}

resource "aws_iam_policy" "wireguard_policy" {
  name        = "tf-wireguard"
  description = "Terraform Managed. Allows Wireguard instance to attach EIP."
  policy      = "${data.aws_iam_policy_document.wireguard_policy_doc.json}"
}

resource "aws_iam_role" "wireguard_role" {
  name               = "tf-wireguard"
  description        = "Terraform Managed. Role to allow Wireguard instance to attach EIP."
  path               = "/"
  assume_role_policy = "${data.aws_iam_policy_document.ec2_assume_role.json}"
}

resource "aws_iam_role_policy_attachment" "wireguard_roleattach" {
  role       = "${aws_iam_role.wireguard_role.name}"
  policy_arn = "${aws_iam_policy.wireguard_policy.arn}"
}

resource "aws_iam_instance_profile" "wireguard_profile" {
  name = "tf-wireguard"
  role = "${aws_iam_role.wireguard_role.name}"
}

resource "aws_security_group" "sg_wireguard_external" {
  name        = "wireguard-external"
  description = "Terraform Managed. Allow Wireguard client traffic from internet."
  vpc_id      = "${var.vpc_id}"

  tags {
    Name       = "wireguard-external"
    Project    = "wireguard"
    tf-managed = "True"
  }

  ingress {
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
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
