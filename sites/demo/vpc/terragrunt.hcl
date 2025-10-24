terraform {
  source = "../../../modules/aws/vpc"
}

include {
  path = find_in_parent_folders("root.hcl")
}

locals { 
  module_vars = yamldecode(file("values.yml"))
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl")) 
}

inputs = merge(
  local.module_vars,
  local.env_vars.inputs
)
