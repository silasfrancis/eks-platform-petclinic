# WireGuard Server — IAM
#
# Instance role allowing EC2 to assume it, with the AWS-managed
# AmazonSSMManagedInstanceCore policy attached so the instance can be managed
# via AWS Systems Manager (Session Manager, Ansible-over-SSM) without
# requiring SSH key access.


# Role assumable by EC2, attached to the instance via the profile below
resource "aws_iam_role" "wireguard_server_role" {
  name = "wireguard-server-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Sid    = ""
            Principal = {
                Service = "ec2.amazonaws.com"
            }
        }
    ]
  })
  tags = var.extended_tags
}

# Grants SSM Agent permissions needed for Session Manager and managed
# instance core functionality
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.wireguard_server_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile attached to the EC2 instance
resource "aws_iam_instance_profile" "wireguard_server_profile" {
  name = "wireguard-server-instance-profile" 
  role = aws_iam_role.wireguard_server_role.name
}