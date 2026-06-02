data "aws_ssm_parameter" "eks_ami" {
  name = "/aws/service/eks/optimized-ami/${var.cluster_version}/amazon-linux-2023/arm64/standard/recommended/image_id"
}

locals {
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
  instance_type = "t4g.medium"
  image_id      = data.aws_ssm_parameter.eks_ami.value
  user_data = base64encode(local.node_user_data)
  update_default_version = true
  
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

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