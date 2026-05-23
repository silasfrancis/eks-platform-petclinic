# NAT Gateways (placed dynamically inside each corresponding public subnet)
resource "aws_nat_gateway" "nat" {
  for_each      = aws_subnet.public
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = each.value.id

  tags = {
    Name     = "${var.app}-${var.env}-nat-gateway-${index(local.target_azs, each.key) + 1}"
    resource = "vpc"
  }

  depends_on = [aws_internet_gateway.igw]
}