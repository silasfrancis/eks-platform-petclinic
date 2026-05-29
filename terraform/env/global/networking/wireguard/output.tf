output "vpc_id" {
  value = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  value = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "public_route_table_ids" {
  value = module.vpc.public_route_table_ids
}

output "wireguard_server_instance_id" {
  value = module.wireguard.instance_id
}

output "wireguard_server_instance_profile" {
  value = module.wireguard.instance_profile
}

output "wireguard_sg_id" {
  value = module.wireguard.security_group_id
}

output "wireguard_public_ip" {
  value = module.wireguard.public_ip
}