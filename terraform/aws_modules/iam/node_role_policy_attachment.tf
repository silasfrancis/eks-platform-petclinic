resource "aws_iam_role_policy_attachment" "node_secrets_policy_attachment" {
  role       = aws_iam_role.worker_node_role.name
  policy_arn = aws_iam_policy.read_secrets_policy.arn
  depends_on = [ aws_iam_policy.read_secrets_policy ]
}

resource "aws_iam_role_policy_attachment" "ec2_container_registry_policy_attachment" {
  role       = aws_iam_role.worker_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_minimal_policy_attachment" {
  role       = aws_iam_role.worker_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodeMinimalPolicy"
}

