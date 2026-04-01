resource "aws_iam_policy" "lbc_policy" {
  name   = "${var.env}-${var.app}-AWSLoadBalancerControllerIAMPolicy"
  policy = file("${path.module}/lb-controller-policy.json")
}

resource "aws_iam_role_policy_attachment" "irsa_lb_controller_policy_attachment" {
  role       = aws_iam_role.irsa_lb_controller.name
  policy_arn = aws_iam_policy.lbc_policy.arn
}