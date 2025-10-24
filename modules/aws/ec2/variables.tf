variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "env" {
  type    = string
  default = null
}

variable "name" {
  type    = string
  default = "bastion"
}

variable "vpc_id" {
  type    = string
  default = ""
}

variable "az" {
  type    = string
  default = ""
}

variable "private_subnet_id" {
  type    = string
  default = ""
}

variable "public_subnet_id" {
  type    = string
  default = ""
}

variable "enable_public_access" {
  type = bool
  description = "Enable external access"
  default = false
}

variable "ami_filter" {
  description = "List of maps used to create the AMI filter for the used AMI."
  type        = map(list(string))

  default = {
    name                = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-server-*"]
    virtualization-type = ["hvm"]
  }
}

variable "ami_owners" {
  description = "The list of owners used to select the AMI of used instances."
  type        = list(string)
  default     = ["099720109477"] # Canonical
}

variable "ami" {
  type        = string
  description = "AMI to use for the instance. Setting this will ignore `ami_filter` and `ami_owners`."
  default     = null
}

variable "instance_type" {
  type        = string
  description = "Instance type for the created machine"
  default     = "t3.small"
}

variable "iam_instance_profile" {
  type        = string
  description = "IAM instance profile to be attached in the created machine"
  default     = ""
}
variable "allowed_tcp_ports" {
  type        = list(number)
  description = "Default set of TCP ports to allow in Security Group for ingress"
  default     = [22, 80, 443]
}

variable "allowed_udp_ports" {
  type        = list(number)
  description = "Default set of UDP ports to allow in Security Group for ingress"
  default     = []
}

variable "allowed_cidr_blocks" {
  type        = list(string)
  description = "Source IP CIDRs to allow in Security Group for ingress"
  default     = ["0.0.0.0/0"]
}

variable "vpc_private_cidr_blocks" {
  type        = list(string)
  description = "VPC IP CIDRs to allow in Security Group for ingress"
  default     = ["10.0.0.0/8"]
}
variable "enable_imds_for_containers" {
  type = bool
  description = "Enable EC2 IMDS so containers can access instance metadata and IAM credentials; hop limit 2 limits access to containers"
  default = false
}

# variable "tcp_proxy" {
#   type        = map(string)
#   description = "Map of values used for creating a TCP proxy"
#   default     = {}
# }

variable "root_volume_size" {
  type        = number
  description = "Root volume size in GB"
  default     = 10 
}

variable "root_volume_type" {
  type        = string
  description = "Root volume type"
  default     = "gp3" 
}

variable "root_volume_daily_snapshots_enabled" {
  type        = bool
  default     = false
  description = "Enable daily snapshots for the root volume with a 7-day retention period"
}

variable "additional_ebs_volumes" {
  description = "List of additional EBS volumes to attach"
  type = list(object({
    device_name           = string
    volume_size           = number
    volume_type           = string
    iops                  = optional(number)
    delete_on_termination = optional(bool, true)
    encrypted             = optional(bool, true)
    kms_key_id            = optional(string)
    daily_snapshots       = optional(bool, false)
  }))
  default = []
}

### Example of adding EBS volumes:
# additional_ebs_volumes = [
#   {
#     device_name = "/dev/sdf"
#     volume_size = 20
#     volume_type = "gp3"
#     iops        = 3000
#   },
#   {
#     device_name = "/dev/sdg"
#     volume_size = 50
#     volume_type = "io2"
#     iops        = 10000
#     delete_on_termination = false
#     encrypted = true
#   }
# ]

variable "user_data_extra_commands" {
  description = "Custom shell commands to execute after provisioning"
  type        = string
  default     = ""
}