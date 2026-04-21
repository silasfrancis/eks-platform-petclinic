resource "aws_instance" "wireguard_server" {
  ami = data.aws_ami.al2023_arm.id
  instance_type = "t4g.micro"
  subnet_id = var.public_subnet_id
  vpc_security_group_ids  = [var.wireguard_server_security_group_id]
  iam_instance_profile = var.wireguard_server_instance_profile 
  associate_public_ip_address = false
  source_dest_check = false
  user_data = file("${path.module}/templates/user-data.sh")
  user_data_replace_on_change = false

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
    Name = "${var.env}-${var.app}-wireguard"
    resource = "ec2"
  }

  lifecycle {
    # prevent_destroy = true
    ignore_changes = [user_data, associate_public_ip_address] 
  }
}