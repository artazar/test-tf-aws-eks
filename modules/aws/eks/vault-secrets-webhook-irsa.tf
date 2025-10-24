locals {
  cluster_name   = module.eks.cluster_name
  oidc_provider  = module.eks.oidc_provider_arn
  oidc_url       = module.eks.oidc_provider
  namespace      = "kube-system"
  serviceaccount = "vault-secrets-webhook"
}

resource "aws_iam_role" "vault_secrets_webhook" {
  name = "vault-secrets-webhook-irsa-role"
  count = var.vault_secrets_webhook_irsa_enabled ? 1 : 0
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = local.oidc_provider
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${local.oidc_url}:sub" = "system:serviceaccount:${local.namespace}:${local.serviceaccount}",
            "${local.oidc_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "vault_secrets_webhook_ecr" {
  count      = var.vault_secrets_webhook_irsa_enabled ? 1 : 0
  role       = aws_iam_role.vault_secrets_webhook[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "kubernetes_service_account" "vault_secrets_webhook" {
  count = var.vault_secrets_webhook_irsa_enabled ? 1 : 0
  metadata {
    name      = local.serviceaccount
    namespace = local.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.vault_secrets_webhook[0].arn
    }
  }
}
