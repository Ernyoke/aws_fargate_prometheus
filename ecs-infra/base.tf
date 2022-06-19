# Create a VPC
resource "aws_vpc" "base_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    "Name" = "base-vpc"
  }
}

# Create a public subnet
resource "aws_subnet" "public_subnet" {
  count             = 2
  availability_zone = element(data.aws_availability_zones.azs.names, count.index)
  vpc_id            = aws_vpc.base_vpc.id
  cidr_block        = cidrsubnet("10.0.0.0/16", 8, count.index)

  tags = {
    Name = "Public Subnet"
  }
}

# Create a private subnet
resource "aws_subnet" "private_subnet" {
  count             = 2
  availability_zone = element(data.aws_availability_zones.azs.names, count.index)
  vpc_id            = aws_vpc.base_vpc.id
  cidr_block        = cidrsubnet("10.0.0.0/16", 8, length(aws_subnet.public_subnet[*]) + count.index)

  tags = {
    Name = "Private Subnet"
  }
}

# Create an internet gateway for the VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.base_vpc.id

  tags = {
    Name = "Internet Gateway"
  }
}

# Create a NAT gateway for the private subnet and place it into the public subnet
resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.ngw_eip.allocation_id
  subnet_id     = aws_subnet.public_subnet[0].id

  tags = {
    Name = "NAT Gateway"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.igw]
}

# Public IP for the NAT gateway
resource "aws_eip" "ngw_eip" {
  tags = {
    "Name" = "NAT Gateway IP"
  }
}

# Route traffic from the public subnet to the internet gateway
resource "aws_route_table" "public_rt" {
  count  = 2
  vpc_id = aws_vpc.base_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Public Subnet Route Table"
  }
}

resource "aws_route_table_association" "public_rt_association" {
  count          = 2
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_rt[count.index].id
}

# Route traffic from the private subnet to the NAT gateway
resource "aws_route_table" "private_rt" {
  count  = 2
  vpc_id = aws_vpc.base_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.ngw.id
  }

  tags = {
    Name = "Private Subnet Route Table"
  }
}

resource "aws_route_table_association" "private_rt_association" {
  count          = 2
  subnet_id      = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.private_rt[count.index].id
}