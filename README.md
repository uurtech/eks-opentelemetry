# EKS Observability Stack with ADOT and Fluentd

This Terraform configuration deploys a complete observability stack on Amazon EKS with:

- **Amazon EKS** cluster with managed node groups
- **AWS Distro for OpenTelemetry (ADOT)** for metrics and traces collection
- **Fluentd** for log aggregation and forwarding to CloudWatch
- **Prometheus** for metrics storage and querying
- **Grafana** for visualization with pre-configured dashboards
- **AWS Load Balancer Controller** for ingress management
- **CloudWatch Container Insights** for container and cluster monitoring
- **AWS X-Ray** for distributed tracing

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Applications  │───▶│   ADOT Collector │───▶│   CloudWatch    │
│                 │    │                  │    │   Container     │
│                 │    │  - Metrics       │    │   Insights      │
│                 │    │  - Traces        │    │                 │
│                 │    │  - Logs          │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│    Fluentd      │───▶│   CloudWatch     │    │    AWS X-Ray    │
│   DaemonSet     │    │     Logs         │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │
         ▼
┌─────────────────┐    ┌──────────────────┐
│   Prometheus    │───▶│     Grafana      │
│                 │    │   Dashboards     │
└─────────────────┘    └──────────────────┘
```

## Features

### ✅ Observability Best Practices
- **Metrics**: Cluster, node, pod, and application metrics via Prometheus and CloudWatch
- **Logs**: Centralized logging with Fluentd to CloudWatch Logs
- **Traces**: Distributed tracing with ADOT and AWS X-Ray
- **Dashboards**: Pre-configured Grafana dashboards for Kubernetes monitoring

### ✅ Security & IAM
- IAM roles with least privilege access
- Service accounts with IRSA (IAM Roles for Service Accounts)
- Proper network security groups

### ✅ High Availability
- Multi-AZ deployment using default VPC subnets
- Auto-scaling node groups
- Persistent storage for Grafana and Prometheus

### ✅ Cost Optimization
- Right-sized instance types (t3.medium by default)
- Log retention policies
- Resource limits and requests

## Prerequisites

1. **AWS CLI** configured with appropriate permissions
2. **Terraform** >= 1.0
3. **kubectl** for cluster management
4. **Helm** (optional, for manual chart management)

### Required AWS Permissions

Your AWS credentials need the following permissions:
- EKS cluster creation and management
- EC2 instance and VPC management
- IAM role and policy creation
- CloudWatch and X-Ray access
- Load Balancer management

## Quick Start

### Step 1: Deploy Infrastructure
1. **Clone and configure**:
   ```bash
   cd /path/to/this/directory
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your preferred settings
   ```

2. **Deploy infrastructure**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. **Configure kubectl**:
   ```bash
   aws eks --region us-west-2 update-kubeconfig --name eks-observability-cluster
   ```

### Step 2: Install Observability Components with Helm

After the infrastructure is deployed, you have two options to install the observability stack:

#### Option A: Use the Convenience Script (Recommended)
```bash
./install-observability.sh
```

#### Option B: Manual Installation

#### 1. Install AWS Load Balancer Controller
```bash
# Add the EKS repository
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Get VPC ID
export VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query "Vpcs[0].VpcId" --output text)

# Install with values
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  -f helm-values/aws-load-balancer-controller.yaml \
  --set vpcId=${VPC_ID} \
  --wait --timeout 10m
```

#### 2. Install ADOT Collector
```bash
# Add OpenTelemetry repository
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

# Get ADOT IAM role ARN
export ADOT_ROLE_ARN=$(terraform output -raw adot_collector_role_arn)

# Install ADOT Collector
helm install adot-collector open-telemetry/opentelemetry-collector \
  -n amazon-cloudwatch \
  -f helm-values/adot-collector.yaml \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=${ADOT_ROLE_ARN} \
  --wait --timeout 10m
```

#### 3. Install Fluentd
```bash
# Add Fluent repository
helm repo add fluent https://fluent.github.io/helm-charts
helm repo update

# Get Fluentd IAM role ARN
export FLUENTD_ROLE_ARN=$(terraform output -raw fluentd_role_arn)

# Install Fluentd
helm install fluentd fluent/fluentd \
  -n fluentd \
  -f helm-values/fluentd.yaml \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=${FLUENTD_ROLE_ARN} \
  --wait --timeout 10m
```

#### 4. Install Prometheus + Grafana
```bash
# Add Prometheus repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus and Grafana
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --create-namespace \
  -f helm-values/prometheus-grafana.yaml \
  --wait --timeout 15m
```

### Step 3: Access the UIs

#### **Access Grafana**:
```bash
# Get Grafana URL
kubectl get svc -n monitoring prometheus-grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Default credentials:
# Username: admin
# Password: admin123!
```

#### **Access Prometheus**:
```bash
kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## Configuration

### Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region to deploy resources | `us-west-2` |
| `cluster_name` | Name of the EKS cluster | `eks-observability-cluster` |
| `kubernetes_version` | Kubernetes version | `1.28` |
| `environment` | Environment name | `production` |
| `node_instance_types` | EC2 instance types for nodes | `["t3.medium"]` |
| `desired_capacity` | Desired number of nodes | `2` |
| `max_capacity` | Maximum number of nodes | `4` |
| `min_capacity` | Minimum number of nodes | `1` |

### Customization

Create a `terraform.tfvars` file to customize the deployment:

