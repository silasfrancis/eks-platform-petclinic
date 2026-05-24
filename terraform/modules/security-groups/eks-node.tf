resource "aws_security_group" "eks_node" {
  description = "Security group for EKS Nodes"
  name = "${var.app}-${var.env}-eks-security_group"
  vpc_id = var.vpc_id
  tags = {  
    resource = "vpc"
  }

  lifecycle {
    ignore_changes = [
      tags,
      tags_all,
    ]
  }
}

resource "aws_vpc_security_group_ingress_rule" "nodes_internal" {
  description       = "Allow nodes to communicate with each other"
  security_group_id = aws_security_group.eks_node.id
  ip_protocol       = "-1" 
  referenced_security_group_id = aws_security_group.eks_node.id
}

resource "aws_vpc_security_group_ingress_rule" "external_nlb_to_node" {
  description                  = "Allow External NLB to reach node port for HTTP"
  security_group_id            = aws_security_group.eks_node.id
  from_port                    = 30000
  to_port                      = 32767
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.nlb["external"].id
}

# Add this
resource "aws_vpc_security_group_ingress_rule" "internal_nlb_to_node" {
  description                  = "Allow Internal NLB to reach node port for HTTP"
  security_group_id            = aws_security_group.eks_node.id
  from_port                    = 30000
  to_port                      = 32767
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.nlb["internal"].id
}

resource "aws_vpc_security_group_ingress_rule" "nlb_to_nodes_healthcheck" {
  description       = "Allow NLB to reach node port for Istio health check"
  security_group_id = aws_security_group.eks_node.id
  
  from_port         = 32319
  to_port           = 32319
  ip_protocol       = "tcp"
  referenced_security_group_id = aws_security_group.nlb["external"].id
}

resource "aws_vpc_security_group_ingress_rule" "internal_nlb_healthcheck" {
  description                  = "Allow Internal NLB to reach node port for Istio health check"
  security_group_id            = aws_security_group.eks_node.id
  from_port                    = 32319
  to_port                      = 32319
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.nlb["internal"].id
}

resource "aws_vpc_security_group_egress_rule" "nodes_to_internet" {
  description       = "Allow nodes to reach AWS APIs and Internet"
  security_group_id = aws_security_group.eks_node.id
  
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  
  tags = {
    Name = "node-egress-all"
  }
}