resource "aws_instance" "ec2_instance" {
  ami = var.ami
  instance_type = var.instance_type
  subnet_id = var.private_subnet_id
  vpc_security_group_ids  = var.ec2_security_group_id
  iam_instance_profile = var.iam_instance_profile 
  associate_public_ip_address = false
  metadata_options {
    http_tokens                 = "required"  
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
  }
  root_block_device {
    encrypted = true
  }
  tags = {
    Name = "${var.tags}-instance"
  }
}