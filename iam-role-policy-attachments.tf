resource "aws_iam_role_policy_attachment" "wireguard_roleattach" {
  role = aws_iam_role.wireguard_role[0].name

  policy_arn = aws_iam_policy.wireguard_policy[0].arn
  count      = (var.eip_id == null ? 0 : 1) # only used for EIP mode
}

#resource "aws_iam_role_policy_attachment" "ssm_agent_to_ec2_instance_role" {
#  role       = aws_iam_role.wireguard_role[0].name
#  policy_arn = aws_iam_policy.ssm_agent_policy.arn
#}
