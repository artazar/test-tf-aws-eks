variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_endpoint" {
  description = "Endpoint for Kubernetes API server"
  type        = string
}

variable "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for cluster"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "env" {
  description = "Environment name"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for nginx deployment"
  type        = string
  default     = "default"
}

variable "replicas" {
  description = "Number of nginx replicas"
  type        = number
  default     = 1
}
