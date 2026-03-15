# ==============================================================================
# ELASTIC CONTAINER REGISTRY (ECR)
# ==============================================================================

# Repositório para a imagem do Frontend
resource "aws_ecr_repository" "frontend" {
  name                 = "amparo-frontend-repo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "amparo-frontend-repo"
  }
}

# Repositório para a imagem do Backend
resource "aws_ecr_repository" "backend" {
  name                 = "amparo-backend-repo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "amparo-backend-repo"
  }
}
