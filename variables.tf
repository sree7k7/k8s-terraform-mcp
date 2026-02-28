variable region {
  type        = string
  default     = "eu-central-1"
  description = "AWS region"
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
  default     = ["eu-central-1a", "eu-central-1b"]
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

variable "karpenter_enable_spot_termination" {
  description = "Determines whether to enable native node termination handling"
  type        = bool
  default     = true
}

variable "karpenter_enable_instance_profile_creation" {
  description = "Determines whether Karpenter will be allowed to create the IAM instance profile (v1beta1) or if Terraform will (v1alpha1)"        
  type        = bool
  default     = true
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