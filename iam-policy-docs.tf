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

data "aws_iam_policy_document" "wireguard_policy_doc" {
  statement {
    actions = [
      "ec2:AssociateAddress",
    ]

    resources = ["*"]
  }
}

# AWS Services - SSM Agent, Session Manager
# https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-setting-up-messageAPIs.html
# Note we do not have KMS/S3 perms, our use case is only SSH and that doesn't support encryption/logging
data "aws_iam_policy_document" "ssm_agent_policy" {
  # allow Container Instances to interact with Systems Manager via SSM Agent
  statement {
    actions = [
      "ssm:DescribeDocumentParameters",
      "ssm:DescribeInstanceProperties",
      "ssm:GetManifest",
      "ssm:ListInstanceAssociations",
      "ssm:PutConfigurePackageResult",
      "ssm:UpdateInstanceAssociationStatus",
      "ssm:UpdateInstanceInformation",
    ]

    # can't do much here
    # https://docs.aws.amazon.com/service-authorization/latest/reference/list_awssystemsmanager.html
    resources = [
      "*"
    ]
  }

  # allow Container Instances to interact with Session Manager
  # "This endpoint is required to create and delete session channels with the Session Manager service in the cloud"
  statement {
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
      //      "s3:GetEncryptionConfiguration",
    ]

    # can't do much here
    # https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazonsessionmanagermessagegatewayservice.html
    resources = [
      "*",
    ]
  }

  //  # (along with GetEncryptionConfiguration above) use KMS for additional encryption
  //  statement {
  //    actions = [
  //      "kms:Decrypt"
  //    ]
  //  }
  //
  //  resources = [
  //    var.ssm_kms_key_arn,
  //  ]

  # allow Container Instances to interact with Session Manager
  statement {
    actions = [
      "ec2messages:AcknowledgeMessage",
      "ec2messages:DeleteMessage",
      "ec2messages:FailMessage",
      "ec2messages:GetEndpoint",
      "ec2messages:GetMessages",
      "ec2messages:SendReply"
    ]

    # can't do much here
    # https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazonmessagedeliveryservice.html
    resources = [
      "*"
    ]
  }
}
