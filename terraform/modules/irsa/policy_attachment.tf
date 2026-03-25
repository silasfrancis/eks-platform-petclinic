resource "aws_iam_role_policy_attachment" "irsa_secrets_policy_attachment" {
  role       = aws_iam_role.irsa_secrets_reader.name
  policy_arn = aws_iam_policy.irsa_secrets_policy.arn
  depends_on = [ aws_iam_policy.irsa_secrets_policy]
}   
