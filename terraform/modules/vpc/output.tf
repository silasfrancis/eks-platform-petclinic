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

output "public_route_table_id" {
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "list of all private route table Ids"
  value       = [for rt in aws_route_table.private : rt.id]
}

output "all_route_table_ids" {
  description = "A unified list containing all public and private route table IDs" # a much needed output to pass to the vpc peering module
  value       = concat([aws_route_table.public.id], [for rt in aws_route_table.private : rt.id])
}