output "roles" {
  value = {
    cluster_role       = aws_iam_role.cluster_role.arn
    worker_node_role   = aws_iam_role.worker_node_role.arn
    jumphost_ec2_role = aws_iam_role.jumphost_ec2_role.arn
    rds_export_role     = aws_iam_role.rds_export_role.arn
    vpc_flow_logs_role  = aws_iam_role.vpc_flow_logs_role.arn
    rds_monitoring_role = aws_iam_role.rds_enhanced_monitoring.arn
  }
}

output "iam_instance_profile" {
  value = aws_iam_instance_profile.ec2_profile.name
}