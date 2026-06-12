output "transit_gateway_id" {
  value       = module.transit_gateway.transit_gateway_id
}

output "transit_gateway_arn" {
  value       = module.transit_gateway.transit_gateway_arn
}

output "wireguard_tgw_attachment_id" {
  value       = module.transit_gateway.wireguard_tgw_attachment_id
}

output "spoke_tgw_attachment_ids" {
  description = "Map of spoke environments to their respective TGW attachment IDs"
  value = module.transit_gateway.spoke_tgw_attachment_ids
}

output "tgw_route_table_ids" {
  description = "Map of all created TGW Route Table IDs for verification or peering tracking"
  value = module.transit_gateway.tgw_route_table_ids
}