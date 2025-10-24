locals {
  tags = {
    env       = var.env
    tf_module = "aws/s3"
  }

  bucket_prefix = "${data.aws_caller_identity.current.account_id}-${var.env}"

  # Convert the simple list into default config map
  default_bucket_config = {
    for name in var.bucket_list : name => {}
  }

  # Merge simple defaults and advanced config (advanced overrides)
  combined_bucket_config = merge(
    local.default_bucket_config,
    var.bucket_config
  )

  bucket_resources_list = flatten([
    for bucket in keys(local.combined_bucket_config) : [
      "arn:aws:s3:::${local.bucket_prefix}-${bucket}",
      "arn:aws:s3:::${local.bucket_prefix}-${bucket}/*"
    ]
  ])

  # put default values to bucket config
  normalized_bucket_config = {
    for k, v in local.combined_bucket_config : k => merge(
      {
        lifecycle_rule = null
        acl            = "private"
        versioned      = false
        force_destroy  = true
      },
      v != null ? tomap({ for attr, val in v : attr => val if val != null }) : {}
    )
  }

}

data "aws_caller_identity" "current" {}

module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.1.2"

  for_each = local.normalized_bucket_config

  bucket = "${local.bucket_prefix}-${each.key}"

  # Security & policy settings
  attach_policy                         = false
  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true

  # Ownership and encryption
  control_object_ownership = true
  object_ownership         = "BucketOwnerPreferred"
  expected_bucket_owner    = data.aws_caller_identity.current.account_id
  acl                      = lookup(each.value, "acl")

  # Versioning
  versioning = {
    status = lookup(each.value, "versioned")
  }

  # Encryption
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  # Lifecycle rules (conditionally set per-bucket)
  lifecycle_rule = (
    contains(keys(each.value), "lifecycle_rule") && each.value.lifecycle_rule != null
    ? [
        {
          id      = "auto-expire-objects"
          enabled = true
          prefix  = lookup(each.value.lifecycle_rule, "prefix", "")
          tags    = lookup(each.value.lifecycle_rule, "tags", null)

          transition = (
            contains(keys(each.value.lifecycle_rule), "transition_days") &&
            each.value.lifecycle_rule.transition_days != null
          ) ? [
            {
              days          = each.value.lifecycle_rule.transition_days
              storage_class = "STANDARD_IA"
            }
          ] : []

          expiration = (
            contains(keys(each.value.lifecycle_rule), "expiration_days") &&
            each.value.lifecycle_rule.expiration_days != null
          ) ? {
            days = each.value.lifecycle_rule.expiration_days
          } : null
        }
      ]
    : []
  )

  # Cleanup behavior
  force_destroy = lookup(each.value, "force_destroy")

  # Tags
  tags = local.tags
}

## IAM

# Global User

resource "aws_iam_user" "s3_user" {
  name = "${var.env}-s3-user"
  tags = local.tags
}

resource "aws_iam_policy" "s3_policy" {
  name        = "${var.env}-s3-policy"
  path        = "/"
  description = "Allow S3 buckets access"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "VisualEditor0",
        "Effect" : "Allow",
        "Action" : [
          "s3:List*",
          "s3:PutObject*",
          "s3:GetObject*",
          "s3:DeleteObject*"
        ],
        "Resource" : local.bucket_resources_list
      },
      {
        "Sid" : "VisualEditor1",
        "Effect" : "Allow",
        "Action" : [
          "s3:Head*",
          "s3:GetBucket*",
          "s3:List*"
        ],
        "Resource" : "*"
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_user_policy_attachment" "s3_policy_attachment" {
  user       = aws_iam_user.s3_user.name
  policy_arn = aws_iam_policy.s3_policy.arn
}

# Per-Bucket Users

resource "aws_iam_user" "s3_bucket_user" {
  for_each = var.user_bucket_list
  name     = format("%s-%s-%s", var.env, "s3-user", each.key)
  tags     = local.tags
}

