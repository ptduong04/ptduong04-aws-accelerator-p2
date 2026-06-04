variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "xbrain-k8s"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "ami_id" {
  description = "AMI ID for EC2 instance (Ubuntu 22.04 LTS in us-west-2)"
  type        = string
  default     = "ami-03a1c8d65318aa1fc" # Ubuntu 22.04 LTS
}

variable "key_name" {
  description = "SSH key pair name (optional - for debugging)"
  type        = string
  default     = ""
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access ALB"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Allow from anywhere - adjust for production
}

variable "k8s_app_port" {
  description = "NodePort for K8s service"
  type        = number
  default     = 30080
}
