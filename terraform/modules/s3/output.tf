output "bucket_arn" {
  value = {
    tf_state_bucket_arn = aws_s3_bucket.tf_state_bucket.arn
    rds_export_bucket_arn = aws_s3_bucket.rds_export.arn
    loki_bucket_arn = aws_s3_bucket.loki.arn
    velero_bucket_arn = aws_s3_bucket.velero.arn
  }
}

output "bucket_ids"{
    value = {
        tf_state_bucket_id = aws_s3_bucket.tf_state_bucket.id
        rds_export_bucket_id = aws_s3_bucket.rds_export.id
        loki_bucket_id = aws_s3_bucket.loki.id
        velero_bucket_id = aws_s3_bucket.velero.id
    }
}

output "bucket_name" {
  value = {
    tf_state_bucket_name = aws_s3_bucket.tf_state_bucket.bucket
    rds_export_bucket_name = aws_s3_bucket.rds_export.bucket
    loki_bucket_name = aws_s3_bucket.loki.bucket
    velero_bucket_name = aws_s3_bucket.velero.bucket
  }
}