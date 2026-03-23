resource "aws_iam_role_policy_attachment" "jump_host_secrets_policy_attachment" {
  role       = aws_iam_role.jumphost_ec2_role.name
  policy_arn = aws_iam_policy.read_secrets_policy.arn
  depends_on = [ aws_iam_policy.read_secrets_policy ]
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.jumphost_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "jumphost_ec2_profile" {
  name = "${var.env}-${var.app}-jumphost-profile" 
  role = aws_iam_role.jumphost_ec2_role.name
}