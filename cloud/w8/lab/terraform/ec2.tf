# ============================================
# EC2 Instance with minikube
# ============================================
resource "aws_instance" "k8s" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public_1.id

  vpc_security_group_ids = [aws_security_group.ec2.id]

  key_name = var.key_name != "" ? var.key_name : null

  # User data script to install Docker, minikube, kubectl and deploy app
  user_data = templatefile("${path.module}/userdata.sh", {
    K8S_APP_PORT = var.k8s_app_port
  })

  # Enhanced monitoring
  monitoring = true

  # Root volume
  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true

    tags = merge(local.common_tags, {
      Name = "${local.name_prefix}-root-volume"
    })
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-k8s-instance"
    Role = "kubernetes-node"
  })

  # Wait for instance to be ready before ALB tries to connect
  depends_on = [
    aws_internet_gateway.main
  ]
}

# ============================================
# Elastic IP for EC2 (optional but recommended)
# ============================================
resource "aws_eip" "k8s" {
  domain   = "vpc"
  instance = aws_instance.k8s.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-eip"
  })

  depends_on = [aws_internet_gateway.main]
}
