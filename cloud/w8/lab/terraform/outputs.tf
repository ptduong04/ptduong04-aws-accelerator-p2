output "alb_url" {
  description = "Application Load Balancer URL"
  value       = "http://${aws_lb.main.dns_name}"
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "ec2_public_ip" {
  description = "EC2 instance public IP"
  value       = aws_eip.k8s.public_ip
}

output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.k8s.id
}

output "resource_suffix" {
  description = "Random suffix used for resource names"
  value       = random_id.suffix.hex
}

output "ssh_command" {
  description = "SSH command to connect to EC2 (if key_name provided)"
  value       = var.key_name != "" ? "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${aws_eip.k8s.public_ip}" : "No SSH key configured"
}

output "minikube_status_command" {
  description = "Command to check minikube status"
  value       = "ssh ubuntu@${aws_eip.k8s.public_ip} 'kubectl get all'"
}

output "deployment_complete" {
  description = "Deployment status"
  value       = "✅ Deployment complete! Wait ~5 minutes for setup, then access: http://${aws_lb.main.dns_name}"
}
