variable "ssh_key_id"  {}
variable "dns_zone_id" {}
variable "vpc_id"      {}
variable "subnets"     {
  type = "list"
}

data "aws_ssm_parameter" "wg-server-private-key" { name = "/wireguard/wg-server-private-key" }
data "aws_ssm_parameter" "wg-laptop-public-key"  { name = "/wireguard/wg-laptop-public-key" }

data "aws_iam_policy_document" "ec2-assume-role" {
    statement {
        actions = [
          "sts:AssumeRole"
        ]
        principals {
          type        = "Service"
          identifiers = ["ec2.amazonaws.com"]
        }
    }
}

data "template_file" "wg0-config" {
  template = <<EOF
[Interface]
Address = 192.168.2.1
PrivateKey = "$${wg_server_private_key}"
ListenPort = 51820
PostUp   = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = "$${wg_laptop_public_key}"
AllowedIPs = 192.168.2.2/32
EOF

  vars {
    wg_server_private_key = "${data.aws_ssm_parameter.wg-server-private-key.value}"
    wg_laptop_public_key  = "${data.aws_ssm_parameter.wg-laptop-public-key.value}"
  }
}

data "template_cloudinit_config" "config" {
  part {
    content_type = "text/x-shellscript"
    content      =<<EOF
add-apt-repository ppa:wireguard/wireguard
apt-get update
apt-get install -y wireguard-dkms wireguard-tools awscli
export INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
aws ec2 associate-address --allocation-id ${aws_eip.wireguard_eip.id} --instance-id $${INSTANCE_ID}
EOF
  }

  part {
    filename     = "/etc/wireguard/wg.conf"
    content_type = "text/part-handler"
    content      = "${data.template_file.wg0-config.rendered}"
  }

  part {
    content_type = "text/x-shellscript"
    content      =<<EOF
chown -R root:root /etc/wireguard/
chmod -R og-rwx /etc/wireguard/*
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sysctl -p
ufw allow ssh
ufw allow 51820/udp
ufw --force enable
systemctl enable wg-quick@wg0.service
systemctl start wg-quick@wg0.service
EOF
  }
}

resource "aws_eip" "wireguard_eip" {
  vpc     = true
}

resource "aws_route53_record" "vpn_r53_a_record" {
  zone_id = "${var.dns_zone_id}"
  name    = "vpnwg"
  type    = "A"
  ttl     = "300"
  records = ["${aws_eip.wireguard_eip.public_ip}"]
}

data "aws_iam_policy_document" "wireguard-policy-doc" {
    statement {
      actions = [
        "ec2:AssociateAddress"
      ]
      resources = ["*"] ## TODO: See if we can scope this to wireguard_eip
    }
}

resource "aws_iam_policy" "wireguard-policy" {
    name = "tf-wireguard"
    description = "Terraform Managed. Allows Wireguard instance to attach EIP."
    policy = "${data.aws_iam_policy_document.wireguard-policy-doc.json}"
}

resource "aws_iam_role" "wireguard-role" {
  name = "tf-wireguard"
  description = "Terraform Managed. Role to allow Wireguard instance to attach EIP."
  path = "/"
  assume_role_policy = "${data.aws_iam_policy_document.ec2-assume-role.json}"
}

resource "aws_iam_instance_profile" "wireguard-profile" {
  name = "tf-wireguard"
  role = "${aws_iam_role.wireguard-role.name}"
}

resource "aws_security_group" "wireguard-sg" {
  name          = "wireguard-sg"
  description   = "Terraform Managed. Allow Wireguard client traffic from internet."
  vpc_id        = "${var.vpc_id}"
  tags {
    Name        = "wireguard-sg",
    Project     = "wireguard",
    tf-managed  = "True"
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
resource "aws_launch_configuration" "wireguard-launch-config" {
    name_prefix                 = "wireguard-lc-"
    image_id                    = "ami-da05a4a0"
    instance_type               = "t2.micro"
    key_name                    = "${var.ssh_key_id}"
    iam_instance_profile        = "${aws_iam_instance_profile.wireguard-profile.name}"
    user_data                   = "${data.template_cloudinit_config.config.rendered}"
    security_groups             = ["${aws_security_group.wireguard-sg.id}"]
    associate_public_ip_address = true

    lifecycle {
      create_before_destroy = true
    }
}

resource "aws_autoscaling_group" "wireguard-asg" {
  name_prefix          = "wireguard-asg-"
  max_size             = 1
  min_size             = 1
  launch_configuration = "${aws_launch_configuration.wireguard-launch-config.name}"
  vpc_zone_identifier  = "${var.subnets}"
  health_check_type    = "EC2"
  termination_policies = ["OldestInstance"]

  lifecycle {
    create_before_destroy = true
  }

  tags {
    Name = "wireguard",
    Project = "wireguard",
    tf-managed = "True"
  }
}
