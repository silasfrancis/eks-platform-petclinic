output "vpc_id" {
  value = aws_vpc.main_vpc.id
}

output "subnets" {
  value = {
    public_subnet_1 = aws_subnet.public_subnet_1.id
    public_subnet_2 = aws_subnet.public_subnet_2.id
    private_subnet_1 = aws_subnet.private_subnet_1.id
    private_subnet_2 = aws_subnet.private_subnet_2.id
  }
}

output "public_subnets" {
  value = [
    aws_subnet.public_subnet_1.id,
    aws_subnet.public_subnet_2.id
  ]
}

output "private_subnets" {
  value = [
    aws_subnet.private_subnet_1.id,
    aws_subnet.private_subnet_2.id
  ]
}

output "security_group" {
  value = {
    nlb-external = aws_security_group.nlb-external.id
    nlb-internal = aws_security_group.nlb-internal.id
    ec2 = aws_security_group.ec2.id
    eks = aws_security_group.eks.id
    rds = aws_security_group.rds.id
  }
}