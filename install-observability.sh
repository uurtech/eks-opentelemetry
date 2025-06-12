#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting observability stack installation...${NC}"

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"
if ! command -v helm &> /dev/null; then
    echo -e "${RED}Helm is not installed. Please install Helm first.${NC}"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl is not installed. Please install kubectl first.${NC}"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo -e "${RED}AWS CLI is not installed. Please install AWS CLI first.${NC}"
    exit 1
fi

# Check if terraform outputs are available
if ! terraform output > /dev/null 2>&1; then
    echo -e "${RED}Terraform outputs not available. Please run 'terraform apply' first.${NC}"
    exit 1
fi

echo -e "${GREEN}Prerequisites check passed!${NC}"

# Add Helm repositories
echo -e "${YELLOW}Adding Helm repositories...${NC}"
helm repo add eks https://aws.github.io/eks-charts
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo add fluent https://fluent.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Get required values from terraform and AWS
echo -e "${YELLOW}Getting required values...${NC}"
export VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query "Vpcs[0].VpcId" --output text)
export ADOT_ROLE_ARN=$(terraform output -raw adot_collector_role_arn)
export FLUENTD_ROLE_ARN=$(terraform output -raw fluentd_role_arn)
export CLUSTER_NAME=$(terraform output -raw cluster_name)
export AWS_REGION=$(terraform output -raw region)

echo "VPC ID: $VPC_ID"
echo "ADOT Role ARN: $ADOT_ROLE_ARN"
echo "Fluentd Role ARN: $FLUENTD_ROLE_ARN"
echo "Cluster Name: $CLUSTER_NAME"
echo "AWS Region: $AWS_REGION"

# Update values files with actual values
echo -e "${YELLOW}Updating values files with actual cluster values...${NC}"
sed -i.bak "s/eks-observability-cluster/$CLUSTER_NAME/g" helm-values/*.yaml
sed -i.bak "s/us-west-2/$AWS_REGION/g" helm-values/*.yaml

# Install AWS Load Balancer Controller
echo -e "${YELLOW}Installing AWS Load Balancer Controller...${NC}"
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  -f helm-values/aws-load-balancer-controller.yaml \
  --set vpcId=${VPC_ID} \
  --wait --timeout 10m

echo -e "${GREEN}AWS Load Balancer Controller installed successfully!${NC}"

# Install ADOT Collector
echo -e "${YELLOW}Installing ADOT Collector...${NC}"
helm upgrade --install adot-collector open-telemetry/opentelemetry-collector \
  -n amazon-cloudwatch \
  -f helm-values/adot-collector.yaml \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=${ADOT_ROLE_ARN} \
  --wait --timeout 10m

echo -e "${GREEN}ADOT Collector installed successfully!${NC}"

# Install Fluentd
echo -e "${YELLOW}Installing Fluentd...${NC}"
helm upgrade --install fluentd fluent/fluentd \
  -n fluentd \
  -f helm-values/fluentd.yaml \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=${FLUENTD_ROLE_ARN} \
  --wait --timeout 10m

echo -e "${GREEN}Fluentd installed successfully!${NC}"

# Install Prometheus + Grafana
echo -e "${YELLOW}Installing Prometheus and Grafana...${NC}"
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --create-namespace \
  -f helm-values/prometheus-grafana.yaml \
  --wait --timeout 15m

echo -e "${GREEN}Prometheus and Grafana installed successfully!${NC}"

# Restore original values files
echo -e "${YELLOW}Restoring original values files...${NC}"
for file in helm-values/*.yaml.bak; do
  if [ -f "$file" ]; then
    mv "$file" "${file%.bak}"
  fi
done

# Wait for LoadBalancers to be ready
echo -e "${YELLOW}Waiting for LoadBalancers to be ready...${NC}"
echo "This may take a few minutes..."

# Get LoadBalancer URLs
echo -e "${YELLOW}Getting service URLs...${NC}"
sleep 30  # Give some time for LoadBalancers to provision

echo -e "${GREEN}Installation completed successfully!${NC}"
echo ""
echo -e "${YELLOW}Access Information:${NC}"
echo ""

# Get Grafana URL
GRAFANA_URL=$(kubectl get svc -n monitoring prometheus-grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "Pending...")
echo -e "${GREEN}Grafana URL:${NC} http://$GRAFANA_URL"
echo -e "${GREEN}Grafana Credentials:${NC} admin / admin123!"

# Get Prometheus URL
PROMETHEUS_URL=$(kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "Pending...")
echo -e "${GREEN}Prometheus URL:${NC} http://$PROMETHEUS_URL:9090"

echo ""
echo -e "${YELLOW}CloudWatch Integration:${NC}"
echo "- Container Insights: AWS Console -> CloudWatch -> Container Insights"
echo "- Logs: AWS Console -> CloudWatch -> Log Groups -> /aws/eks/$CLUSTER_NAME/fluentd"
echo "- X-Ray Traces: AWS Console -> X-Ray -> Traces"

echo ""
echo -e "${YELLOW}Note:${NC} If URLs show 'Pending', LoadBalancers are still being provisioned."
echo "Run the following commands in a few minutes to get the actual URLs:"
echo ""
echo "kubectl get svc -n monitoring prometheus-grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
echo "kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'" 