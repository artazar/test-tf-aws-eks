variable "region" {
  type    = string
  default = "us-east-1"
}

variable "enable_local_zones" {
  type    = bool
  default = false
}

variable "env" {
  type    = string
  default = null
}

variable "cidr" {
  type    = string
  default = "10.1.0.0/16"
}

variable "public_subnets" {
  type    = list(string)
  default = ["10.1.192.0/22", "10.1.196.0/22", "10.1.200.0/22"]
}

variable "private_subnets" {
  type    = list(string)
  default = ["10.1.0.0/18", "10.1.64.0/18", "10.1.128.0/18"]
}

variable "public_subnets_local_zone" {
  type    = list(string)
  default = []
}

variable "private_subnets_local_zone" {
  type    = list(string)
  default = []
}

variable "create_database_subnet_group" {
  type        = bool
  default     = false
  description = "Controls if database subnet group should be created"
}

variable "database_subnets" {
  type    = list(string)
  default = [] #["10.100.219.0/24", "10.100.220.0/24", "10.100.221.0/24"]
}

variable "create_elasticache_subnet_group" {
  type        = bool
  default     = false
  description = "Controls if elasticache subnet group should be created"
}

variable "elasticache_subnets" {
  type    = list(string)
  default = [] #["10.100.222.0/23", "10.100.224.0/23", "10.100.226.0/23"]
}

variable "enable_dns_hostnames" {
  type        = bool
  default     = true
  description = "Should be true to enable DNS hostnames in the VPC"
}

variable "enable_dns_support" {
  type        = bool
  default     = true
  description = "Should be true to enable DNS support in the VPC"
}

variable "enable_nat_gateway" {
  type        = bool
  default     = true
  description = "Should be true if you want to provision NAT Gateways for each of your private networks"
}

variable "single_nat_gateway" {
  type        = bool
  default     = false
  description = "Should be true if you want to provision a single shared NAT Gateway across all of your private networks"
}

variable "vpc_endpoints" {
  type    = list(string)
  default = []
}
