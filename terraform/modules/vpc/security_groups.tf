resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    Name = "default-security-group"
    resource = "vpc"
  }
}

resource "aws_security_group" "nlb_external" {
  description = "Security group for NLB external"
  name = "${var.env}-nlb-external-security_group"
  vpc_id = aws_vpc.main_vpc.id
  tags = { 
    resource = "vpc"
  }
}

resource "aws_security_group" "nlb_internal" {
  description = "Security group for NLB internal"
  name = "${var.env}-nlb-internal-security_group"
  vpc_id = aws_vpc.main_vpc.id
  tags = { 
    resource = "vpc"
  }
}

resource "aws_security_group" "wireguard_server" {
  description = "Security group for wireguard server"
  name = "${var.env}-wireguard-server-security_group"
  vpc_id = aws_vpc.main_vpc.id
  tags = {  
    resource = "vpc"
  }
}

resource "aws_security_group" "eks_node" {
  description = "Security group for EKS Nodes"
  name = "${var.env}-eks-security_group"
  vpc_id = aws_vpc.main_vpc.id
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

resource "aws_security_group" "rds" {
  description = "Security group for RDS instances"
  name = "${var.env}-rds-security_group"
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    resource = "vpc"   
  }
}