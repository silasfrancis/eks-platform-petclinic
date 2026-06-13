# IRSA for Cluster Add-ons
#
# IAM roles for service accounts used by core cluster add-ons and Karpenter.
# vpcCni and ebsCsi attach AWS-managed policies only. karpenter gets a custom
# policy combining node lifecycle permissions with several extra statements
# (instance profile management, interruption queue access, cluster describe,
# KMS access for encrypted EBS volumes).
#
# 
# HOW TO ADD A NEW IRSA ROLE HERE
# 1. Add a new key under `irsa_roles`.
# 2. Set `namespace` and `sas` (ServiceAccount names) to scope the trust policy.
# 3. Set `aws_managed_policies` to a list of managed policy ARNs to attach
#    (or leave empty if none).
# 4. Set `policy.actions`/`policy.resources` for a custom inline policy
#    (leave both empty if no custom policy is needed).
# 5. (Optional) Add `extra_statements` for additional IAM statement blocks
#    that don't fit the actions/resources shape.
# A custom policy + attachment is only created if policy.actions is non-empty
# or extra_statements is present.

data "aws_caller_identity" "current" {}

locals {
  oidc_url = replace(aws_iam_openid_connect_provider.eks.url, "https://", "")
  irsa_roles = {
      # VPC CNI — pod networking, uses AWS-managed CNI policy only
      vpcCni = {
        namespace = "kube-system"
        sas       = ["aws-node"]
        aws_managed_policies = ["arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"]
        policy    = {
          actions   = []
          resources = []
        }
      }

      # EBS CSI Driver — volume provisioning, uses AWS-managed EBS CSI policy only
      ebsCsi = {
        namespace = "kube-system"
        sas       = ["ebs-csi-controller-sa"]
        aws_managed_policies = ["arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"]
        policy    = {
          actions   = []
          resources = []
        }
      }

      # Karpenter — node provisioning/lifecycle management, fully custom policy
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

        extra_statements = [
          # Allows Karpenter to pass the node IAM role to new EC2 instances
          # it launches, and to inspect existing instance profiles
          {
          Effect   = "Allow"
          Action   = [
            "iam:PassRole",
            "iam:ListInstanceProfiles"
          ]
          Resource = [
            aws_iam_role.node_role.arn
          ]
        },
        # Allows Karpenter to consume interruption/rebalance notifications
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
        # Allows Karpenter to read cluster details (e.g. endpoint, CA cert)
        {
          Effect = "Allow"
          Action = [
            "eks:DescribeCluster"
          ]
          Resource = aws_eks_cluster.main_cluster.arn
        },
        # Allows Karpenter to create/manage instance profiles for new nodes
        # (required since EKS managed node groups aren't used for Karpenter nodes)
        {
          Effect = "Allow"
          Action = [
            "iam:GetInstanceProfile",
            "iam:CreateInstanceProfile",
            "iam:AddRoleToInstanceProfile",
            "iam:RemoveRoleFromInstanceProfile",
            "iam:DeleteInstanceProfile",
            "iam:TagInstanceProfile"       
          ]
          Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/*"
        },
        # Allows Karpenter to read SSM parameters (e.g. for resolving the
        # latest EKS-optimized AMI ID)
        {
          Effect = "Allow"
          Action = [
            "ssm:GetParameter"
          ]
          Resource = "*"
        },
        # Allows Karpenter-launched nodes' EBS volumes to be encrypted using
        # the data storage KMS key
        {
        Effect = "Allow"
        Action = [
          "kms:CreateGrant",
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:ReEncrypt*"
        ]
        Resource = var.data_storage_kms_key_arn
      }]
      }
    }
}

# IAM role per add-on, trusted by the cluster's OIDC provider and scoped to
# the ServiceAccount(s) listed in each.value.sas
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
  tags = merge(
      {
        system = "irsa"
      },
      var.extended_tags
    )
}

# Custom inline policy, created only for roles with custom actions or
# extra_statements (vpcCni and ebsCsi are skipped — managed policies only)
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
  tags = merge(
      {
        system = "irsa"
      },
      var.extended_tags
    )
}

# Maps each AWS-managed policy ARN to its target role for attachment
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

# Attach AWS-managed policies (vpcCni, ebsCsi)
resource "aws_iam_role_policy_attachment" "managed" {
  for_each   = local.managed_policy_map
  role       = aws_iam_role.irsa[each.value.role_name].name
  policy_arn = each.value.policy_arn
}

# Attach custom inline policies (karpenter)
resource "aws_iam_role_policy_attachment" "custom" {
  for_each = { for k, v in local.irsa_roles : k => v 
    if length(v.policy.actions) > 0 || can(v.extra_statements) 
  }
  role       = aws_iam_role.irsa[each.key].name
  policy_arn = aws_iam_policy.custom_irsa[each.key].arn
}