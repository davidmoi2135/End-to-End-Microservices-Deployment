provider "aws" {
   region=var.aws_region
}
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] 

  filter {
    name   = "name"
 
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
resource "aws_security_group" "k8s_sg" {
  name        = "k8s_security_group"
  description = "Security group for Kubernetes cluster"

 ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_instance" "master" {
  count=1
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.master_instance_type
  key_name = var.aws_access_key
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]
  root_block_device {
    volume_size =30
    volume_type = "gp3"
  }
    tags = { Name = "k8s-master-${count.index + 1}" }
 
}
resource "aws_instance" "workers" {
  count=2
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.worker_instance_type
  key_name = var.aws_access_key
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]
  root_block_device {
        volume_size = 30
        volume_type = "gp3"
    }
    tags = {
        Name = "k8s-worker-${count.index + 1}"
  }
}
resource "local_file" "kubespray_inventory" {
  content = templatefile("${path.module}/templates/inventory.tmpl", {
    master_ips         = aws_instance.master[*].public_ip
    master_private_ips = aws_instance.master[*].private_ip
    worker_ips         = aws_instance.workers[*].public_ip
    worker_private_ips = aws_instance.workers[*].private_ip
  })
  filename = "../inventory/mycluster/hosts.yaml"
}