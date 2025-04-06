provider "aws" {
  region = "ap-south-1"
}

resource "aws_vpc" "terraform_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "OnFinance-vpc"
  }
}

# Public Subnets
resource "aws_subnet" "public_subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.terraform_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.terraform_vpc.cidr_block, 8, count.index)
  availability_zone       = element(["ap-south-1a", "ap-south-1b"], count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "OnFinance--public-subnet-${count.index}"
  }
}

# Private Subnets
resource "aws_subnet" "private_subnet" {
  count             = 2
  vpc_id            = aws_vpc.terraform_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.terraform_vpc.cidr_block, 8, count.index + 2)
  availability_zone = element(["ap-south-1a", "ap-south-1b"], count.index)

  tags = {
    Name = "OnFinance--private-subnet-${count.index}"
  }
}

resource "aws_internet_gateway" "terraform_igw" {
  vpc_id = aws_vpc.terraform_vpc.id

  tags = {
    Name = "OnFinance--igw"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "terraform_nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_subnet[0].id

  tags = {
    Name = "OnFinance--nat"
  }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.terraform_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.terraform_igw.id
  }

  tags = {
    Name = "OnFinance--public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.terraform_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.terraform_nat.id
  }

  tags = {
    Name = "OnFinance--private-rt"
  }
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.private.id
}

# Security Groups

resource "aws_security_group" "terraform_cluster_sg" {
  vpc_id = aws_vpc.terraform_vpc.id

  #Outgoing
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "OnFinance-cluster-sg"
  }
}

resource "aws_security_group" "terraform_node_sg" {
  vpc_id = aws_vpc.terraform_vpc.id

  #Incoming
  ingress {
    from_port   = 22 #SSH
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80 #HTTP
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443 #HTTPS
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "OnFinance--node-sg"
  }
}

# IAM Roles and Policies

resource "aws_iam_role" "terraform_cluster_role" {
  name = "terraform-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "eks.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "terraform_cluster_role_policy" {
  role       = aws_iam_role.terraform_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "terraform_node_group_role" {
  name = "terraform-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "terraform_node_group_role_policy" {
  role       = aws_iam_role.terraform_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "terraform_node_group_cni_policy" {
  role       = aws_iam_role.terraform_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "terraform_node_group_registry_policy" {
  role       = aws_iam_role.terraform_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "terraform_node_group_monitoring_policy" {
  role       = aws_iam_role.terraform_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# EKS Cluster and Node Group

resource "aws_eks_cluster" "terraform" {
  name     = "terraform-cluster"
  role_arn = aws_iam_role.terraform_cluster_role.arn

  vpc_config {
    subnet_ids         = aws_subnet.private_subnet[*].id
    security_group_ids = [aws_security_group.terraform_cluster_sg.id]
  }
}

resource "aws_eks_node_group" "terraform" {
  cluster_name    = aws_eks_cluster.terraform.name
  node_group_name = "terraform-node-group"
  node_role_arn   = aws_iam_role.terraform_node_group_role.arn
  subnet_ids      = aws_subnet.private_subnet[*].id

  scaling_config {
    desired_size = 2
    max_size     = 5
    min_size     = 1
  }

  instance_types = ["t2.medium"]

  remote_access {
    ec2_ssh_key               = var.ssh_key_name
    source_security_group_ids = [aws_security_group.terraform_node_sg.id]
  }
}

#RDS

resource "aws_db_subnet_group" "mysql_subnet_group" {
  name       = "mysql-subnet-group"
  subnet_ids = aws_subnet.private_subnet[*].id

  tags = {
    Name = "MySQL Subnet Group"
  }
}

resource "aws_security_group" "mysql_sg" {
  name   = "mysql-sg"
  vpc_id = aws_vpc.terraform_vpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.terraform_node_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "MySQL Security Group"
  }
}

resource "aws_db_instance" "mysql" {
  identifier              = "onfinance-mysql-db"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  username                = var.db_username
  password                = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.mysql_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.mysql_sg.id]
  skip_final_snapshot     = true
  publicly_accessible     = true
  deletion_protection     = false

  tags = {
    Name = "MySQL-RDS"
  }
}

#ECR

resource "aws_ecr_repository" "onfinance_backend" {
  name = "onfinance-backend"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "OnFinance ECR"
  }
}
