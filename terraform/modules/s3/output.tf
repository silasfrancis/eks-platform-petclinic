output "bucket_arn" {
  value = {
    tf_state_bucket_arn = aws_s3_bucket.tf_state_bucket.arn
    rds_export_bucket_arn = aws_s3_bucket.rds_export.arn
    loki_bucket_arn = aws_s3_bucket.loki_bucket.arn
    velero_bucket_arn = aws_s3_bucket.velero_bucket.arn
  }
}

output "bucket_ids"{
    value = {
        tf_state_bucket_id = aws_s3_bucket.tf_state_bucket.id
        rds_export_bucket_id = aws_s3_bucket.rds_export.id
        loki_bucket_id = aws_s3_bucket.loki_bucket.id
        velero_bucket_id = aws_s3_bucket.velero_bucket.id
    }
}

output "bucket_name" {
  value = {
    tf_state_bucket_name = aws_s3_bucket.tf_state_bucket.bucket
    rds_export_bucket_name = aws_s3_bucket.rds_export.bucket
    loki_bucket_name = aws_s3_bucket.loki_bucket.bucket
    velero_bucket_name = aws_s3_bucket.velero_bucket.bucket
  }
}