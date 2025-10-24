locals {
  tags = {
    Name      = local.name
    env       = var.env
    tf_module = "aws/s3"
  }
  name = "${var.env}-${var.name}"
}

data "aws_ami" "ami" {
  most_recent = "true"

  dynamic "filter" {
    for_each = var.ami_filter
    content {
      name   = filter.key
      values = filter.value
    }
  }

  owners = var.ami_owners
}

resource "tls_private_key" "private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

module "key_pair" {
  source  = "terraform-aws-modules/key-pair/aws"
  version = "2.0.0"

  key_name   = local.name
  public_key = trimspace(tls_private_key.private_key.public_key_openssh)

  tags = local.tags
}

resource "local_file" "private_key" {
  content         = tls_private_key.private_key.private_key_pem
  filename        = "${path.module}/../../../../../${local.name}.pem"
  file_permission = "0600"
}

resource "aws_eip" "eip" {
  count           = var.enable_public_access ? 1 : 0

  network_interface    = aws_network_interface.public[count.index].id
  network_border_group = substr(var.az, 0, length(var.az) - 1)

  tags              = local.tags
}

data "aws_kms_key" "aws_ebs" {
  key_id = "alias/aws/ebs"
}

resource "aws_network_interface" "private" {
  subnet_id       = var.private_subnet_id
  security_groups = [aws_security_group.sg.id]

  tags = merge(
    local.tags,
    {
      subnet = "private"
    }
  )
}

resource "aws_network_interface" "public" {
  count           = var.enable_public_access ? 1 : 0
  subnet_id       = var.public_subnet_id
  security_groups = [aws_security_group.sg.id]

  tags = merge(
    local.tags,
    {
      subnet = "public"
    }
  )
}

resource "aws_instance" "vm" {
  ami               = data.aws_ami.ami.id
  ebs_optimized     = true
  instance_type     = var.instance_type
  key_name          = module.key_pair.key_pair_name
  availability_zone = var.az
  iam_instance_profile = var.iam_instance_profile
  dynamic "metadata_options" {
    for_each = var.enable_imds_for_containers ? [1] : []
    content {
      http_put_response_hop_limit = 2
    }
  }
  dynamic "network_interface" {
    for_each = var.enable_public_access == true ? [1] : [0]
    content {
      network_interface_id = aws_network_interface.private.id
      device_index         = network_interface.value
    }
  }

  dynamic "network_interface" {
    for_each = var.enable_public_access == true ? [0] : []
    content {
      network_interface_id = aws_network_interface.public[0].id
      device_index         = network_interface.value
    }
  }

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    delete_on_termination = true
    encrypted             = true
    kms_key_id            = data.aws_kms_key.aws_ebs.arn
    tags = merge(
      local.tags,
      var.root_volume_daily_snapshots_enabled ? { Snapshot = "${local.name}-daily-root" } : {}
    )
  }

  # Dynamic block to support multiple additional EBS volumes
  dynamic "ebs_block_device" {
    for_each = var.additional_ebs_volumes
    content {
      device_name           = ebs_block_device.value.device_name
      volume_size           = ebs_block_device.value.volume_size
      volume_type           = ebs_block_device.value.volume_type
      iops                  = lookup(ebs_block_device.value, "iops", null)
      delete_on_termination = lookup(ebs_block_device.value, "delete_on_termination", true)
      encrypted             = lookup(ebs_block_device.value, "encrypted", true)
      kms_key_id            = lookup(ebs_block_device.value, "kms_key_id", data.aws_kms_key.aws_ebs.arn) 

      tags = merge(
        local.tags,
        try(ebs_block_device.value.daily_snapshots, false) ? { Snapshot = "${local.name}-daily-ebs" } : {}
      )
    }
  }

  credit_specification {
    cpu_credits = "standard"
  }

  user_data = templatefile("${path.module}/templates/user-data.txt", { 
    hostname = var.name
    custom_commands = var.user_data_extra_commands
  })

  lifecycle {
    ignore_changes = [ami]
  }

  tags = local.tags

  # volume_tags = local.tags
}

### DLM policies

data "aws_iam_role" "ebs_snapshot_role" {
  name = "AWSDataLifecycleManagerDefaultRole"
}

resource "aws_dlm_lifecycle_policy" "daily_root_snapshot" {
  count               = var.root_volume_daily_snapshots_enabled ? 1 : 0
  execution_role_arn  = data.aws_iam_role.ebs_snapshot_role.arn
  description         = "Daily snapshot for root volume"
  state               = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]

    target_tags = {
      Snapshot = "${local.name}-daily-root"
    }

    schedule {
      name = "DailyRootSnapshots"

      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = ["23:00"]
      }

      retain_rule {
        count = 7
      }

      tags_to_add = {
        CreatedBy = "Terraform"
      }
    }
  }
}

resource "aws_dlm_lifecycle_policy" "daily_ebs_snapshots" {
  count               = length([for v in var.additional_ebs_volumes : v if try(v.daily_snapshots, false)]) > 0 ? 1 : 0
  execution_role_arn  = data.aws_iam_role.ebs_snapshot_role.arn
  description         = "Daily snapshot for EBS data volumes"
  state               = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]

    target_tags = {
      Snapshot = "${local.name}-daily-ebs"
    }

    schedule {
      name = "DailyEbsSnapshots"

      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = ["23:30"]
      }

      retain_rule {
        count = 7
      }

      tags_to_add = {
        CreatedBy = "Terraform"
      }
    }
  }
}