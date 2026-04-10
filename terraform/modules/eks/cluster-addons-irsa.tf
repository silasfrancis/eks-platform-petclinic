locals {
  oidc_url = replace(aws_iam_openid_connect_provider.eks.url, "https://", "")
  irsa_roles = {
      vpc_cni = {
        namespace = "kube-system"
        sas       = ["aws-node"]
        aws_managed_policies = ["arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"]
        policy    = {
          actions   = []
          resources = []
        }
      }

      ebs_csi = {
        namespace = "kube-system"
        sas       = ["aws-ebs-csi-driver"]
        aws_managed_policies = ["arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"]
        policy    = {
          actions   = []
          resources = []
        }
      }

      karpenter = {
        namespace = "karpenter"
        sas       = ["karpenter"]
        aws_managed_policies = []
        policy    = {
          actions   = [
            "ec2:CreateLaunchTemplate",
            "ec2:CreateFleet",
            "ec2:RunInstances",
            "ec2:CreateTags",
            "ec2:TerminateInstances",
            "ec2:DeleteLaunchTemplate",
            "ec2:DescribeLaunchTemplates",
            "ec2:DescribeInstances",
            "ec2:DescribeSecurityGroups",
            "ec2:DescribeSubnets",
            "ec2:DescribeImages",
            "ec2:DescribeInstanceTypes",
            "ec2:DescribeInstanceTypeOfferings",
            "ec2:DescribeAvailabilityZones",
            "ec2:DescribeSpotPriceHistory",
            "pricing:GetProducts",
          ]
          resources = ["*"]
        }

        extra_statements = [{
          Effect   = "Allow"
          Action   = [
            "iam:PassRole",
            "iam:ListInstanceProfiles"
          ]
          Resource = [
            var.node_role_arn
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "sqs:DeleteMessage",
            "sqs:GetQueueAttributes",
            "sqs:GetQueueUrl",
            "sqs:ReceiveMessage"
          ]
          Resource = aws_sqs_queue.karpenter_interruption.arn
        },
        {
          Effect = "Allow"
          Action = [
            "eks:DescribeCluster"
          ]
          Resource = aws_eks_cluster.main_cluster.arn
        }]
      }
    }
}

resource "aws_iam_role" "irsa" {
  for_each = local.irsa_roles
  name     = "${aws_eks_cluster.main_cluster.name}-${each.key}-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = aws_iam_openid_connect_provider.eks.arn }
      Condition = {
        StringLike = {
          "${local.oidc_url}:sub" = [
            for sa in each.value.sas : "system:serviceaccount:${each.value.namespace}:${sa}"
          ]
          "${local.oidc_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_policy" "custom_irsa" {
  for_each = { for k, v in local.irsa_roles : k => v 
    if length(v.policy.actions) > 0 || can(v.extra_statements) 
  }
  name = "${aws_eks_cluster.main_cluster.name}-${each.key}-custom-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      length(each.value.policy.actions) > 0 ? [{
        Effect   = "Allow"
        Action   = each.value.policy.actions
        Resource = length(each.value.policy.resources) > 0 ? each.value.policy.resources : ["*"]
      }] : [],
      lookup(each.value, "extra_statements", [])
    )
  })
}

locals {
  managed_policy_map = merge([
    for role_key, role_data in local.irsa_roles : {
      for policy_arn in role_data.aws_managed_policies : 
        "${role_key}-${md5(policy_arn)}" => {
          role_name  = role_key
          policy_arn = policy_arn
        }
    }
  ]...)
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each   = local.managed_policy_map
  role       = aws_iam_role.irsa[each.value.role_name].name
  policy_arn = each.value.policy_arn
}

resource "aws_iam_role_policy_attachment" "custom" {
  for_each   = aws_iam_policy.custom_irsa
  role       = aws_iam_role.irsa[each.key].name
  policy_arn = each.value.arn
}