output "vpc_id" {
  description = "AWS VPC ID"
  value       = module.vpc.vpc_id
}

output "region" {
  description = "AWS Region"
  value       = var.region
}

output "env" {
  description = "env"
  value       = var.env
}

output "public_subnets" {
  description = "public subnets ids"
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "private subnets ids"
  value       = module.vpc.private_subnets
}

output "public_subnets_local_zone" {
  description = "local zone public subnets ids"
  value       = compact(aws_subnet.public_local_zone[*].id)
}

output "private_subnets_local_zone" {
  description = "local zone private subnets ids"
  value       = compact(aws_subnet.private_local_zone[*].id)
}

output "elasticache_subnets" {
  description = "elasticache subnets ids"
  value       = module.vpc.elasticache_subnets
}

output "database_subnets" {
  description = "database subnets ids"
  value       = module.vpc.database_subnets
}

output "public_subnets_cidr_blocks" {
  description = "List of cidr_blocks of public subnets"
  value       = module.vpc.public_subnets_cidr_blocks
}

output "private_subnets_cidr_blocks" {
  description = "List of cidr_blocks of private subnets"
  value       = module.vpc.private_subnets_cidr_blocks
}

output "public_subnets_local_zone_cidr_blocks" {
  description = "local zone public subnets cidr blocks"
  value       = compact(aws_subnet.public_local_zone[*].cidr_block)
}

output "private_subnets_local_zone_cidr_blocks" {
  description = "local zone private subnets cidr blocks"
  value       = compact(aws_subnet.private_local_zone[*].cidr_block)
}

output "elasticache_subnets_cidr_blocks" {
  description = "List of cidr_blocks of elasticache subnets"
  value       = module.vpc.elasticache_subnets_cidr_blocks
}

output "database_subnets_cidr_blocks" {
  description = "List of cidr_blocks of database subnets"
  value       = module.vpc.database_subnets_cidr_blocks
}

output "public_route_table_ids" {
  description = "List of IDs of public route tables"
  value       = module.vpc.public_route_table_ids
}

output "private_route_table_ids" {
  description = "List of IDs of private route tables"
  value       = module.vpc.private_route_table_ids
}

output "elasticache_route_table_ids" {
  description = "List of IDs of elasticache route tables"
  value       = module.vpc.elasticache_route_table_ids
}

output "database_route_table_ids" {
  description = "List of IDs of database route tables"
  value       = module.vpc.database_route_table_ids
}
