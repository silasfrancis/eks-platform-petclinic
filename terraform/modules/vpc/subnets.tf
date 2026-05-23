# Public Subnets
resource "aws_subnet" "public" {
  for_each          = toset(local.target_azs)
  vpc_id            = aws_vpc.main_vpc.id
  availability_zone = each.value
  cidr_block        = "${local.network_prefix}.${index(local.target_azs, each.value) + 1}.0/24"

  tags = {
    Tier     = "public"
    resource = "vpc"
    Name     = "${var.app}-${var.env}-public-subnet-${index(local.target_azs, each.value) + 1}"
  }

  lifecycle { ignore_changes = [tags, tags_all] }
}

# Private Subnets
resource "aws_subnet" "private" {
  for_each          = toset(local.target_azs)
  vpc_id            = aws_vpc.main_vpc.id
  availability_zone = each.value
  cidr_block        = "${local.network_prefix}.${index(local.target_azs, each.value) + 11}.0/24"

  tags = {
    Tier     = "private"
    resource = "vpc"
    Name     = "${var.app}-${var.env}-private-subnet-${index(local.target_azs, each.value) + 1}"
  }

  lifecycle { ignore_changes = [tags, tags_all] }
}

# Data Subnets
resource "aws_subnet" "data" {
  for_each          = toset(local.target_azs)
  vpc_id            = aws_vpc.main_vpc.id
  availability_zone = each.value
  cidr_block        = "${local.network_prefix}.${index(local.target_azs, each.value) + 21}.0/24"

  tags = {
    Tier     = "data"
    resource = "vpc"
    Name     = "${var.app}-${var.env}-data-subnet-${index(local.target_azs, each.value) + 1}"
  }

  lifecycle { ignore_changes = [tags, tags_all] }
}