variable "env" {
  type = string
}

variable "region" {
  type = string
}

variable "bucket_list" {
  description = "List of bucket names to create with default configuration"
  type        = list(string)
  default     = []
}

variable "bucket_config" {
  description = "Map of bucket names (suffixes) to per-bucket configuration"
  type = map(object({
    lifecycle_rule = optional(object({
      prefix          = optional(string)
      tags            = optional(map(string))
      transition_days = optional(number)
      expiration_days = optional(number)
    }))
    acl           = optional(string)
    versioned     = optional(bool)
    force_destroy = optional(bool)
  }))
  default = {}
}

variable "user_bucket_list" {
  type = map(list(string))
  default = {}
}
variable "role_bucket_list" {
  type = map(list(string))
  default = {}
}
### For users created separately outside this module
variable "extra_user_bucket_list" {
  type = map(list(string))
  default = {}
}