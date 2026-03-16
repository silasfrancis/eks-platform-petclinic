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

output "security_group" {
  value = {
    alb = aws_security_group.alb.id
    ec2 = aws_security_group.ec2.id
  }
}