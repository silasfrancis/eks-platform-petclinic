output "db_identifier" {
 value = aws_db_instance.main.identifier 
}

output "rds_sg_id" {
  value = aws_security_group.rds.id
}