# EKS Cluster
#
# The EKS control plane. Runs in private subnets only (no public API
# endpoint — accessed via the WireGuard VPN / Transit Gateway). Secrets are
# encrypted using the dedicated eks_secrets KMS key, API/audit logs are sent
# to CloudWatch, and the cluster is protected from accidental destroy.
resource "aws_eks_cluster" "main_cluster" {
  name     = "${var.app}-${var.env}-cluster"
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster_role.arn

  vpc_config {
    subnet_ids              = var.private_subnets
    security_group_ids      = [aws_security_group.eks_node.id]
    endpoint_private_access = true
    endpoint_public_access  = false 
    }

  # Enables both the access entries API and the legacy aws-auth ConfigMap
  # for cluster authentication
  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  # Encrypts Kubernetes Secrets at the etcd layer using the eks_secrets KMS key
  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = var.eks_secrets_kms_key_arn 
    }
  }

  enabled_cluster_log_types = ["api", "audit"]

  kubernetes_network_config {
  service_ipv4_cidr = "10.100.0.0/16" 
  ip_family         = "ipv4"
  }

  timeouts {
    create = "30m"
    update = "60m"
    delete = "30m"
  }
  tags = merge(
      {
        Name = "${var.app}-${var.env}-cluster"
      },
      var.extended_tags
    )

  depends_on = [
    aws_iam_role.cluster_role,
    aws_cloudwatch_log_group.eks_log_group
  ]

  # Protects the cluster from accidental deletion via terraform destroy
  lifecycle {
    prevent_destroy = true
  }
}