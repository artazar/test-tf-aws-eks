locals {
  tags = {
    env       = var.env
    tf_module = "aws/ecr"
  }
}
resource "aws_ecr_repository" "this" {
  for_each = toset(var.repositories)

  name                 = each.value
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }
  tags = local.tags

  
}
resource "aws_ecr_lifecycle_policy" "retain" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name

  policy = jsonencode({
    rules = [

      {
        rulePriority = 1
        description  = "Keep 5 images from main branch - production releases"
        selection = {
          tagStatus      = "tagged"
          tagPatternList = ["main-*"]            
          countType      = "imageCountMoreThan"
          countNumber    = 5                  # keep 5, expire the rest
        }
        action = { type = "expire" }
      },

      {
        rulePriority = 2
        description  = "Keep 3 images of stage branch - internal releases"
        selection = {
          tagStatus   = "tagged"
          tagPatternList = ["stage-*"]
          countType   = "imageCountMoreThan"
          countNumber = 3                    # keep 3, expire the rest
        }
        action = { type = "expire" }
      },

      {
        rulePriority = 3
        description  = "Keep 3 images of develop branch"
        selection = {
          tagStatus   = "tagged"
          tagPatternList = ["develop-*"]
          countType   = "imageCountMoreThan"
          countNumber = 3                    # keep 3, expire the rest
        }
        action = { type = "expire" }
      },

      {
        rulePriority = 4
        description  = "Keep only the newest 5 images of any remaining tag"
        selection = {
          tagStatus   = "tagged"
          tagPatternList = ["*"]
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = { type = "expire" }
      },

      {
        rulePriority = 99                   
        description  = "Expire any image (tagged or untagged) older than 90 days"
        selection = {
          tagStatus   = "any"               
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 90
        }
        action = { type = "expire" }
      }
    ]
  })
}
