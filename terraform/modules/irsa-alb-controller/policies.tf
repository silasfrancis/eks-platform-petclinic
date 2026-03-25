resource "aws_iam_policy" "lbc_policy" {
  name   = "${var.env}-${var.app}-AWSLoadBalancerControllerIAMPolicy"
  policy = file("${path.module}/alb-controller-policy.json")
}