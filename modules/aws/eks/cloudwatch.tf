### Here we add pod service account role association for fluent bit deployed by GitOps tools (FluxCD)
module "aws_cloudwatch_fluent_bit_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "= 5.39.1"

  attach_cloudwatch_observability_policy = true

  role_name = "${var.cluster_name}-fluent-bit-cloudwatch"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["observability:fluent-bit"]
    }
  }
}

resource "kubernetes_namespace" "observability" {
  metadata {
    name = "observability"
  }
  lifecycle {
    ignore_changes = all
  }
}

resource "kubernetes_service_account" "fluent_bit" {
  metadata {
    name      = "fluent-bit"
    namespace = kubernetes_namespace.observability.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = module.aws_cloudwatch_fluent_bit_irsa.iam_role_arn
    }
  }

}