variable "aws_region"{
    description = "AWS region to deploy resources in"
    type=string
    default = "ap-southeast-1"
}
variable "aws_access_key"{
    description = "AWS access key for authentication"
    type=string
    default = "trinhkeypair-ap"
}
variable "master_instance_type"{
    description = "EC2 instance type for the master node"
    type=string
    default = "t3.medium"
}
variable "worker_instance_type"{
    description = "EC2 instance type for the worker nodes"
    type=string
    default = "t3.medium"
}