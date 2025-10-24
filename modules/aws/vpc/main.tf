locals {
  tags = {
    env       = var.env
    tf_module = "aws/vpc"
  }
}

data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }  
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "${var.env}-vpc"
  cidr = var.cidr
  azs  = data.aws_availability_zones.available.names

  public_subnets      = var.public_subnets
  private_subnets     = var.private_subnets
  elasticache_subnets = var.create_elasticache_subnet_group ? var.elasticache_subnets : []
  database_subnets    = var.create_database_subnet_group ? var.database_subnets : []

  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support
  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway

  tags = local.tags

  public_subnet_tags = {
    "kubernetes.io/role/elb"           = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"  = 1
    "karpenter.sh/discovery"           = var.env
  }
}

data "aws_security_group" "default" {
  name   = "default"
  vpc_id = module.vpc.vpc_id
}

module "vpc_endpoints" {
  source             = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version            = "5.21.0"
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnets
  security_group_ids = [data.aws_security_group.default.id]

  create_security_group      = true
  security_group_name_prefix = "${var.env}-vpc-endpoints-"
  security_group_description = "VPC endpoint security group"
  security_group_rules = {
    ingress_https = {
      description = "HTTPS from VPC"
      cidr_blocks = [module.vpc.vpc_cidr_block]
    }
  }

  endpoints = {
    s3 = {
      create              = contains(var.vpc_endpoints, "s3")
      service             = "s3"
      service_type        = "Gateway"
      private_dns_enabled = true
      route_table_ids     = flatten([module.vpc.private_route_table_ids, module.vpc.public_route_table_ids])

      tags    = merge(
        { Name = "s3-vpc-endpoint" },
        local.tags
      )

    },
    ecr_api = {
      create              = contains(var.vpc_endpoints, "ecr")
      service             = "ecr.api"
      service_type        = "Interface"
      private_dns_enabled = true
      policy              = data.aws_iam_policy_document.generic_endpoint_policy.json

      tags    = merge(
        { Name = "ecr-vpc-endpoint" },
        local.tags
      )
    },
    ecr_dkr = {
      create              = contains(var.vpc_endpoints, "ecr")
      service             = "ecr.dkr"
      service_type        = "Interface"
      private_dns_enabled = true
      policy              = data.aws_iam_policy_document.generic_endpoint_policy.json

      tags    = merge(
        { Name = "ecr-vpc-endpoint" },
        local.tags
      )
    }
  }
}


data "aws_iam_policy_document" "generic_endpoint_policy" {
  ### Block non-vpc sources
  statement {
    effect    = "Deny"
    actions   = ["*"]
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:SourceVpc"

      values = [module.vpc.vpc_id]
    }
  }

  ### Required for ECR
  ### https://docs.aws.amazon.com/AmazonECR/latest/userguide/vpc-endpoints.html#ecr-setting-up-s3-gateway
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::prod-${var.region}-starport-layer-bucket/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
  statement {
    sid     = "AllowECRPullPushActions"
    effect  = "Allow"
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetAuthorizationToken",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload"
    ]
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

data "aws_availability_zones" "localzone" {
  count = var.enable_local_zones ? 1 : 0

  all_availability_zones = true

  filter {
    name   = "region-name"
    values = [var.region]
  }

  filter {
    name   = "opt-in-status"
    values = ["opted-in"]
  }
}

resource "aws_subnet" "public_local_zone" {
  count = var.enable_local_zones ? 1 : 0

  vpc_id            = module.vpc.vpc_id
  cidr_block        = var.public_subnets_local_zone[0]
  availability_zone = element(data.aws_availability_zones.localzone[count.index].names, count.index)

  tags = {
    Name = format("%s-vpc-public-%s", var.env, element(data.aws_availability_zones.localzone[count.index].names, count.index))
    "kubernetes.io/role/elb" = 1 
  }

}

resource "aws_subnet" "private_local_zone" {
  count = var.enable_local_zones ? 1 : 0

  vpc_id            = module.vpc.vpc_id
  cidr_block        = var.private_subnets_local_zone[0]
  availability_zone = element(data.aws_availability_zones.localzone[count.index].names, count.index)

  tags = {
    Name = format("%s-vpc-private-%s", var.env, element(data.aws_availability_zones.localzone[count.index].names, count.index))
    "kubernetes.io/role/internal-elb" = 1
    "karpenter.sh/discovery"          = var.env
  }

}

resource "aws_route_table_association" "public_local_zone" {
  count = var.enable_local_zones ? 1 : 0

  subnet_id = element(aws_subnet.public_local_zone[*].id, count.index)
  route_table_id = element(module.vpc.public_route_table_ids, count.index)
}

resource "aws_route_table_association" "private_local_zone" {
  count = var.enable_local_zones ? 1 : 0

  subnet_id = element(aws_subnet.private_local_zone[*].id, count.index)
  route_table_id = element(module.vpc.private_route_table_ids, count.index)
}