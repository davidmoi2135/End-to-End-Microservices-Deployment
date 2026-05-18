variable "aws_region" {
  description = "AWS region (us-east-1 for AWS Academy Learner Lab)"
  type        = string
  default     = "us-east-1"
}

# SSH key name - use "vockey" for AWS Academy Learner Lab
variable "ssh_key_name" {
  description = "EC2 key pair name (use 'vockey' for AWS Academy Learner Lab)"
  type        = string
  default     = "vockey"
}

# VPC ID from AWS Academy
variable "vpc_id" {
  description = "VPC ID for the cluster (default VPC in us-east-1)"
  type        = string
  default     = "vpc-0b2f5a587f2209531"
}

# Master node subnet (us-east-1a)
variable "master_subnet_id" {
  description = "Subnet ID for the k3s master node"
  type        = string
  default     = "subnet-0229a6bb52d06fce7"
}

# Worker node subnets (spread across 2 AZs for HA)
variable "worker_subnet_ids" {
  description = "List of subnet IDs for k3s worker nodes"
  type        = list(string)
  default     = [
    "subnet-0c98cb9b3a21fb5e8",  # us-east-1b
    "subnet-0ed06789242c1b57c",   # us-east-1c
  ]
}

variable "master_instance_type" {
  description = "EC2 instance type for k3s master node (t3.medium = 2 vCPU, 4GB RAM)"
  type        = string
  default     = "t3.medium"
}

variable "worker_instance_type" {
  description = "EC2 instance type for k3s worker nodes (t3.medium = 2 vCPU, 4GB RAM)"
  type        = string
  default     = "t3.medium"
}

variable "k3s_version" {
  description = "k3s version channel or pinned version"
  type        = string
  default     = "v1.30.5+k3s1"
}

variable "worker_count" {
  description = "Number of k3s worker nodes (max 2 to stay within 9 instance limit)"
  type        = number
  default     = 2
}