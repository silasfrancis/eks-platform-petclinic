
output "transit_gateway_id" {
  value = aws_ec2_transit_gateway.main.id
}

output "dev_tgw_route_table_id" {
  value = aws_ec2_transit_gateway_route_table.dev.id
}

output "prod_tgw_route_table_id" {
  value = aws_ec2_transit_gateway_route_table.prod.id
}

output "dev_tgw_attachment_id" {
  value = aws_ec2_transit_gateway_vpc_attachment.dev.id
}

output "prod_tgw_attachment_id" {
  value = aws_ec2_transit_gateway_vpc_attachment.prod.id
}

output "wireguard_tgw_attachment_id" {
  value = aws_ec2_transit_gateway_vpc_attachment.wireguard.id
}