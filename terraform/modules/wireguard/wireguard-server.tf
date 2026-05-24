resource "aws_instance" "wireguard_server" {
  ami = data.aws_ami.al2023_arm.id
  instance_type = "t4g.micro"
  subnet_id = var.public_subnet_id
  vpc_security_group_ids  = [var.wireguard_sg_id]
  iam_instance_profile = aws_iam_instance_profile.wireguard_server_profile.name 
  associate_public_ip_address = false
  source_dest_check = false

  metadata_options {
    http_tokens                 = "required"  
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
  }
  root_block_device {
    encrypted = true
    kms_key_id = var.data_storage_kms_key_arn
    volume_size = 30
    volume_type = "gp3"
  }
  tags = {
    Name = "wireguard-server"
    resource = "ec2"
  }

  lifecycle {
    # prevent_destroy = true
    ignore_changes = [user_data, associate_public_ip_address] 
  }
}