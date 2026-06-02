# Fetch the official AWS Load Balancer Controller IAM Policy
data "http" "aws_lbc_iam_policy_json" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json"
  
  request_headers = {
    Accept = "application/json"
  }
}

resource "aws_iam_role" "alb_controller_irsa" {
  name = "${var.cluster_name}-aws-load-balancer-controller-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = var.oidc_arn }
      Condition = {
        StringLike = {
          "${var.oidc_url}:sub" = [
            "system:serviceaccount:kube-system:aws-load-balancer-controller"
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

resource "aws_iam_policy" "alb_controller_policy" {
  name   = "${var.cluster_name}-alb-controller-policy"
  policy = data.http.aws_lbc_iam_policy_json.response_body

  tags = merge(
    {
      system = "irsa"
    },
    var.extended_tags
  )
}

resource "aws_iam_role_policy_attachment" "alb_controller_attach" {
  role       = aws_iam_role.alb_controller_irsa.name
  policy_arn = aws_iam_policy.alb_controller_policy.arn
}