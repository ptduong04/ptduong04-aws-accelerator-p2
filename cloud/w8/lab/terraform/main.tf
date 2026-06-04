# ============================================
# Random suffix for unique resource naming (using UUID)
# ============================================
resource "random_id" "suffix" {
  byte_length = 3
  
  keepers = {
    project = var.project_name
  }
}

# ============================================
# Data sources
# ============================================
data "aws_availability_zones" "available" {
  state = "available"
}

# ============================================
# Local values
# ============================================
locals {
  name_prefix = "${var.project_name}-${random_id.suffix.hex}"
  common_tags = {
    Project   = var.project_name
    Terraform = "true"
  }
}
