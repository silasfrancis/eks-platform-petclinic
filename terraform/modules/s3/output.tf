output "bucket_arns" {
  description = "Map of all application bucket ARNs"
  value       = { for k, v in aws_s3_bucket.this : k => v.arn }
}

output "bucket_ids" {
  description = "Map of all application bucket IDs"
  value       = { for k, v in aws_s3_bucket.this : k => v.id }
}

output "bucket_names" {
  description = "Map of all application bucket names"
  value       = { for k, v in aws_s3_bucket.this : k => v.bucket }
}