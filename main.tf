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
