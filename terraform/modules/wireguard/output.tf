output "instance_id" {
  value = aws_instance.wireguard_server.id
}

output "instance_profile" {
  value = aws_iam_instance_profile.wireguard_server_profile.name
}

output "security_group_id" {
  value = aws_security_group.wireguard_server.id
}

output "public_ip" {
  description = "Public Elastic IP of the WireGuard server"
  value       = aws_eip.wireguard_server.public_ip
}