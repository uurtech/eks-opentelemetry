output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "cluster_iam_role_name" {
  description = "IAM role name associated with EKS cluster"
  value       = aws_iam_role.eks_cluster_role.name
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "node_groups" {
  description = "EKS node groups"
  value       = aws_eks_node_group.main.node_group_name
}

output "region" {
  description = "AWS region"
  value       = var.aws_region
}

output "grafana_admin_password" {
  description = "Grafana admin password"
  value       = "admin123!"
  sensitive   = true
}

output "grafana_url" {
  description = "Grafana URL (will be available after LoadBalancer is provisioned)"
  value       = "Check 'kubectl get svc -n monitoring prometheus-grafana' for external IP"
}

output "prometheus_url" {
  description = "Prometheus URL (will be available after LoadBalancer is provisioned)"
  value       = "Check 'kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus' for external IP"
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group for Fluentd logs"
  value       = aws_cloudwatch_log_group.fluentd.name
}

output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = "aws eks --region ${var.aws_region} update-kubeconfig --name ${aws_eks_cluster.main.name}"
}

output "adot_collector_service" {
  description = "ADOT Collector service endpoint"
  value       = "adot-collector-opentelemetry-collector.amazon-cloudwatch.svc.cluster.local:4317"
}

output "adot_collector_role_arn" {
  description = "IAM role ARN for ADOT Collector"
  value       = aws_iam_role.adot_collector_role.arn
}

output "fluentd_role_arn" {
  description = "IAM role ARN for Fluentd"
  value       = aws_iam_role.fluentd_role.arn
}

output "aws_load_balancer_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  value       = aws_iam_role.aws_load_balancer_controller.arn
}

output "access_instructions" {
  description = "Instructions to access the observability UIs"
  value = <<EOF
To access your observability stack:

1. Configure kubectl:
   ${local.kubectl_config_command}

2. Get Grafana URL:
   kubectl get svc -n monitoring prometheus-grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

3. Get Prometheus URL:
   kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

4. Grafana Login:
   Username: admin
   Password: ${local.grafana_password}

5. Check CloudWatch Logs:
   AWS Console -> CloudWatch -> Log groups -> ${aws_cloudwatch_log_group.fluentd.name}

6. Check AWS X-Ray traces:
   AWS Console -> X-Ray -> Traces

7. Check Container Insights:
   AWS Console -> CloudWatch -> Container Insights
EOF
}

locals {
  kubectl_config_command = "aws eks --region ${var.aws_region} update-kubeconfig --name ${aws_eks_cluster.main.name}"
  grafana_password       = "admin123!"
} 