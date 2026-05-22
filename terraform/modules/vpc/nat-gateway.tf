resource "aws_nat_gateway" "nat_1" {
  allocation_id = aws_eip.nat_eip_1.id
  subnet_id = aws_subnet.public_subnet_1.id
  tags = {
    resource = "vpc"
    Name = "${var.app}-${var.env}-nat-gateway-1"
  }
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "nat_2" {
  allocation_id = aws_eip.nat_eip_2.id
  subnet_id = aws_subnet.public_subnet_2.id
  tags = {
    resource = "vpc"
    Name = "${var.app}-${var.env}-nat-gateway-2"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "private_rt_1" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_1.id
  }

  tags = { 
    resource = "vpc"
    Name = "${var.app}-${var.env}-private-route-table-1"
    }
}

resource "aws_route_table" "private_rt_2" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_2.id
  }

  tags = { 
    resource = "vpc"
    Name = "${var.app}-${var.env}-private-route-table-2"
    }
}

resource "aws_route_table_association" "private_subnet_association_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt_1.id
}

resource "aws_route_table_association" "private_subnet_association_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_rt_2.id
}