output "master_public_ips" {
  description = "IP Public của Master Node"
  value       = aws_instance.master[*].public_ip
}

output "worker_public_ips" {
  description = "IP Public của các Worker Nodes"
  value       = aws_instance.workers[*].public_ip
}