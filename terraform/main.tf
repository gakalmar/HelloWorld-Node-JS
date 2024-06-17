# PROVIDER SETUP
provider "aws" {
  region = "eu-west-2"
}

provider "kubernetes" {
  host                   = aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.eks.certificate_authority[0].data)
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

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.eks_vpc.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.eks_vpc.id
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_eip" "nat" {
  count = 2
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  count         = 2
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.eks_subnet[count.index].id  # NAT Gateway in the public subnets

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "private" {
  count = 2
  vpc_id = aws_vpc.eks_vpc.id
}

resource "aws_route" "private_nat" {
  count                  = 2
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[count.index].id
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.eks_subnet[count.index + 2].id  # Associate private subnets
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_subnet" "eks_subnet" {
  count = 4  # Adjusting count to 4 for two public and two private subnets

  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = count.index < 2 ? "10.0.${count.index}.0/24" : "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index % 2]
  map_public_ip_on_launch = count.index < 2 ? true : false  # Public IP mapping for public subnets only

  tags = {
    Name = "eks_subnet_${count.index < 2 ? "public" : "private"}_${count.index % 2}"
    "kubernetes.io/cluster/hello-world-eks-cluster" = "owned"
  }
}

resource "aws_route_table_association" "public" {
  count          = 2  # Only associate the first two subnets with the public route table
  subnet_id      = aws_subnet.eks_subnet[count.index].id
  route_table_id = aws_route_table.public.id
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
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # Allowing all traffic within the VPC
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

data "aws_eks_cluster_auth" "eks" {
  name = aws_eks_cluster.eks.name
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

resource "aws_iam_role" "eks_node" {
  name = "hello-world-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
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

resource "aws_iam_role_policy_attachment" "eks_AmazonEKSVPCResourceController" {
  role       = aws_iam_role.eks.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}

resource "aws_iam_role_policy_attachment" "eks_node_AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_node_AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_node_AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# NODE GROUP
resource "aws_eks_node_group" "eks_nodes" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "hello-world-eks-node-group"
  node_role_arn   = aws_iam_role.eks_node.arn

  # Use a string comparison to filter for private subnets
  subnet_ids      = [for s in aws_subnet.eks_subnet : s.id if can(regex("private", s.tags["Name"]))]

  instance_types  = ["t3.medium"]
  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  depends_on = [
    aws_eks_cluster.eks
  ]
}

# DEBUGGING
## cluster_endpoint should show an HTTPS URL:
output "cluster_endpoint" {
  value = aws_eks_cluster.eks.endpoint
}

## cluster_ca_certificate should be a large blob of Base64 text:
output "cluster_ca_certificate" {
  value = base64decode(aws_eks_cluster.eks.certificate_authority[0].data)
}

## cluster_token should be a JWT token:
output "cluster_token" {
  value = data.aws_eks_cluster_auth.eks.token
  sensitive = true
}

# DEFINE DEPLOYMENT AND A SERVICE:
resource "kubernetes_deployment" "helloworld-deployment" {
  metadata {
    name = "helloworld-app"
    labels = {
      app = "helloworld-app"
    }
  }

  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "helloworld-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "helloworld-app"
        }
      }

      spec {
        container {
          image = "891376988072.dkr.ecr.eu-west-2.amazonaws.com/helloworld-nodejs:1.0"
          name  = "helloworld"

          ports {
            container_port = 3000
          }

          resources {
            requests {
              cpu    = "100m"
              memory = "200Mi"
            }
            limits {
              cpu    = "200m"
              memory = "400Mi"
            }
          }
        }  
      }
    }
  }
}

resource "kubernetes_service" "helloworld-service" {
  metadata {
    name = "helloworld-service"
  }

  spec {
    selector = {
      app = "helloworld-app"
    }

    ports {
      name        = "http"
      port        = 80
      target_port = 3000
    }

    type = "LoadBalancer"
  }
}
