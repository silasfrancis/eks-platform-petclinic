output "eks_node_sg_id" {
  value = aws_security_group.eks_node.id
}

output "nlb_external_sg_id" {
  value = aws_security_group.nlb["external"].id
}

output "nlb_internal_sg_id" {
  value = aws_security_group.nlb["internal"].id
}

output "rds_sg_id" {
  value = aws_security_group.rds.id
}

output "wireguard_sg_id" {
  value = aws_security_group.wireguard.id
}