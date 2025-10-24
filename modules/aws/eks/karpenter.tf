# This data source can only be used in the us-east-1 region.
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecrpublic_authorization_token
data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.us-east-1
}

locals {
  karpenter_namespace = "karpenter"
}

# Karpenter IAM permissions
resource "aws_iam_policy" "karpenter_additional_policy" {
  name        = "${var.cluster_name}-karpenter-additional-policy"
  description = "Policy for Karpenter EC2 permissions"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "ec2:*"
        ]
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "iam:CreateServiceLinkedRole",
          "iam:ListRoles",
          "iam:ListInstanceProfiles"
        ]
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

# for ecr pull through cache
resource "aws_iam_policy" "karpenter_node_additional_policy" {
  name        = "${var.cluster_name}-karpenter-node-additional-policy"
  description = "Policy for Karpenter Node Role EC2 permissions"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "ecr:CreateRepository",
          "ecr:ReplicateImage",
          "ecr:BatchImportUpstreamImage"
        ]
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

# These are preparatory steps for Karpenter installation
module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "= 19.21.0"

  cluster_name = module.eks.cluster_name

  irsa_oidc_provider_arn          = module.eks.oidc_provider_arn
  irsa_namespace_service_accounts = ["karpenter:karpenter"]

  policies = {
    AmazonSSMManagedInstanceCore       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    AdditionalPolicy                   = aws_iam_policy.karpenter_additional_policy.arn
  }

  iam_role_additional_policies = {
    AmazonSSMManagedEC2InstanceDefaultPolicy = "arn:aws:iam::aws:policy/AmazonSSMManagedEC2InstanceDefaultPolicy"
    AdditionalPolicy                         = aws_iam_policy.karpenter_node_additional_policy.arn
  }

  tags = local.tags
}


# Karpenter CRDs
resource "helm_release" "karpenter_crds" {
  namespace        = local.karpenter_namespace
  create_namespace = true

  name                = "karpenter-crd"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter-crd"
  version             = var.karpenter_version

  set {
    name  = "webhoook.enabled"
    value = "true"
  }

  set {
    name  = "webhoook.serviceName"
    value = "karpenter"
  }

  set {
    name  = "webhook.port"
    value = "8443"
  }
}

# Actual Karpenter helm release
resource "helm_release" "karpenter" {
  namespace        = local.karpenter_namespace
  create_namespace = true

  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = var.karpenter_version
  skip_crds           = true

  set {
    name  = "replicas"
    value = 2
  }

  set {
    name  = "logLevel"
    value = "debug"
  }

  set {
    name  = "settings.clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "settings.clusterEndpoint"
    value = module.eks.cluster_endpoint
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter.irsa_arn
  }

  set {
    name  = "settings.interruptionQueue"
    value = module.karpenter.queue_name
  }

  set {
    name  = "controller.resources.requests.cpu"
    value = 1
  }

  set {
    name  = "controller.resources.limits.cpu"
    value = 1
  }

  set {
    name  = "controller.resources.requests.memory"
    value = "1Gi"
  }

  set {
    name  = "controller.resources.limits.memory"
    value = "1Gi"
  }

  set {
    name  = "webhoook.enabled"
    value = "true"
  }

  set {
    name  = "webhook.port"
    value = "8443"
  }

  set {
    name  = "serviceMonitor.enabled"
    value = "true"
  }

  depends_on = [module.eks.fargate_profiles, module.karpenter, helm_release.aws_load_balancer_controller, helm_release.karpenter_crds]

}

data "archive_file" "karpenter-nodepools_helm_dir_checksum" {
  type        = "zip"
  source_dir  = "${path.module}/templates/karpenter-nodepools"
  output_path = "/tmp/karpenter-nodepools_helm_dir_checksum.zip"
}

