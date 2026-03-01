variable region {
  type        = string
  default     = "us-east-1"
  description = "AWS region"
}

variable git_role_name {
  type        = string
  default     = "aws-to-github"
  description = "IAM Role name for GitHub Actions to assume for cluster access"
}

variable cluster_name {
  type        = string
  default     = "edge-cluster"
  description = "EKS Cluster name"
}

variable cluster_version {
  type        = string
  default     = "1.35"
  description = "EKS Cluster Version"
}

variable vpc_cidr {
  type        = string
  default     = "10.0.0.0/16"
  description = "VPC CIDR"
}

variable vpc_azs {
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
  description = "VPC AZs"
}


## Karpenter Settings
variable "enable_karpenter" {
  description = "Enable Karpenter controller add-on"
  type        = bool
  default     = false
}

variable "karpenter" {
  description = "Karpenter add-on configuration values"
  type        = any
  default     = {}
}

variable "karpenter_sqs" {
  description = "Karpenter SQS queue for native node termination handling configuration values"
  type        = any
  default     = {}
}

variable "karpenter_node" {
  description = "Karpenter IAM role and IAM instance profile configuration values"
  type        = any
  default     = {}
}