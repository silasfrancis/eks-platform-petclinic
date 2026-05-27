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

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.wireguard_server_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "wireguard_server_profile" {
  name = "wireguard-server-instance-profile" 
  role = aws_iam_role.wireguard_server_role.name
}