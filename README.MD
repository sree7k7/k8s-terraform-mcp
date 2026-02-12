```
eks-terraform-project/
├── main.tf        # The Brain: Where the resources are actually defined.
├── variables.tf   # The Dials: Settings you can change (like region or cluster name).
├── outputs.tf     # The Receipt: Information Terraform gives back (like the Cluster Endpoint).
└── versions.tf    # The Rules: Specifies which version of Terraform/AWS to use.
```


## Blueprint

```
source  = "terraform-aws-modules/eks/aws"
```

## Security & Access
enable_cluster_creator_admin_permissions = true: This ensures that you (the person running the Terraform command) actually have permission to log in and control the cluster after it is created.
cluster_endpoint_public_access = true: This opens a secure door on the internet so you can send commands (using kubectl) from your laptop.
cluster_endpoint_private_access = true: This opens a door inside your private network so your worker nodes can talk to the brain without going out to the public internet.

## permissions

IRSA enabled, e.g: applications inside your cluster can read AWS resources

## Essential Utilities

coredns: It helps applications find each other by name (e.g., "database") instead of IP address.
kube-proxy: It handles network rules on each node.
vpc-cni: It allows your Kubernetes pods to have real AWS IP addresses inside your VPC.

## Karpenter

Karpenter is high performace auto-scaler, it will instantly launches the exact right size servers to handle the work done.
Karpenter needs permission to create and destroy servers
