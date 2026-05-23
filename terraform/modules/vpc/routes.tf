# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name     = "${var.app}-${var.env}-public-route-table"
    resource = "vpc"
  }
}

# Public Route Table Associations
resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Private Route Tables (One per public subnet/NAT for independent paths)
resource "aws_route_table" "private" {
  for_each = aws_subnet.public
  vpc_id   = aws_vpc.main_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[each.key].id
  }

  tags = {
    Name     = "${var.app}-${var.env}-private-route-table-${index(local.target_azs, each.key) + 1}"
    resource = "vpc"
  }
}

# Private Route Table Associations
resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}