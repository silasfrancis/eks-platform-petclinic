output "bucket_arn" {
  value = {
    tf_state_bucket_arn = aws_s3_bucket.tf_state_bucket.arn
    alb_logs_bucket_arn = aws_s3_bucket.alb_logs.arn
    rds_export_bucket_arn = aws_s3_bucket.rds_export.arn
  }
}

output "bucket_ids"{
    value = {
        tf_state_bucket_id = aws_s3_bucket.tf_state_bucket.id
        alb_logs_bucket_id = aws_s3_bucket.alb_logs.id
        rds_export_bucket_id = aws_s3_bucket.rds_export.id
    }
}

output "bucket_name" {
  value = {
    tf_state_bucket_name = aws_s3_bucket.tf_state_bucket.bucket
    alb_logs_bucket_name = aws_s3_bucket.alb_logs.bucket
    rds_export_bucket_name = aws_s3_bucket.rds_export.bucket
  }
}