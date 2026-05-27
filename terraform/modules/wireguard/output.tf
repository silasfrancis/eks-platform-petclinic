output "wireguard_server_instance_id" {
  value = aws_instance.wireguard_server.id
}

output "wireguard_server_instance_profile" {
  value = aws_iam_instance_profile.wireguard_server_profile.name
}

output "wireguard_sg_id" {
  value = aws_security_group.wireguard_server.id
}