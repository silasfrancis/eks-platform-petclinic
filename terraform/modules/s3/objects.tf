resource "aws_s3_object" "tf_state_object" {
  bucket = aws_s3_bucket.tf_state_bucket.id
  key = "${var.app}/terraform.tfstate"
  tags = {
    resource = "s3"
  }
}
