resource "aws_eks_cluster" "main_cluster" {
  name     = "${var.env}-${var.app}-eks-cluster"
  version  = var.cluster_version
  role_arn = var.cluster_role_arn

  vpc_config {
    subnet_ids              = var.subnet_ids_for_cluster
    security_group_ids      = [var.eks_security_group_id]
    endpoint_private_access = true
    endpoint_public_access  = false 
    }

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = var.kms_eks_secrets_arn 
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
  tags = {
    resource = "eks"
  }

  lifecycle {
    prevent_destroy = true
  }

}
