output "master_public_ips" {
  description = "Public IPs of k3s master nodes"
  value       = aws_instance.master[*].public_ip
}

output "worker_public_ips" {
  description = "Public IPs of k3s worker nodes"
  value       = aws_instance.workers[*].public_ip
}

output "master_private_ip" {
  description = "Private IP of k3s master node"
  value       = aws_instance.master[0].private_ip
}

output "k3s_token" {
  description = "Pre-shared k3s cluster token"
  value       = random_password.k3s_token.result
  sensitive   = true
}

output "security_group_id" {
  description = "Security Group ID for k3s cluster"
  value       = aws_security_group.k8s_sg.id
}

output "kubeconfig_fetch_cmd" {
  description = "Run this command (after master boots ~90s) to get kubeconfig"
  value       = <<-EOT
    # Get kubeconfig from k3s master (AWS Academy uses labsuser.pem)
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/labsuser.pem ubuntu@${aws_instance.master[0].public_ip} \
      'sudo cat /etc/rancher/k3s/k3s.yaml' \
      | sed "s/127.0.0.1/${aws_instance.master[0].public_ip}/" > ./kubeconfig
    echo "export KUBECONFIG=$(pwd)/kubeconfig"
    echo "Test: kubectl get nodes --kubeconfig=./kubeconfig"
  EOT
}

output "ssh_connect_cmds" {
  description = "SSH commands to connect to cluster nodes"
  value = {
    master  = "ssh -i ~/.ssh/labsuser.pem ubuntu@${aws_instance.master[0].public_ip}"
    worker1 = "ssh -i ~/.ssh/labsuser.pem ubuntu@${aws_instance.workers[0].public_ip}"
    worker2 = "ssh -i ~/.ssh/labsuser.pem ubuntu@${aws_instance.workers[1].public_ip}"
  }
}