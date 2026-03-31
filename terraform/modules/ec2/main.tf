resource "aws_instance" "ec2_instance" {
  ami = data.aws_ami.al2023_arm.id
  instance_type = var.instance_type
  subnet_id = var.public_subnet_id
  vpc_security_group_ids  = [var.ec2_security_group_id]
  iam_instance_profile = var.iam_instance_profile 
  associate_public_ip_address = false
  source_dest_check = false
  user_data = templatefile("${path.module}/templates/user-data.sh", {
    cluster_name = var.cluster_name
    region       = var.region
    app          = var.app
  })
  user_data_replace_on_change = false

  metadata_options {
    http_tokens                 = "required"  
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
  }
  root_block_device {
    encrypted = true
    volume_size = 20
    volume_type = "gp3"
  }
  tags = {
    Name = "${var.env}-${var.app}-jumphost"
    resource = "ec2"
  }

  lifecycle {
    ignore_changes = [user_data] 
  }
}