resource "aws_iam_role_policy_attachment" "jump_host_secrets_policy_attachment" {
  role       = aws_iam_role.pod_secrets_reader.name
  policy_arn = aws_iam_policy.pod_read_secrets_policy.arn
  depends_on = [ aws_iam_policy.pod_read_secrets_policy]
}   
