resource "aws_vpc" "vpc" {
  enable_dns_hostnames = true
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.project}-vpc-${var.environment}"
  })
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.vpc.id
  count                   = length(var.public_subnets_cidr)
  cidr_block              = element(var.public_subnets_cidr, count.index).cidr
  availability_zone       = element(var.public_subnets_cidr, count.index).az
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = element(var.public_subnets_cidr, count.index).name
    Tier = "public"
  })
}

resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.vpc.id
  count                   = length(var.private_subnets_cidr)
  cidr_block              = element(var.private_subnets_cidr, count.index).cidr
  availability_zone       = element(var.private_subnets_cidr, count.index).az
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = element(var.private_subnets_cidr, count.index).name
    Tier = "private"
  })
}

resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(var.tags, {
    Name = "${var.project}-${var.account_id}-igw"
  })
}

resource "aws_eip" "nat_elastic_ip" {
  vpc        = true
  depends_on = [aws_internet_gateway.ig]
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_elastic_ip.id
  subnet_id     = element(aws_subnet.public_subnet.*.id, 0)
  depends_on    = [aws_internet_gateway.ig]

  tags = merge(var.tags, {
    Name = "${var.project}-${var.account_id}-nat"
  })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(var.tags, {
    Name = "${var.project}-private-route-table-${var.environment}"
  })
}

# Routing tables to route traffic for Public Subnet
resource "aws_route_table" "public" {
  depends_on = [aws_vpc.vpc]
  vpc_id     = aws_vpc.vpc.id

  tags = merge(var.tags, {
    Name = "${var.project}-public-route-table-${var.environment}"
  })
}

# Route for Internet Gateway
resource "aws_route" "public_internet_gateway" {
  depends_on             = [aws_internet_gateway.ig, aws_route_table.public]
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ig.id
}

# Route for NAT
resource "aws_route" "private_nat_gateway" {
  depends_on             = [aws_nat_gateway.nat, aws_route_table.private]
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

# Route table associations for both Public & Private Subnets
resource "aws_route_table_association" "public" {
  depends_on     = [aws_subnet.public_subnet, aws_route_table.public]
  count          = length(var.public_subnets_cidr)
  subnet_id      = element(aws_subnet.public_subnet.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  depends_on     = [aws_subnet.private_subnet, aws_route_table.private]
  count          = length(var.private_subnets_cidr)
  subnet_id      = element(aws_subnet.private_subnet.*.id, count.index)
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "default" {
  name        = "${var.project}-${aws_vpc.vpc.id}-default-sg"
  description = "Default security group. Allows all outbound and ssh from VPN cidr"
  vpc_id      = aws_vpc.vpc.id
  depends_on  = [
    aws_vpc.vpc
  ]

  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "TCP"
    cidr_blocks = [var.vpn_cidr]
  }

  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_flow_log" "flow_logs" {
  depends_on = [aws_cloudwatch_log_group.flow_log_group, aws_iam_role.flow_log_role, aws_vpc.vpc]

  iam_role_arn    = aws_iam_role.flow_log_role.arn
  log_destination = aws_cloudwatch_log_group.flow_log_group.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.vpc.id
}

resource "aws_iam_role" "flow_log_role" {
  name = "vpc-flow-log-writer-role-${var.environment}"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "vpc-flow-logs.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "flow_log_policy" {
  depends_on = [aws_iam_role.flow_log_role]

  name = "${aws_vpc.vpc.id}-flow-logs-policy"
  role = aws_iam_role.flow_log_role.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ],
        "Effect" : "Allow",
        "Resource" : "*"
      }
    ]
  }
  )
}

resource "aws_cloudwatch_log_group" "flow_log_group" {
  name              = var.flow_log_cloudwatch_group
  retention_in_days = 365
}