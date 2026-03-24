resource "aws_iam_role_policy_attachment" "jumphost_eks_policy_attachment" {
  role       = aws_iam_role.jumphost_ec2_role.name
  policy_arn = aws_iam_role_policy.jumphost_eks_policy.arn
  depends_on = [ aws_iam_role_policy.jumphost_eks_policy ]
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.jumphost_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "jumphost_ec2_profile" {
  name = "${var.env}-${var.app}-jumphost-profile" 
  role = aws_iam_role.jumphost_ec2_role.name
}