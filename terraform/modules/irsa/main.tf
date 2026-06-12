# IRSA Resources
#
# Iterates over local.irsa_roles to create, per entry:
#   - An IAM role assumable only via the EKS OIDC provider, restricted to the
#     specific namespace/ServiceAccount combination(s) defined in `sas`
#   - An IAM policy combining the base `policy` block with any
#     `extra_statements`
#   - The attachment binding the policy to the role


# IAM role per component, trusted by the cluster's OIDC provider and scoped
# to the Kubernetes ServiceAccount(s) listed in each.value.sas
resource "aws_iam_role" "irsa" {
  for_each = local.irsa_roles
  name     = "${var.cluster_name}-${each.key}-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
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
  tags = merge(
      {
        system = "irsa"
      },
      var.extended_tags
    )
}

# IAM policy per component, combining its base actions/resources with any
# extra_statements defined for that entry
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
  
  tags = merge(
      {
        system = "irsa"
      },
      var.extended_tags
    )
}

# Attach each generated policy to its corresponding role
resource "aws_iam_role_policy_attachment" "irsa" {
  for_each   = local.irsa_roles
  role       = aws_iam_role.irsa[each.key].name
  policy_arn = aws_iam_policy.irsa[each.key].arn
}