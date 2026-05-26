# Public Subnets
resource "aws_subnet" "public" {
  for_each = {
    for index, az in local.public_azs :
    az => {
      index = index
      az    = az
    }
  }

  vpc_id            = aws_vpc.main_vpc.id
  availability_zone = each.value.az

  cidr_block = "${local.network_prefix}.${each.value.index + 1}.0/24"

  map_public_ip_on_launch = true

  tags = merge(
    {
      Tier = "public"
      Name = "${var.vpc_name_prefix}-${var.env}-public-subnet-${each.value.index + 1}"
    },
    var.extended_tags
  )

  lifecycle {
    ignore_changes = [
      tags,
      tags_all
    ]
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  for_each = {
    for index, az in local.private_azs :
    az => {
      index = index
      az    = az
    }
  }

  vpc_id            = aws_vpc.main_vpc.id
  availability_zone = each.value.az

  cidr_block = "${local.network_prefix}.${each.value.index + 11}.0/24"

  tags = merge(
    {
      Tier = "private"
      Name = "${var.vpc_name_prefix}-${var.env}-private-subnet-${each.value.index + 1}"

      "kubernetes.io/role/internal-elb" = "1"
    },
    var.extended_tags
  )

  lifecycle {
    ignore_changes = [
      tags,
      tags_all
    ]
  }
}
# Data Subnets
resource "aws_subnet" "data" {
  for_each = {
    for index, az in local.data_azs :
    az => {
      index = index
      az    = az
    }
  }

  vpc_id            = aws_vpc.main_vpc.id
  availability_zone = each.value.az

  cidr_block = "${local.network_prefix}.${each.value.index + 21}.0/24"

  tags = merge(
    {
      Tier = "data"
      Name = "${var.vpc_name_prefix}-${var.env}-data-subnet-${each.value.index + 1}"
    },
    var.extended_tags
  )

  lifecycle {
    ignore_changes = [
      tags,
      tags_all
    ]
  }
}
