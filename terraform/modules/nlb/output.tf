output "nlb_external_sg_id" {
  value = aws_security_group.nlb["external"].id
}

output "nlb_internal_sg_id" {
  value = aws_security_group.nlb["internal"].id
}