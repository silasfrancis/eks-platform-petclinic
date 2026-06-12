# Route Tables
#
# One public route table shared by all public subnets, routing 0.0.0.0/0 to
# the IGW. Private route tables are created one-per-NAT-gateway (for
# independent egress paths per AZ); if only one NAT gateway exists, all
# private subnets share that single route table — otherwise each private
# subnet is matched to the NAT gateway/route table in the same AZ.

# Public Route Table — routes internet-bound traffic to the IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(
    {
      Name = "${var.vpc_name_prefix}-${var.env}-public-route-table"
    },
    var.extended_tags
  )
}

# Public Route Table Associations
resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Private Route Tables (One per public subnet/NAT for independent paths)
# Each routes 0.0.0.0/0 to the NAT gateway in the same AZ
resource "aws_route_table" "private" {
  for_each = aws_nat_gateway.nat

  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = each.value.id
  }

  tags = merge(
    {
      Name = "${var.vpc_name_prefix}-${var.env}-private-route-table-${index(local.nat_azs, each.key) + 1}"
    },
    var.extended_tags
  )
}

# Private Route Table Associations
# If there's only one NAT gateway (and thus one private route table), all
# private subnets use it. Otherwise, match each private subnet to the route
# table in its own AZ.
resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id = each.value.id

  route_table_id = (
    length(aws_route_table.private) == 1
    ? values(aws_route_table.private)[0].id
    : aws_route_table.private[each.key].id
  )
}