provider "aws" {
  region = var.region
}

# This tells Terraform how to talk to your new EKS cluster
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    # This uses your local AWS CLI to authenticate
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

# 1. Network Layer
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "eks-vpc"
  cidr = var.vpc_cidr

  azs             = var.vpc_azs
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true # Saves money in dev/learning environments

  # Tags required for Load Balancer Controller
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    "karpenter.sh/discovery" = var.cluster_name # Required for Karpenter to discover these subnets
  }
}

# 2. The Cluster Layer
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  # Network settings, connects the cluster to the VPC
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  # Access Entries (Modern Auth)
  enable_cluster_creator_admin_permissions = true # Grants you (the creator) of the cluster admin permissions (Best Practice for initial setup)
  cluster_endpoint_public_access           = true # Allows access to the cluster API from the internet (Required for EKS Anywhere / Remote Management)
  cluster_endpoint_private_access          = true # Allows access to the cluster API from within the VPC (Best Practice for security)

  # OIDC Identity provider (Required for IRSA / Service Accounts)
  enable_irsa = true

  # Standard EKS Add-ons (Best Practice to manage these here)
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  # 3. The Compute Layer
  eks_managed_node_groups = {
    initial = {
      min_size     = 1
      max_size     = 3
      desired_size = 2

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      
      # Ensure nodes have enough disk space
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 50
            volume_type           = "gp3"
            delete_on_termination = true
          }
        }
      }
    }
  }
}


module "eks_blueprints_addons" {
  source = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.16" # Always check for latest

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  # 1. Install Karpenter
  enable_karpenter = true

  # 2. Configure Karpenter Settings
  karpenter = {
    chart_version       = "1.0.0" # Use v1+ (The stable version)
    repository_username = "public.ecr.aws/karpenter"
    repository_password = ""      # Public repo, no password needed
  }
  
  # This creates the IAM Role Karpenter needs to launch EC2s on your behalf
  karpenter_enable_spot_termination          = true
  karpenter_enable_instance_profile_creation = true
}