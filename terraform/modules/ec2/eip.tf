resource "aws_eip" "jumphost_eip" {
  domain   = "vpc"
  
  tags = {
    Name = "${var.env}-${var.app}-jumphost-eip"
    resource = "eip"
  }
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.ec2_instance.id
  allocation_id = aws_eip.jumphost_eip.id
}
