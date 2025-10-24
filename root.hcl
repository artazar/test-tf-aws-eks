terragrunt_version_constraint = ">= v0.72.6 "
terraform_version_constraint  = ">= 1.10.5"

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl")) 
}

# Indicate what region to deploy the resources into
generate "provider" {
  path = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents = <<EOF
provider "aws" {
  region = var.region
  default_tags {
    tags = {
      managed_by = "Terraform"
      project    = "DEMO"
    }
  }
}
provider "aws" {
  region = "us-east-1"
  alias  = "us-east-1"
  default_tags {
    tags = {
      managed_by = "Terraform"
      project    = "DEMO"
    }
  }
}
EOF
}

remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }

  config = {
    encrypt        = true
    bucket         = "demo-terraform-state"
    region         = "eu-central-1"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    acl            = "bucket-owner-full-control"
    use_lockfile   = true
  }
}
