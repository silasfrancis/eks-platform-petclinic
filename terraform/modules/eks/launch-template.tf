# EKS Node Launch Template
#
# Launch template used by the Karpenter bootstrap node group (and as the
# template Karpenter references when launching its own nodes). Uses the
# latest ARM64 (Graviton) EKS-optimized AMI, bootstraps nodes via the
# node.eks.aws NodeConfig user-data format, enforces IMDSv2, and encrypts the
# root EBS volume with the data storage KMS key.


# Latest ARM64 EKS-optimized AMI for this cluster's Kubernetes version
data "aws_ssm_parameter" "eks_ami" {
  name = "/aws/service/eks/optimized-ami/${var.cluster_version}/amazon-linux-2023/arm64/standard/recommended/image_id"
}

locals {
  # NodeConfig user-data (node.eks.aws format) that bootstraps the node to
  # join the cluster, with maxPods raised to 58 to better utilize Graviton
  # instances' higher pod-per-node capacity
  node_user_data = <<-EOT
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="==BOUNDARY=="

--==BOUNDARY==
Content-Type: application/node.eks.aws

---
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster:
    name: ${aws_eks_cluster.main_cluster.name}
    apiServerEndpoint: ${aws_eks_cluster.main_cluster.endpoint}
    certificateAuthority: ${aws_eks_cluster.main_cluster.certificate_authority[0].data}
    cidr: ${aws_eks_cluster.main_cluster.kubernetes_network_config[0].service_ipv4_cidr}
  kubelet:
    config:
      maxPods: 58
    flags:
      - "--max-pods=58"

--==BOUNDARY==--
EOT
}

resource "aws_launch_template" "eks_nodes" {
  name = "${var.app}-${var.env}-eks-node-template"
  description = "EKS node launch template for ${var.env}"
  instance_type = "t4g.small"
  image_id      = data.aws_ssm_parameter.eks_ami.value
  user_data = base64encode(local.node_user_data)
  update_default_version = true
  
  # Enforces IMDSv2 (token required) to mitigate SSRF-based credential theft
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  # Root volume — encrypted with the shared data storage KMS key
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = "30"
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = var.data_storage_kms_key_arn
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      {
        Name = "${var.env}-karpenter-node"
      },
      var.extended_tags
    )
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(
      {
        Name = "${var.env}-karpenter-node-volume"
      },
      var.extended_tags
    )
  }
}