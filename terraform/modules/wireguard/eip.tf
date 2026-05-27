resource "aws_eip" "wireguard_server" {
  domain   = "vpc"
  
  tags = merge({
    Name = "wireguard-server-eip"
  }, var.extended_tags)
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.wireguard_server.id
  allocation_id = aws_eip.wireguard_server.id 
}
