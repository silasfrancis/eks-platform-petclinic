output "vpc_id" {
  value = aws_vpc.main_vpc.id
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
    nlb_external = aws_security_group.nlb_external.id
    nlb_internal = aws_security_group.nlb_internal.id
    wireguard_server = aws_security_group.wireguard_server.id
    eks_node = aws_security_group.eks_node.id
    rds = aws_security_group.rds.id
  }
}