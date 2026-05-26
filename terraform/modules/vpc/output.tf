output "vpc_id" {
  value = aws_vpc.main_vpc.id
}

output "vpc_cidr_block" {
  value = aws_vpc.main_vpc.cidr_block
}

output "public_subnet_ids" {
  value = [for subnet in aws_subnet.public : subnet.id]
}

output "private_subnet_ids" {
  value = [for subnet in aws_subnet.private : subnet.id]
}

output "data_subnet_ids" {
  value = [for subnet in aws_subnet.data : subnet.id]
}