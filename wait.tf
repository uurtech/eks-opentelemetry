# Wait for the cluster to be ready before installing components
resource "time_sleep" "wait_for_cluster" {
  depends_on = [
    aws_eks_cluster.main,
    aws_eks_node_group.main
  ]

  create_duration = "30s"
}

# Check cluster readiness
data "kubernetes_nodes" "cluster_nodes" {
  depends_on = [
    time_sleep.wait_for_cluster
  ]
} 