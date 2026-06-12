# IRSA: AWS Load Balancer Controller
#
# Dedicated IRSA setup for the AWS Load Balancer Controller, which is installed
# to allow advanced annotations on Service type=LoadBalancer resources used by
# the Istio ingress gateways (e.g. NLB target type, subnet and
# security group attachment, etc). Kept separate from the generic IRSA module since
# its IAM policy is fetched directly from the upstream project rather than
# defined inline.

# Fetch the official AWS Load Balancer Controller IAM Policy
# Pulled directly from the upstream project so the policy stays in sync with
# the controller version being installed
data "http" "aws_lbc_iam_policy_json" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json"
  
  request_headers = {
    Accept = "application/json"
  }
}

# IAM role for the controller, trusted by the cluster's OIDC provider and
# scoped to the aws-load-balancer-controller ServiceAccount in kube-system
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

# IAM policy containing the full set of permissions the controller needs to
# manage ALBs/NLBs, target groups, security groups, etc.
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

# Attach the controller policy to its role
resource "aws_iam_role_policy_attachment" "alb_controller_attach" {
  role       = aws_iam_role.alb_controller_irsa.name
  policy_arn = aws_iam_policy.alb_controller_policy.arn
}