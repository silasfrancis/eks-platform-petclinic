# WireGuard Server — SSM Access
#
# Grants the "platform" IAM group permission to start SSM sessions
# (Session Manager shell, SSH-over-SSM, and port forwarding) on the WireGuard
# server only — used for Ansible configuration management and troubleshooting
# without exposing SSH to the internet.


# Permits Session Manager / SSH-over-SSM / port forwarding to the WireGuard
# instance specifically, plus read-only session/instance discovery (required
# by the Session Manager client, scoped to "*" since these are list/describe
# calls with no resource-level permissions)
resource "aws_iam_policy" "ssm_wireguard_server_access" {
  name        = "ssm-wireguard-server-access"
  description = "Allows SSM access to wireguard server only"

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

# IAM group whose members (platform engineers) get this access
data "aws_iam_group" "platform_engineers" {
  group_name = var.platform_engineers_group_name
}

resource "aws_iam_group_policy_attachment" "ssm_wireguard_server" {
  group      = data.aws_iam_group.platform_engineers.group_name
  policy_arn = aws_iam_policy.ssm_wireguard_server_access.arn
}