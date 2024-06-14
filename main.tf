# PROVIDER SETUP
provider "aws" {
  region = "eu-west-2"
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.eks.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.eks.token
  }
}

data "aws_availability_zones" "available" {}

# VPC / NETWORK CONFIG:
resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "eks_vpc"
  }
}

resource "aws_subnet" "eks_subnet" {
  count = 2
  vpc_id     = aws_vpc.eks_vpc.id
  cidr_block = count.index == 0 ? "10.0.1.0/24" : "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "eks_subnet_${count.index}"
  }
}

resource "aws_security_group" "eks_sg" {
  name   = "eks_sg"
  vpc_id = aws_vpc.eks_vpc.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# CREATE CLUSTER
resource "aws_eks_cluster" "eks" {
  name     = "hello-world-eks-cluster"
  role_arn = aws_iam_role.eks.arn

  vpc_config {
    subnet_ids         = aws_subnet.eks_subnet[*].id
    security_group_ids = [aws_security_group.eks_sg.id]
  }
  
  depends_on = [
    aws_iam_role_policy_attachment.eks_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks_AmazonEKSVPCResourceController,
  ]
}

# CREATE IAM ROLES AND POLICIES
resource "aws_iam_role" "eks" {
  name = "hello-world-eks-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_AmazonEKSClusterPolicy" {
  role       = aws_iam_role.eks.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# NODE GROUP
resource "aws_eks_node_group" "eks_nodes" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "hello-world-eks-node-group"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = aws_subnet.eks_subnet[*].id

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  depends_on = [
    aws_eks_cluster.eks
  ]
}
