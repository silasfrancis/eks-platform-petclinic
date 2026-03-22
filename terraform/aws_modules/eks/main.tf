resource "aws_eks_cluster" "main_cluster" {
  name     = "${var.env}-eks-cluster"
  version  = var.k8_version
  role_arn = var.cluster_role_arn

  vpc_config {
    subnet_ids              = var.subnet_ids_for_cluster
    security_group_ids      = var.security_group_id
    endpoint_private_access = true
    endpoint_public_access  = false 
    }

  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = var.kms_eks_secrets_arn 
    }
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  kubernetes_network_config {
  service_ipv4_cidr = "10.100.0.0/16" 
  ip_family         = "ipv4"
  }

  timeouts {
    create = "30m"
    delete = "30m"
  }
  tags = {
    env = var.env
    app = var.application
    resource = "EKS"
  }

}

resource "aws_launch_template" "eks_nodes" {
  name = "${var.env}-eks-node-template"
  description = "EKS node launch template for ${var.env}"

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.disk_size
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = var.kms_eks_nodes_ebs_arn
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.env}-eks-node"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name = "${var.env}-eks-node-volume"
    }
  }
  tag_specifications {
    tags = {
      env = var.env
      app = var.application
    }
  }
}

resource "aws_eks_node_group" "cluster_node_group" {
  cluster_name    = aws_eks_cluster.main_cluster.name
  node_group_name = "${var.env}-node-group"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids_node_group
  ami_type        = var.ami_type

  launch_template {
    id      = aws_launch_template.eks_nodes.id
    version = aws_launch_template.eks_nodes.default_version
  }

  scaling_config {
    desired_size = var.node_scaling_config.desired_size
    max_size     = var.node_scaling_config.max_size
    min_size     = var.node_scaling_config.min_size
  }

  update_config {
    max_unavailable_percentage = 33
  }

  capacity_type = "ON_DEMAND"

  tags = {
    env = var.env
    app = var.application
    "k8s.io/cluster-autoscaler/enabled"                              = "true"
    "k8s.io/cluster-autoscaler/${aws_eks_cluster.main_cluster.name}" = "owned"
  }

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}