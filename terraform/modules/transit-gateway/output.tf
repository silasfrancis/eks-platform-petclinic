output "transit_gateway_id" {
  value       = aws_ec2_transit_gateway.main.id
}

output "transit_gateway_arn" {
  value       = aws_ec2_transit_gateway.main.arn
}

output "wireguard_tgw_attachment_id" {
  value       = aws_ec2_transit_gateway_vpc_attachment.wireguard.id
}

# output "spoke_tgw_attachment_ids" {
#   description = "Map of spoke environments to their respective TGW attachment IDs"
#   value = {
#     for k, v in aws_ec2_transit_gateway_vpc_attachment.spokes : k => v.id
#   }
# }

# output "tgw_route_table_ids" {
#   description = "Map of all created TGW Route Table IDs for verification or peering tracking"
#   value = {
#     wireguard = aws_ec2_transit_gateway_route_table.wireguard.id
#     dev       = aws_ec2_transit_gateway_route_table.spokes["dev"].id
#     prod      = aws_ec2_transit_gateway_route_table.spokes["prod"].id
#   }
# }