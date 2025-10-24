variable "region" {
  type    = string
  default = "eu-south-2"
}

variable "env" {
  type    = string
  default = null
}

variable "repositories" {
  type = list(any)
}

variable "retain_count" {
  type        = number
  description = "How many images to keep per repo before older ones are expired"
  default     = 4
}

variable "scan_on_push" {
  type    = bool
  default = false
}

variable "image_tag_mutability" {
  type    = string
  default = "MUTABLE"
  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be either 'MUTABLE' or 'IMMUTABLE'."
  }
}