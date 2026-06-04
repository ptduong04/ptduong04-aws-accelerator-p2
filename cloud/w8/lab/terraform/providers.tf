terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# ============================================
# AWS Provider Configuration
# ============================================
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "xbrain-k8s-challenge"
      ManagedBy   = "Terraform"
      Environment = "lab"
      Owner       = "ptduong04"
    }
  }
}

# ============================================
# Kubernetes Provider Configuration
# ============================================
provider "kubernetes" {
  # Kubernetes provider sẽ connect tới minikube cluster
  # Config này sẽ được setup sau khi EC2 instance khởi động
  # Hiện tại để empty vì cluster chưa tồn tại
  config_path = "~/.kube/config"
}
