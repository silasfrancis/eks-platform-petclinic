resource "aws_eip" "wireguard_server_eip" {
  domain   = "vpc"
  
  tags = {
    Name = "wireguard-server-eip"
    resource = "eip"
  }
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.wireguard_server.id
  allocation_id = aws_eip.wireguard_server_eip.id 
}
