variable region {
  type        = string
  default     = "eu-central-1"
  description = "AWS region"
}

variable cluster_name {
  type        = string
  default     = "edge-cluster"
  description = "EKS Cluster Name"
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
