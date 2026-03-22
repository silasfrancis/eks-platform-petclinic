resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    Name = "default-security-group"
    resource = "vpc"
  }
}

resource "aws_security_group" "alb" {
  description = "Security group for ALB with restricted access"
  name = "${var.env}-alb-security_group"
  vpc_id = aws_vpc.main_vpc.id
  tags = { 
    resource = "vpc"
  }
}

resource "aws_security_group" "ec2" {
  description = "Security group for EC2 instances with restricted access"
  name = "${var.env}-ec2-security_group"
  vpc_id = aws_vpc.main_vpc.id
  tags = {  
    resource = "vpc"
  }
}

resource "aws_security_group" "eks" {
  description = "Security group for EKS instances with restricted access"
  name = "${var.env}-eks-security_group"
  vpc_id = aws_vpc.main_vpc.id
  tags = {  
    resource = "vpc"
  }
}

resource "aws_security_group" "rds" {
  description = "Security group for RDS instances with restricted access"
  name = "${var.env}-rds-security_group"
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    resource = "vpc"   
  }
}