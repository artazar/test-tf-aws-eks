terraform {
  source = "../../../modules/aws/nginx"
}

dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    cluster_name                       = "mock-cluster"
    cluster_endpoint                   = "https://mock-endpoint"
    cluster_certificate_authority_data = "bW9jay1jZXJ0LWRhdGE="
    region                             = "eu-central-1"
    env                                = "demo"
  }
}

include {
  path = find_in_parent_folders("root.hcl")
}

locals {
  module_vars = yamldecode(file("values.yml"))
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

inputs = merge(
  {
    cluster_name                       = dependency.eks.outputs.cluster_name
    cluster_endpoint                   = dependency.eks.outputs.cluster_endpoint
    cluster_certificate_authority_data = dependency.eks.outputs.cluster_certificate_authority_data
    region                             = dependency.eks.outputs.region
    env                                = dependency.eks.outputs.env
  },
  local.module_vars,
  local.env_vars.inputs
)
