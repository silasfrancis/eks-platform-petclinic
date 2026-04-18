resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    Name = "default-security-group"
    resource = "vpc"
  }
}

resource "aws_security_group" "nlb-external" {
  description = "Security group for NLB external"
  name = "${var.env}-nlb-external-security_group"
  vpc_id = aws_vpc.main_vpc.id
  tags = { 
    resource = "vpc"
  }
}

resource "aws_security_group" "nlb-internal" {
  description = "Security group for NLB internal"
  name = "${var.env}-nlb-internal-security_group"
  vpc_id = aws_vpc.main_vpc.id
  tags = { 
    resource = "vpc"
  }
}

resource "aws_security_group" "ec2" {
  description = "Security group for EC2 instances"
  name = "${var.env}-ec2-security_group"
  vpc_id = aws_vpc.main_vpc.id
  tags = {  
    resource = "vpc"
  }
}

resource "aws_security_group" "eks" {
  description = "Security group for EKS"
  name = "${var.env}-eks-security_group"
  vpc_id = aws_vpc.main_vpc.id
  tags = {  
    resource = "vpc"
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