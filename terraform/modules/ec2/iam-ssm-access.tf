resource "aws_iam_policy" "ssm_jumphost_access" {
  name        = "ssm-jumphost-access"
  description = "Allows SSM access to jumphost only"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:StartSession"
        ]
        Resource = [
          aws_instance.ec2_instance.arn,
          "arn:aws:ssm:us-east-2::document/AWS-StartSSHSession",
          "arn:aws:ssm:us-east-2::document/AWS-StartPortForwardingSession"
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
      },
      {
        Effect = "Deny"
        Action = "ssm:StartSession"
        NotResource = [
          aws_instance.ec2_instance.arn
        ]
      }
    ]
  })
}

data "aws_iam_group" "platform_engineers" {
  group_name = var.platform_engineers_group_name
}

resource "aws_iam_group_policy_attachment" "ssm_jumphost" {
  group      = data.aws_iam_group.platform_engineers.group_name
  policy_arn = aws_iam_policy.ssm_jumphost_access.arn
}