
## important:
## This Terraform configuration sets up an EKS cluster with Karpenter for dynamic node provisioning, and also installs the kube-prometheus-stack for monitoring. It uses the AWS provider to manage resources in your AWS account, and the Kubernetes provider to interact with the EKS cluster. 1
## The ec2 instance are in public subnets and have associatePublicIPAddress set to true, which allows them to have public IPs for direct internet access. This is useful for learning and experimentation, but in production environments, you would typically place nodes in private subnets without public IPs for better security.

provider "aws" {
  region = var.region
}

terraform {
  backend "s3" {
    key            = "eks/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "terraform-locks"
  }
}

# Fetch the current account ID dynamically
data "aws_caller_identity" "current" {}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.region]
  }
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
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.region]
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

  enable_nat_gateway = false 
  single_nat_gateway = false 
  map_public_ip_on_launch = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
    "karpenter.sh/discovery" = var.cluster_name
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}

# 2. The Cluster Layer
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.10.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  # Network settings, connects the cluster to the VPC
  # Place nodes and the control plane in private subnets for security
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.public_subnets
  control_plane_subnet_ids = module.vpc.public_subnets

  # Access Entries (Modern Auth)
  enable_cluster_creator_admin_permissions = true # Grants you (the creator) of the cluster admin permissions (Best Practice for initial setup)
  cluster_endpoint_public_access           = true # Allows access to the cluster API from the internet (Required for EKS Anywhere / Remote Management)
  cluster_endpoint_private_access          = true # Allows access to the cluster API from within the VPC (Best Practice for security)

  cloudwatch_log_group_retention_in_days = 1

  # OIDC Identity provider (Required for IRSA / Service Accounts)
  enable_irsa = true

  # This section explicitly enables KMS encryption for Kubernetes secrets,
  # which is a security best practice. It also gives you control over the key's lifecycle.
  # When you run `terraform destroy`, AWS KMS keys are not deleted immediately
  # but are scheduled for deletion after a "deletion window" (7-30 days).
  # This is a safety feature. By setting `kms_key_deletion_window_in_days` to 7,
  # you can speed up the deletion process in non-production environments.
  cluster_encryption_config = {
    resources = ["secrets"]
  }
  kms_key_deletion_window_in_days = 7

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
      max_size     = 2
      desired_size = 1

      instance_types = ["t3.medium"]
      capacity_type  = "SPOT" # use SPOT for cost savings in dev/learning environments, switch to ON_DEMAND for production workloads
      
      # Ensure nodes have enough disk space
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 20
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
  version = "~> 1.16" 

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  # 1. Install Karpenter
  enable_karpenter = true

  karpenter = {
    chart_version       = "1.0.0" 
    repository_username = "public.ecr.aws/karpenter"
    repository_password = ""      
    values = [yamlencode({
      replicas = 1 
    })]
  }
  
  # Creates the IAM Role & Instance Profile for Karpenter nodes
  karpenter_node = {
    create                   = true
    iam_role_use_name_prefix = false
    iam_role_name            = "KarpenterNodeRole-${module.eks.cluster_name}"
  }

  # RESTORED: Required for handling Spot instance terminations safely
  karpenter_sqs = {
    create = true
  }

  # 2. Install Prometheus & Grafana
  enable_kube_prometheus_stack = true
  
  kube_prometheus_stack = {
    namespace        = "monitoring"
    create_namespace = true
    values = [yamlencode({
      alertmanager = { enabled = false } 
    })]
  }
}

# 1. This reads your file and automatically splits it into separate documents
data "kubectl_file_documents" "karpenter_manifests" {
  content = file("${path.module}/karpenter.yaml")
}

# 2. This loops through the split documents and applies them one by one
resource "kubectl_manifest" "karpenter_resources" {
  for_each  = data.kubectl_file_documents.karpenter_manifests.manifests
  yaml_body = each.value

  # Still strictly waiting for Karpenter to be installed first
  depends_on = [module.eks_blueprints_addons]
}

resource "null_resource" "update_kubeconfig" {
  depends_on = [module.eks]

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
  }
}

# Tells the EKS Control Plane to allow Karpenter nodes to join the cluster
resource "aws_eks_access_entry" "karpenter_node_access" {
  cluster_name  = module.eks.cluster_name
  principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/KarpenterNodeRole-${module.eks.cluster_name}"
  type          = "EC2_LINUX"
}