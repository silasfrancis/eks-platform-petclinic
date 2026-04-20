resource "aws_iam_policy" "ssm_wireguard_server_access" {
  name        = "ssm-jumphost-access"
  description = "Allows SSM access to jumphost only"

  policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = ["ssm:StartSession"]
          Resource = [
            aws_instance.wireguard_server.arn,
            "arn:aws:ssm:us-east-2:*:document/AWS-StartSSHSession",
            "arn:aws:ssm:us-east-2:*:document/AWS-StartPortForwardingSession",
            "arn:aws:ssm:us-east-2:*:document/SSM-SessionManagerRunShell"
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "ec2:DescribeInstances",
            "ssm:DescribeSessions",
            "ssm:GetConnectionStatus",
            "ssm:DescribeInstanceProperties"
          ]
          Resource = "*"
        }
      ]
    })
}

data "aws_iam_group" "platform_engineers" {
  group_name = var.platform_engineers_group_name
}

resource "aws_iam_group_policy_attachment" "ssm_wireguard_server" {
  group      = data.aws_iam_group.platform_engineers.group_name
  policy_arn = aws_iam_policy.ssm_wireguard_server_access.arn
}