resource "aws_iam_policy" "s3_bucket_user_policy" {
  for_each    = var.user_bucket_list
  name        = format("%s-%s-%s", var.env, "s3-policy", each.key)
  path        = "/"
  description = "Allow S3 buckets access"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "VisualEditor0",
        "Effect" : "Allow",
        "Action" : [
          "s3:*Object",
          "s3:*ObjectVersion"
        ],
        "Resource" : flatten([for bucket in each.value : [
          "arn:aws:s3:::${local.bucket_prefix}-${bucket}/*"
        ]])
      },
      {
        "Sid" : "VisualEditor1",
        "Effect" : "Allow",
        "Action" : [
          "s3:ListBucket",
          "s3:ListBucketVersions"
        ],
        "Resource" : flatten([for bucket in each.value : [
          "arn:aws:s3:::${local.bucket_prefix}-${bucket}"
        ]])
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_user_policy_attachment" "s3_bucket_user_policy_attachment" {
  for_each   = var.user_bucket_list
  user       = aws_iam_user.s3_bucket_user[each.key].name
  policy_arn = aws_iam_policy.s3_bucket_user_policy[each.key].arn
}

### For external users
resource "aws_iam_policy" "s3_extra_bucket_user_policy" {
  for_each    = var.extra_user_bucket_list
  name        = format("%s-%s-%s", var.env, "s3-policy", each.key)
  path        = "/"
  description = "Allow S3 buckets access"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "VisualEditor0",
        "Effect" : "Allow",
        "Action" : [
          "s3:*Object"
        ],
        "Resource" : flatten([for bucket in each.value : [
          "arn:aws:s3:::${local.bucket_prefix}-${bucket}/*"
        ]])
      },
      {
        "Sid" : "VisualEditor1",
        "Effect" : "Allow",
        "Action" : [
          "s3:ListBucket"
        ],
        "Resource" : flatten([for bucket in each.value : [
          "arn:aws:s3:::${local.bucket_prefix}-${bucket}"
        ]])
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_user_policy_attachment" "s3_extra_bucket_user_policy_attachment" {
  for_each   = var.extra_user_bucket_list
  user       = each.key
  policy_arn = aws_iam_policy.s3_extra_bucket_user_policy[each.key].arn
}
resource "aws_iam_role" "s3_bucket_role" {
  for_each = var.role_bucket_list
  name     = format("%s-%s-%s", var.env, "s3-role", each.key)

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

resource "aws_iam_policy" "s3_bucket_role_policy" {
  for_each    = var.role_bucket_list
  name        = format("%s-%s-%s", var.env, "s3-policy", each.key)
  path        = "/"
  description = "Allow S3 buckets access"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "BucketActions",
        Effect = "Allow",
        Action = [
          "s3:GetBucketLocation",
          "s3:ListBucketVersions",
          "s3:ListBucketMultipartUploads",
          "s3:ListBucket",
          "s3:GetEncryptionConfiguration",
          "s3:GetBucketVersioning"
        ],
        Resource = [for bucket in each.value : "arn:aws:s3:::${local.bucket_prefix}-${bucket}"]
      },
      {
        Sid    = "ObjectActions",
        Effect = "Allow",
        Action = [
          "s3:GetObjectVersion",
          "s3:GetObjectRetention",
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListMultipartUploadParts",
          "s3:AbortMultipartUpload"
        ],
        Resource = [for bucket in each.value : "arn:aws:s3:::${local.bucket_prefix}-${bucket}/*"]
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "s3_bucket_role_policy_attachment" {
  for_each   = var.role_bucket_list
  role       = aws_iam_role.s3_bucket_role[each.key].name
  policy_arn = aws_iam_policy.s3_bucket_role_policy[each.key].arn
}

resource "aws_iam_instance_profile" "s3_bucket_instance_profile" {
  for_each = var.role_bucket_list
  name     = format("%s-%s-%s", var.env, "s3-profile", each.key)
  role     = aws_iam_role.s3_bucket_role[each.key].name
}
