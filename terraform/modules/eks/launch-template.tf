data "aws_ssm_parameter" "eks_ami" {
  name = "/aws/service/eks/optimized-ami/${var.cluster_version}/amazon-linux-2023/arm64/standard/recommended/image_id"
}

resource "aws_launch_template" "eks_nodes" {
  name = "${var.env}-${var.app}-eks-node-template"
  description = "EKS node launch template for ${var.env}"
  instance_type = ["t4g.medium"]
  image_id      = data.aws_ssm_parameter.eks_ami.value
  
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
}