# here we create default node pools and classes
resource "helm_release" "karpenter-nodepools" {
  name             = "karpenter-nodepools"
  chart            = "./templates/karpenter-nodepools"
  namespace        = local.karpenter_namespace
  create_namespace = false
  cleanup_on_fail  = true

  set {
    name  = "helm_dir_hash"
    value = data.archive_file.karpenter-nodepools_helm_dir_checksum.output_md5
  }

  values = [
    templatefile("${path.module}/templates/karpenter-nodepools/values.yaml",
      {
        karpenter_nodepool_arm64_name = var.karpenter_nodepool_arm64_name
        karpenter_nodepool_amd64_name = var.karpenter_nodepool_amd64_name

        karpenter_nodeclass_arm64_name = var.karpenter_nodeclass_arm64_name
        karpenter_nodeclass_amd64_name = var.karpenter_nodeclass_amd64_name

        karpenter_nodepool_arm64_capacity_types = var.karpenter_nodepool_arm64_capacity_types
        karpenter_nodepool_amd64_capacity_types = var.karpenter_nodepool_amd64_capacity_types

        karpenter_nodepool_disruption_consolidation_policy = var.karpenter_nodepool_disruption_consolidation_policy
        karpenter_nodepool_disruption_consolidate_after    = var.karpenter_nodepool_disruption_consolidate_after
        karpenter_nodepool_disruption_expire_after         = var.karpenter_nodepool_disruption_expire_after

        karpenter_nodepool_disruption_budgets_nodes     = var.karpenter_nodepool_disruption_budgets_nodes
        karpenter_nodepool_disruption_budgets_nodes_max = var.karpenter_nodepool_disruption_budgets_nodes_max
        karpenter_nodepool_disruption_budgets_schedule  = var.karpenter_nodepool_disruption_budgets_schedule
        karpenter_nodepool_disruption_budgets_duration  = var.karpenter_nodepool_disruption_budgets_duration

        karpenter_nodepool_cpu_limit    = var.karpenter_nodepool_cpu_limit
        karpenter_nodepool_memory_limit = var.karpenter_nodepool_memory_limit

        karpenter_nodepool_arm64_weight = var.karpenter_nodepool_arm64_weight
        karpenter_nodepool_amd64_weight = var.karpenter_nodepool_amd64_weight

        karpenter_nodepool_cilium_enabled = var.karpenter_nodepool_cilium_enabled
      }
    )
  ]

  depends_on = [helm_release.karpenter]
}

# https://karpenter.sh/v0.32/concepts/nodeclasses/

data "archive_file" "karpenter-nodeclasses_helm_dir_checksum" {
  type        = "zip"
  source_dir  = "${path.module}/templates/karpenter-nodepools"
  output_path = "/tmp/karpenter-nodeclasses_helm_dir_checksum.zip"
}

resource "helm_release" "karpenter-nodeclasses" {
  name             = "karpenter-nodeclasses"
  chart            = "./templates/karpenter-nodeclasses"
  namespace        = local.karpenter_namespace
  create_namespace = false
  cleanup_on_fail  = true

  set {
    name  = "helm_dir_hash"
    value = data.archive_file.karpenter-nodeclasses_helm_dir_checksum.output_md5
  }

  values = [
    templatefile("${path.module}/templates/karpenter-nodeclasses/values.yaml",
      {
        env                                           = var.env
        cluster_name                                  = var.cluster_name
        karpenter_instance_profile                    = module.karpenter.instance_profile_name
        karpenter_nodeclass_arm64_name                = var.karpenter_nodeclass_arm64_name
        karpenter_nodeclass_amd64_name                = var.karpenter_nodeclass_amd64_name
        karpenter_nodeclass_ebs_size                  = var.karpenter_nodeclass_ebs_size
        karpenter_nodeclass_ebs_type                  = var.karpenter_nodeclass_ebs_type
        karpenter_nodeclass_ebs_delete_on_termination = var.karpenter_nodeclass_ebs_delete_on_termination
      }
    )
  ]

  depends_on = [helm_release.karpenter]
}
