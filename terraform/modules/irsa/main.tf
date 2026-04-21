resource "aws_iam_role" "irsa" {
  for_each = local.irsa_roles
  name     = "${var.cluster_name}-${each.key}-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = var.oidc_arn }
      Condition = {
        StringLike = {
          "${var.oidc_url}:sub" = [
            for sa in each.value.sas :
            "system:serviceaccount:${each.value.namespace}:${sa}"
          ]
          "${var.oidc_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
  tags = {
    system = "irsa"
  }
}

resource "aws_iam_policy" "irsa" {
  for_each = local.irsa_roles
  name     = "${var.cluster_name}-${each.key}-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [{
        Effect   = "Allow"
        Action   = each.value.policy.actions
        Resource = each.value.policy.resources
      }],
      lookup(each.value, "extra_statements", [])
    )
  })
  
  tags = {
    system = "irsa"
  }
}

resource "aws_iam_role_policy_attachment" "irsa" {
  for_each   = local.irsa_roles
  role       = aws_iam_role.irsa[each.key].name
  policy_arn = aws_iam_policy.irsa[each.key].arn
}