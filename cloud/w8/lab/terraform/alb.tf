# ============================================
# Application Load Balancer
# ============================================
resource "aws_lb" "main" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  enable_deletion_protection = false
  enable_http2              = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb"
  })
}

# ============================================
# Target Group for EC2 NodePort
# ============================================
resource "aws_lb_target_group" "k8s" {
  name     = "${local.name_prefix}-tg"
  port     = var.k8s_app_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-tg"
  })
}

# ============================================
# Register EC2 instance with Target Group
# ============================================
resource "aws_lb_target_group_attachment" "k8s" {
  target_group_arn = aws_lb_target_group.k8s.arn
  target_id        = aws_instance.k8s.id
  port             = var.k8s_app_port
}

# ============================================
# ALB Listener (HTTP:80)
# ============================================
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.k8s.arn
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-listener"
  })
}
