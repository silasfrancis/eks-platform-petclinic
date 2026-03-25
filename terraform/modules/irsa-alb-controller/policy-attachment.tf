resource "aws_iam_role_policy_attachment" "irsa_alb_controller_policy_attachment" {
  role       = aws_iam_role.irsa_alb_controller.name
  policy_arn = aws_iam_policy.lbc_policy.arn
}