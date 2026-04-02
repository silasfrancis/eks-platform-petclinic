resource "aws_iam_policy" "jumphost_policy" {
  name = "${var.env}-${var.app}-jumphost-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEKSAccess"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:AccessKubernetesApi"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowECRAccess"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeRepositories",
          "ecr:ListImages"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowSecretsManagerAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:*:*:secret:${var.secret_name}*"
      },
      {
        Sid    = "AllowKMSAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })
  tags = {
    resource = "iam"
  }
}

resource "aws_iam_role_policy_attachment" "jumphost_policy_attachment" {
  role       = aws_iam_role.jumphost_ec2_role.name
  policy_arn = aws_iam_policy.jumphost_policy.arn
  depends_on = [ aws_iam_policy.jumphost_policy ]
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.jumphost_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "jumphost_ec2_profile" {
  name = "${var.env}-${var.app}-jumphost-profile" 
  role = aws_iam_role.jumphost_ec2_role.name
}