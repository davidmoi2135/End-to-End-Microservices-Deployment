variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "project" {
  description = "Name prefix for resources"
  type        = string
  default     = "k3s-free"
}

variable "master_instance_type" {
  description = "Master EC2 type (c7i-flex.large = 2 vCPU / 4 GB; NOT free tier)"
  type        = string
  default     = "c7i-flex.large"
}

variable "worker_instance_type" {
  description = "Worker EC2 type (c7i-flex.large = 2 vCPU / 4 GB; NOT free tier)"
  type        = string
  default     = "c7i-flex.large"
}

variable "worker_count" {
  description = "Number of k3s worker nodes"
  type        = number
  default     = 2
}

variable "k3s_version" {
  description = "k3s version channel or pinned version"
  type        = string
  default     = "v1.30.5+k3s1"
}

variable "root_volume_size_gb" {
  description = "Root EBS volume per node (GB). Free tier total = 30GB across all instances."
  type        = number
  default     = 10
}

variable "ssh_public_key" {
  description = "Optional: existing SSH public key (e.g. file(\"~/.ssh/id_rsa.pub\")). If empty, Terraform generates a fresh key pair and saves it to ./k3s-key.pem."
  type        = string
  default     = ""
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH into nodes. Lock to your IP (e.g. 1.2.3.4/32) for safety."
  type        = string
  default     = "0.0.0.0/0"
}

variable "acm_certificate_arn" {
  description = "Optional ACM certificate ARN. If set, an HTTPS:443 listener is added to the ALB."
  type        = string
  default     = ""
}
