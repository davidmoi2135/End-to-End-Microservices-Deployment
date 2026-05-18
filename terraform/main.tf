terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  ami_id = "ami-00403f401ee6a4b98"
}

resource "random_password" "k3s_token" {
  length  = 48
  special = false
}

resource "aws_security_group" "k8s_sg" {
  name        = "k3s-academy-sg"
  description = "Security group for k3s cluster on AWS Academy Learner Lab"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ICMP (ping)"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Kubernetes API Server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP (Ingress Controller)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS (Ingress Controller)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "NodePort range (30000-32767)"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "All internal traffic"
    from_port  = 0
    to_port    = 0
    protocol   = "-1"
    self       = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "k3s-academy-sg"
  }
}

resource "aws_instance" "master" {
  count = 1

  ami           = local.ami_id
  instance_type = var.master_instance_type
  key_name      = var.ssh_key_name
  subnet_id     = var.master_subnet_id
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOT
    #!/bin/bash
    set -euxo pipefail

    sleep 10

    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
    PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

    echo "PUBLIC_IP=$PUBLIC_IP"
    echo "PRIVATE_IP=$PRIVATE_IP"

    curl -sfL https://get.k3s.io | \
      INSTALL_K3S_VERSION="${var.k3s_version}" \
      K3S_TOKEN="${random_password.k3s_token.result}" \
      sh -s - server \
        --write-kubeconfig-mode=644 \
        --tls-san="$PUBLIC_IP" \
        --tls-san="$PRIVATE_IP" \
        --bind-address=0.0.0.0 \
        --node-ip="$PRIVATE_IP"

    sleep 15

    chmod 644 /etc/rancher/k3s/k3s.yaml
  EOT

  root_block_device {
    volume_size = 40
    volume_type = "gp3"
  }

  tags = {
    Name = "k3s-master-${count.index + 1}"
    Role = "k3s-master"
  }
}

resource "aws_instance" "workers" {
  count = var.worker_count

  ami           = local.ami_id
  instance_type = var.worker_instance_type
  key_name      = var.ssh_key_name
  subnet_id     = var.worker_subnet_ids[count.index]
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]
  associate_public_ip_address = true
  depends_on    = [aws_instance.master]

  user_data = <<-EOT
    #!/bin/bash
    set -euxo pipefail

    sleep 10

    MASTER_IP="${aws_instance.master[0].private_ip}"
    echo "Waiting for k3s server at $MASTER_IP..."

    until curl -ks "https://$MASTER_IP:6443/" >/dev/null 2>&1; do
      echo "Waiting for k3s server..."
      sleep 5
    done

    echo "k3s server is ready. Joining cluster..."

    curl -sfL https://get.k3s.io | \
      INSTALL_K3S_VERSION="${var.k3s_version}" \
      K3S_URL="https://$MASTER_IP:6443" \
      K3S_TOKEN="${random_password.k3s_token.result}" \
      sh -
  EOT

  root_block_device {
    volume_size = 40
    volume_type = "gp3"
  }

  tags = {
    Name = "k3s-worker-${count.index + 1}"
    Role = "k3s-worker"
  }
}

resource "local_file" "kubespray_inventory" {
  content = templatefile("${path.module}/templates/inventory.tmpl", {
    master_ips         = aws_instance.master[*].public_ip
    master_private_ips = aws_instance.master[*].private_ip
    worker_ips         = aws_instance.workers[*].public_ip
    worker_private_ips = aws_instance.workers[*].private_ip
  })
  filename = "${path.module}/../inventory/mycluster/hosts.yaml"
}

resource "local_file" "get_kubeconfig" {
  content = <<-EOT
    #!/bin/bash
    # Get kubeconfig from the k3s master node
    # Usage: ./get-kubeconfig.sh <master-public-ip>
    #
    # Or manually:
    #   scp -i ~/.ssh/labsuser.pem ubuntu@<master-ip>:/etc/rancher/k3s/k3s.yaml ./kubeconfig
    #   sed -i '' 's/127.0.0.1/<master-public-ip>/g' ./kubeconfig

    MASTER_IP="$${1:-${aws_instance.master[0].public_ip}}"
    echo "Master node public IP: $MASTER_IP"
    echo ""
    echo "To get kubeconfig, run:"
    echo "  scp -i ~/.ssh/labsuser.pem ubuntu@$MASTER_IP:/etc/rancher/k3s/k3s.yaml ./kubeconfig"
    echo "  sed -i '' 's/127.0.0.1/$MASTER_IP/g' ./kubeconfig"
    echo "  export KUBECONFIG=./kubeconfig"
  EOT
  filename = "${path.module}/get-kubeconfig.sh"
}

output "cluster_info" {
  description = "k3s cluster node information"
  sensitive   = true
  value = {
    vpc_id          = var.vpc_id
    security_group  = aws_security_group.k8s_sg.id
    master_ip       = aws_instance.master[0].public_ip
    master_private  = aws_instance.master[0].private_ip
    worker_ips      = aws_instance.workers[*].public_ip
    worker_private  = aws_instance.workers[*].private_ip
    k3s_token       = random_password.k3s_token.result
  }
}

output "ssh_commands" {
  description = "SSH commands to connect to nodes"
  value = {
    master  = "ssh -i ~/.ssh/labsuser.pem ubuntu@${aws_instance.master[0].public_ip}"
    worker1 = "ssh -i ~/.ssh/labsuser.pem ubuntu@${aws_instance.workers[0].public_ip}"
    worker2 = length(aws_instance.workers) > 1 ? "ssh -i ~/.ssh/labsuser.pem ubuntu@${aws_instance.workers[1].public_ip}" : "no worker-2"
  }
}