```hcl
aws_region     = "us-east-1"
cluster_name   = "my-observability-cluster"
environment    = "staging"
desired_capacity = 3
max_capacity   = 6
```

## Accessing Services

### Grafana Dashboards

The deployment includes pre-configured dashboards:
- **Kubernetes Cluster Monitoring** (ID: 7249)
- **Kubernetes Pod Monitoring** (ID: 6417)
- **Fluentd Monitoring** (ID: 3131)

### CloudWatch Integration

- **Container Insights**: AWS Console → CloudWatch → Container Insights
- **Logs**: AWS Console → CloudWatch → Log Groups → `/aws/eks/{cluster-name}/fluentd`
- **X-Ray Traces**: AWS Console → X-Ray → Traces

### ADOT Endpoints

- **OTLP gRPC**: `adot-collector-opentelemetry-collector.amazon-cloudwatch.svc.cluster.local:4317`
- **OTLP HTTP**: `adot-collector-opentelemetry-collector.amazon-cloudwatch.svc.cluster.local:4318`
- **Metrics**: `adot-collector-opentelemetry-collector.amazon-cloudwatch.svc.cluster.local:8888`

## Troubleshooting

### Helm Installation Issues

1. **Check Helm repository status**:
   ```bash
   helm repo list
   helm repo update
   ```

2. **Check failed Helm releases**:
   ```bash
   helm list --all-namespaces
   helm status <release-name> -n <namespace>
   ```

3. **Debug Helm installation**:
   ```bash
   # For dry-run testing
   helm install <release-name> <chart> --dry-run --debug -f <values-file>
   
   # For troubleshooting existing installation
   helm get values <release-name> -n <namespace>
   helm get manifest <release-name> -n <namespace>
   ```

4. **Clean up failed Helm installation**:
   ```bash
   helm uninstall <release-name> -n <namespace>
   # Then retry installation
   ```

### Common Issues

1. **Pods stuck in Pending state**:
   ```bash
   kubectl describe nodes
   kubectl get events --sort-by='.metadata.creationTimestamp'
   ```

2. **Load Balancer not getting external IP**:
   ```bash
   kubectl get events -n kube-system | grep aws-load-balancer-controller
   kubectl logs -n kube-system deployment/aws-load-balancer-controller
   ```

3. **ADOT Collector issues**:
   ```bash
   kubectl logs -n amazon-cloudwatch deployment/adot-collector-opentelemetry-collector
   kubectl describe pod -n amazon-cloudwatch -l app.kubernetes.io/name=opentelemetry-collector
   ```

4. **Fluentd issues**:
   ```bash
   kubectl logs -n fluentd daemonset/fluentd
   kubectl describe pod -n fluentd -l app=fluentd
   ```

5. **IAM permissions issues**:
   ```bash
   # Check service account annotations
   kubectl get sa -n amazon-cloudwatch adot-collector -o yaml
   kubectl get sa -n fluentd fluentd -o yaml
   kubectl get sa -n kube-system aws-load-balancer-controller -o yaml
   
   # Check if roles exist
   aws iam get-role --role-name eks-observability-cluster-adot-collector-role
   aws iam get-role --role-name eks-observability-cluster-fluentd-role
   ```

### Useful Commands

```bash
# Check cluster status
kubectl get nodes
kubectl get pods --all-namespaces

# Check Helm releases
helm list --all-namespaces

# View logs
kubectl logs -n amazon-cloudwatch deployment/adot-collector-opentelemetry-collector
kubectl logs -n fluentd daemonset/fluentd

# Check services
kubectl get svc --all-namespaces
```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Note**: This will delete all resources including persistent volumes and data.

## Security Considerations

- Change the default Grafana password in production
- Review IAM policies and adjust permissions as needed
- Enable additional security features like Pod Security Standards
- Consider using AWS Secrets Manager for sensitive configuration

## Cost Estimation

Approximate monthly costs (us-west-2):
- EKS Cluster: ~$73
- EC2 Instances (2x t3.medium): ~$60
- Load Balancers: ~$16-32
- CloudWatch Logs/Metrics: Variable based on usage
- EBS Storage: ~$10

**Total estimated cost**: ~$160-180/month (excluding data transfer and variable costs)

## File Structure

```
├── main.tf                                    # Core EKS infrastructure
├── helm.tf                                   # IAM roles and policies for Helm charts  
├── wait.tf                                   # Cluster readiness configuration
├── variables.tf                              # Input variables
├── outputs.tf                               # Output values
├── terraform.tfvars.example                 # Example configuration
├── install-observability.sh                 # Convenience installation script
├── helm-values/
│   ├── aws-load-balancer-controller.yaml   # AWS LB Controller values
│   ├── adot-collector.yaml                 # ADOT Collector values
│   ├── fluentd.yaml                        # Fluentd values
│   └── prometheus-grafana.yaml             # Prometheus + Grafana values
└── README.md                               # This file
```

## Architecture Components

- **EKS Cluster**: Managed Kubernetes cluster with IRSA support
- **ADOT Collector**: Collects metrics, traces, and logs
- **Fluentd**: Log aggregation and forwarding to CloudWatch
- **Prometheus**: Metrics storage and alerting
- **Grafana**: Visualization and dashboards
- **CloudWatch**: AWS native monitoring and logging
- **X-Ray**: Distributed tracing
- **Load Balancer Controller**: Ingress and service management

## Contributing

Feel free to submit issues and enhancement requests!

## License

This project is licensed under the MIT License. 