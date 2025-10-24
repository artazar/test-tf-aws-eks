terraform {
  source = "../../../modules/aws/eks"
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
      vpc_id = "mock-vpc-id",
      private_subnets = ["10.10.10.0/24"],
      public_subnets = ["10.10.10.0/24"],
      private_subnets_cidr_blocks = []
  }
}

include {
  path = find_in_parent_folders("root.hcl")
}

locals { 
  module_vars = yamldecode(file("values.yml"))
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl")) 
}

inputs = merge(
  {
    vpc_id             = dependency.vpc.outputs.vpc_id,
    private_subnet_ids = dependency.vpc.outputs.private_subnets,
    public_subnet_ids  = dependency.vpc.outputs.public_subnets
  },
  local.module_vars,
  local.env_vars.inputs
)
