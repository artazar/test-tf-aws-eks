locals {
  queue_name        = "${var.cluster_name}-SpotInterruptionQueue"
  rule_name         = "${var.cluster_name}-SpotInterruptRule"
  service_account   = "alert-silencer"
  service_namespace = "observability"
}

# Create SQS queue
resource "aws_sqs_queue" "interrupt_queue" {
  count = var.spot_termination_alert_silencer_enabled ? 1 : 0
  name  = local.queue_name
}

# EventBridge rule for Spot Interruption Warning
resource "aws_cloudwatch_event_rule" "spot_interrupt_rule" {
  count       = var.spot_termination_alert_silencer_enabled ? 1 : 0
  name        = local.rule_name
  description = "Triggers on EC2 spot interruption"
  event_pattern = jsonencode({
    "source"      = ["aws.ec2"],
    "detail-type" = ["EC2 Spot Instance Interruption Warning"]
  })
}

# EventBridge target to SQS
resource "aws_cloudwatch_event_target" "send_to_sqs" {
  count     = var.spot_termination_alert_silencer_enabled ? 1 : 0
  rule      = aws_cloudwatch_event_rule.spot_interrupt_rule[0].name
  arn       = aws_sqs_queue.interrupt_queue[0].arn
  target_id = "SendToSQS"
}

# Allow EventBridge to publish to SQS
resource "aws_sqs_queue_policy" "allow_eventbridge" {
  count     = var.spot_termination_alert_silencer_enabled ? 1 : 0
  queue_url = aws_sqs_queue.interrupt_queue[0].id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          Service = "events.amazonaws.com"
        },
        Action   = "sqs:SendMessage",
        Resource = aws_sqs_queue.interrupt_queue[0].arn
      }
    ]
  })
}

# IAM Trust policy for IRSA
data "aws_iam_policy_document" "assume_role_policy" {
  count = var.spot_termination_alert_silencer_enabled ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider_arn, "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/", "")}:sub"
      values   = ["system:serviceaccount:${local.service_namespace}:${local.service_account}"]
    }
  }
}

# IAM Role for IRSA
resource "aws_iam_role" "irsa_role" {
  count              = var.spot_termination_alert_silencer_enabled ? 1 : 0
  name               = "${var.cluster_name}-${local.service_account}-irsa"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy[0].json
}

# IAM Policy for accessing SQS
resource "aws_iam_role_policy" "sqs_access_policy" {
  count = var.spot_termination_alert_silencer_enabled ? 1 : 0
  name  = "${local.service_account}-sqs-access"
  role  = aws_iam_role.irsa_role[0].id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ],
        Resource = aws_sqs_queue.interrupt_queue[0].arn
      }
    ]
  })
}

# Kubernetes ServiceAccount annotated with IRSA role
resource "kubernetes_service_account" "alert_silencer" {
  count = var.spot_termination_alert_silencer_enabled ? 1 : 0

  metadata {
    name      = local.service_account
    namespace = local.service_namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.irsa_role[0].arn
    }
  }
}
