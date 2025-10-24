output "service_name" {
  description = "Name of the Kubernetes service"
  value       = kubernetes_service.nginx.metadata[0].name
}

output "service_namespace" {
  description = "Namespace of the Kubernetes service"
  value       = kubernetes_service.nginx.metadata[0].namespace
}

output "load_balancer_hostname" {
  description = "Hostname of the AWS Load Balancer"
  value       = try(kubernetes_service.nginx.status[0].load_balancer[0].ingress[0].hostname, "pending")
}

output "load_balancer_url" {
  description = "Public URL for accessing the nginx service"
  value       = try("http://${kubernetes_service.nginx.status[0].load_balancer[0].ingress[0].hostname}", "Load balancer provisioning...")
}

output "deployment_name" {
  description = "Name of the nginx deployment"
  value       = kubernetes_deployment.nginx.metadata[0].name
}
