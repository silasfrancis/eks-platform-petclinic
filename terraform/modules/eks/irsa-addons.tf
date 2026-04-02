locals {
  oidc_url = replace(aws_iam_openid_connect_provider.eks.url, "https://", "")
}

resource "aws_iam_role" "vpc_cni" {
  name = "${var.env}-${var.app}-vpc-cni-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_url}:sub" = "system:serviceaccount:kube-system:aws-node"
          "${local.oidc_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
  tags = {
    resource = "iam"
  }
  depends_on = [ aws_eks_cluster.main_cluster, aws_iam_openid_connect_provider.eks ]
}

resource "aws_iam_role" "ebs_csi" {
  name = "${var.env}-${var.app}-ebs-csi-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_url}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          "${local.oidc_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}


resource "aws_iam_role_policy_attachment" "vpc_cni_policy_attachment" {
  role       = aws_iam_role.vpc_cni.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}   

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}