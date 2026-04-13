#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
RESOURCE_GROUP="openclaw-production-rg"
CLUSTER_NAME="openclaw-aks-cluster"
LOCATION="eastus"
ACR_NAME="${CLUSTER_NAME}acr"

# Functions
print_header() {
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}========================================${NC}\n"
}

print_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local missing=0
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI not found. Please install: https://docs.microsoft.com/cli/azure/install-azure-cli"
        missing=1
    else
        print_success "Azure CLI found"
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform not found. Please install: https://www.terraform.io/downloads"
        missing=1
    else
        print_success "Terraform found ($(terraform version -json | jq -r '.terraform_version'))"
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install: https://kubernetes.io/docs/tasks/tools/"
        missing=1
    else
        print_success "kubectl found"
    fi
    
    # Check Helm
    if ! command -v helm &> /dev/null; then
        print_error "Helm not found. Please install: https://helm.sh/docs/intro/install/"
        missing=1
    else
        print_success "Helm found"
    fi
    
    if [ $missing -eq 1 ]; then
        print_error "Missing required tools. Please install them and try again."
        exit 1
    fi
}

azure_login() {
    print_header "Azure Login"
    
    if ! az account show &> /dev/null; then
        print_info "Not logged in to Azure. Initiating login..."
        az login
    else
        print_success "Already logged in to Azure"
        print_info "Current subscription: $(az account show --query name -o tsv)"
    fi
}

deploy_terraform() {
    print_header "Deploying Infrastructure with Terraform"
    
    # Check if terraform.tfvars exists
    if [ ! -f "terraform.tfvars" ]; then
        print_info "Creating terraform.tfvars from example..."
        cp terraform.tfvars.example terraform.tfvars
        print_error "Please edit terraform.tfvars with your values and run this script again."
        exit 1
    fi
    
    # Initialize Terraform
    print_info "Initializing Terraform..."
    terraform init
    
    # Validate
    print_info "Validating Terraform configuration..."
    terraform validate
    
    # Plan
    print_info "Creating Terraform plan..."
    terraform plan -out=tfplan
    
    # Apply
    print_info "Applying Terraform plan (this will take 10-15 minutes)..."
    terraform apply tfplan
    
    print_success "Infrastructure deployed successfully!"
}

configure_kubectl() {
    print_header "Configuring kubectl"
    
    print_info "Getting AKS credentials..."
    az aks get-credentials \
        --resource-group "$RESOURCE_GROUP" \
        --name "$CLUSTER_NAME" \
        --overwrite-existing
    
    print_success "kubectl configured"
    
    # Verify connection
    print_info "Verifying cluster connection..."
    kubectl get nodes
}

deploy_kubernetes_resources() {
    print_header "Deploying Kubernetes Resources"
    
    # Get ACR name from Terraform output
    ACR_LOGIN_SERVER=$(terraform output -raw acr_login_server)
    
    print_info "Updating deployment manifests with ACR: $ACR_LOGIN_SERVER"
    sed -i.bak "s|<your-acr>.azurecr.io|$ACR_LOGIN_SERVER|g" kubernetes/openclaw-deployments.yaml
    
    # Deploy RBAC
    print_info "Deploying RBAC and Network Policies..."
    kubectl apply -f kubernetes/rbac.yaml
    print_success "RBAC deployed"
    
    # Deploy OpenClaw
    print_info "Deploying OpenClaw instances..."
    kubectl apply -f kubernetes/openclaw-deployments.yaml
    print_success "OpenClaw deployments created"
    
    # Wait for pods
    print_info "Waiting for pods to be ready (this may take a few minutes)..."
    for namespace in openclaw-alpha openclaw-beta openclaw-gamma openclaw-delta; do
        kubectl wait --for=condition=ready pod -l app=openclaw -n $namespace --timeout=300s || true
    done
}

install_ingress() {
    print_header "Installing NGINX Ingress Controller"
    
    # Add Helm repo
    print_info "Adding Helm repository..."
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
    
    # Install NGINX Ingress
    print_info "Installing NGINX Ingress..."
    helm install nginx-ingress ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz
    
    print_success "NGINX Ingress installed"
    
    # Wait for external IP
    print_info "Waiting for external IP (this may take a few minutes)..."
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=300s
    
    # Get external IP
    EXTERNAL_IP=$(kubectl get service -n ingress-nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    print_success "NGINX Ingress ready"
    echo -e "\n${GREEN}External IP: $EXTERNAL_IP${NC}"
    echo -e "${YELLOW}Configure your DNS records to point to this IP:${NC}"
    echo "  alpha.openclaw.yourdomain.com  -> $EXTERNAL_IP"
    echo "  beta.openclaw.yourdomain.com   -> $EXTERNAL_IP"
    echo "  gamma.openclaw.yourdomain.com  -> $EXTERNAL_IP"
    echo "  delta.openclaw.yourdomain.com  -> $EXTERNAL_IP"
}

install_monitoring() {
    print_header "Installing Monitoring Stack (Optional)"
    
    read -p "Do you want to install Prometheus/Grafana monitoring? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Adding Prometheus Helm repository..."
        helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
        helm repo update
        
        print_info "Installing Prometheus stack..."
        helm install prometheus prometheus-community/kube-prometheus-stack \
            --namespace monitoring \
            --create-namespace
        
        print_info "Applying OpenClaw monitoring configuration..."
        kubectl apply -f kubernetes/monitoring.yaml
        
        print_success "Monitoring stack installed"
        
        # Get Grafana admin password
        GRAFANA_PASSWORD=$(kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode)
        echo -e "\n${GREEN}Grafana admin password: $GRAFANA_PASSWORD${NC}"
        echo "Access Grafana with: kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
    fi
}

print_summary() {
    print_header "Deployment Summary"
    
    echo -e "${GREEN}✅ Infrastructure deployed successfully!${NC}\n"
    
    echo "Resource Group: $RESOURCE_GROUP"
    echo "Cluster Name: $CLUSTER_NAME"
    echo "Location: $LOCATION"
    echo ""
    
    # Get node count
    NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
    echo "Total Nodes: $NODE_COUNT"
    echo ""
    
    # Get pod count per namespace
    echo "Pods per team:"
    for namespace in openclaw-alpha openclaw-beta openclaw-gamma openclaw-delta; do
        POD_COUNT=$(kubectl get pods -n $namespace --no-headers 2>/dev/null | wc -l)
        echo "  $namespace: $POD_COUNT"
    done
    echo ""
    
    # Useful commands
    echo -e "${YELLOW}Useful commands:${NC}"
    echo "  View all nodes:  kubectl get nodes"
    echo "  View all pods:   kubectl get pods -A"
    echo "  View services:   kubectl get svc -A"
    echo "  View ingress:    kubectl get ingress -A"
    echo "  Scale pods:      kubectl scale deployment openclaw-alpha -n openclaw-alpha --replicas=5"
    echo ""
    
    echo -e "${GREEN}Next steps:${NC}"
    echo "1. Configure DNS records with the ingress external IP"
    echo "2. Update ingress.yaml with your domain"
    echo "3. Apply ingress: kubectl apply -f kubernetes/ingress.yaml"
    echo "4. (Optional) Install cert-manager for SSL certificates"
    echo ""
    
    echo -e "${YELLOW}For cleanup, run: terraform destroy${NC}"
}

main() {
    print_header "OpenClaw AKS Deployment Script"
    
    check_prerequisites
    azure_login
    deploy_terraform
    configure_kubectl
    deploy_kubernetes_resources
    install_ingress
    install_monitoring
    print_summary
    
    print_success "Deployment complete! 🚀"
}

# Run main function
main
