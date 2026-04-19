resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.wireguard_server_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "wireguard_server_profile" {
  name = "${var.env}-${var.app}-wireguard-server-profile" 
  role = aws_iam_role.wireguard_server_role.name
}