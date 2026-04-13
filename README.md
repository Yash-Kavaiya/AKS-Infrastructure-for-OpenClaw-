# OpenClaw AKS Infrastructure - 20 Node Deployment

Complete Terraform infrastructure for deploying OpenClaw AI Assistant on Azure Kubernetes Service (AKS) with 20 nodes across multiple node pools for team assignments.

## 📋 Architecture Overview

### Node Pool Distribution
- **System Pool**: 3 nodes (Standard_D2s_v3) - Kubernetes system components
- **Production Pool**: 8 nodes (Standard_D4s_v3) - OpenClaw app workloads
- **Compute Pool**: 5 nodes (Standard_F8s_v2) - AI processing tasks
- **Memory Pool**: 4 nodes (Standard_E4s_v3) - Data-intensive operations

**Total: 20 worker nodes + 3 system nodes = 23 total nodes**

### Team Assignments
- **Team Alpha**: 3 replicas on Production nodes
- **Team Beta**: 3 replicas on Production nodes
- **Team Gamma**: 2 replicas on Compute nodes
- **Team Delta**: 2 replicas on Memory nodes

## 🚀 Prerequisites

### Required Tools
```bash
# Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### Azure Subscription
```bash
# Login to Azure
az login

# Set subscription
az account set --subscription "your-subscription-id"

# Verify
az account show
```

## 📦 Project Structure

```
.
├── main.tf                           # Main Terraform configuration
├── variables.tf                      # Variable definitions
├── outputs.tf                        # Output values
├── terraform.tfvars.example          # Example variables
└── kubernetes/
    ├── openclaw-deployments.yaml     # Team deployments
    ├── ingress.yaml                  # Ingress configuration
    └── rbac.yaml                     # RBAC and network policies
```

## 🔧 Deployment Steps

### Step 1: Configure Terraform Variables

```bash
# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

Required configurations:
```hcl
resource_group_name = "openclaw-production-rg"
location            = "eastus"
cluster_name        = "openclaw-aks-cluster"
environment         = "production"
kubernetes_version  = "1.28.0"
```

### Step 2: Initialize Terraform

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Preview changes
terraform plan
```

### Step 3: Deploy Infrastructure

```bash
# Deploy all resources (takes 10-15 minutes)
terraform apply

# Confirm with: yes
```

Expected output:
```
Apply complete! Resources: 12 added, 0 changed, 0 destroyed.

Outputs:
aks_cluster_name = "openclaw-aks-cluster"
get_credentials_command = "az aks get-credentials --resource-group openclaw-production-rg --name openclaw-aks-cluster"
total_nodes = "System: 3, Production: 8, Compute: 5, Memory: 4 = Total 20 nodes"
```

### Step 4: Configure kubectl

```bash
# Get AKS credentials
az aks get-credentials \
  --resource-group openclaw-production-rg \
  --name openclaw-aks-cluster \
  --overwrite-existing

# Verify connection
kubectl get nodes

# Expected output: 23 nodes (3 system + 20 worker)
```

### Step 5: Verify Node Pools

```bash
# Check node pools
az aks nodepool list \
  --resource-group openclaw-production-rg \
  --cluster-name openclaw-aks-cluster \
  --output table

# View nodes by pool
kubectl get nodes --show-labels | grep nodepool-type
```

### Step 6: Deploy OpenClaw to Kubernetes

```bash
# Update ACR image references in deployments
# Replace <your-acr>.azurecr.io with your actual ACR name
sed -i 's/<your-acr>/openclaw-aks-clusteracr/g' kubernetes/openclaw-deployments.yaml

# Apply RBAC and network policies
kubectl apply -f kubernetes/rbac.yaml

# Deploy OpenClaw instances
kubectl apply -f kubernetes/openclaw-deployments.yaml

# Verify deployments
kubectl get pods --all-namespaces | grep openclaw
```

### Step 7: Install NGINX Ingress Controller

```bash
# Add Helm repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install NGINX Ingress
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz

# Wait for external IP
kubectl get service -n ingress-nginx nginx-ingress-ingress-nginx-controller --watch
```

### Step 8: Configure DNS and Deploy Ingress

```bash
# Get external IP
EXTERNAL_IP=$(kubectl get service -n ingress-nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "External IP: $EXTERNAL_IP"

# Update DNS records to point to this IP:
# alpha.openclaw.yourdomain.com  -> $EXTERNAL_IP
# beta.openclaw.yourdomain.com   -> $EXTERNAL_IP
# gamma.openclaw.yourdomain.com  -> $EXTERNAL_IP
# delta.openclaw.yourdomain.com  -> $EXTERNAL_IP

# Update ingress.yaml with your domain
sed -i 's/yourdomain.com/your-actual-domain.com/g' kubernetes/ingress.yaml

# Apply ingress
kubectl apply -f kubernetes/ingress.yaml
```

### Step 9: Install cert-manager for SSL (Optional)

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Create ClusterIssuer for Let's Encrypt
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

## 🔍 Verification & Monitoring

### Check Cluster Health

```bash
# View all nodes
kubectl get nodes -o wide

# Check node pools
kubectl get nodes -L agentpool,workload

# View pod distribution
kubectl get pods -A -o wide | grep openclaw

# Check autoscaling status
kubectl get hpa -A
```

### Monitor Resources

```bash
# View resource usage per namespace
kubectl top pods -n openclaw-alpha
kubectl top pods -n openclaw-beta
kubectl top pods -n openclaw-gamma
kubectl top pods -n openclaw-delta

# View node resource usage
kubectl top nodes

# Check logs
kubectl logs -n openclaw-alpha -l app=openclaw --tail=100 -f
```

### Access Applications

```bash
# Get service endpoints
kubectl get ingress -A

# Get LoadBalancer IPs
kubectl get svc -A | grep LoadBalancer

# Test endpoints
curl -k https://alpha.openclaw.yourdomain.com/health
curl -k https://beta.openclaw.yourdomain.com/health
curl -k https://gamma.openclaw.yourdomain.com/health
curl -k https://delta.openclaw.yourdomain.com/health
```

## 📊 Scaling Operations

### Manual Scaling

```bash
# Scale team deployment
kubectl scale deployment openclaw-alpha -n openclaw-alpha --replicas=5

# Scale node pool
az aks nodepool scale \
  --resource-group openclaw-production-rg \
  --cluster-name openclaw-aks-cluster \
  --name production \
  --node-count 10
```

### Update Autoscaling

```bash
# Update HPA
kubectl autoscale deployment openclaw-alpha \
  -n openclaw-alpha \
  --min=3 \
  --max=15 \
  --cpu-percent=70
```

## 🔐 Security Best Practices

1. **Enable Azure AD Integration**
```bash
az aks update \
  --resource-group openclaw-production-rg \
  --name openclaw-aks-cluster \
  --enable-aad \
  --enable-azure-rbac
```

2. **Enable Network Policies** (already configured in Terraform)

3. **Configure Pod Security Standards**
```bash
kubectl label namespace openclaw-alpha pod-security.kubernetes.io/enforce=restricted
kubectl label namespace openclaw-beta pod-security.kubernetes.io/enforce=restricted
```

## 💰 Cost Estimation

Monthly cost breakdown (approximate):
- **System nodes** (3x D2s_v3): ~$230
- **Production nodes** (8x D4s_v3): ~$920
- **Compute nodes** (5x F8s_v2): ~$725
- **Memory nodes** (4x E4s_v3): ~$580
- **Load Balancer**: ~$25
- **Azure Monitor/Logs**: ~$50

**Total estimated monthly cost: ~$2,530 USD**

## 🧹 Cleanup

```bash
# Delete Kubernetes resources
kubectl delete -f kubernetes/openclaw-deployments.yaml
kubectl delete -f kubernetes/ingress.yaml
kubectl delete -f kubernetes/rbac.yaml

# Destroy Terraform infrastructure
terraform destroy

# Confirm with: yes
```

## 🆘 Troubleshooting

### Pods not starting
```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
```

### Node pool issues
```bash
az aks nodepool show \
  --resource-group openclaw-production-rg \
  --cluster-name openclaw-aks-cluster \
  --name production
```

### Networking issues
```bash
kubectl get networkpolicies -A
kubectl describe networkpolicy -n openclaw-alpha
```

## 📚 Additional Resources

- [Azure AKS Documentation](https://docs.microsoft.com/azure/aks/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [OpenClaw Documentation](https://openclaw.ai/docs)

## 🤝 Support

For issues or questions:
1. Check logs: `kubectl logs -n <namespace> <pod-name>`
2. Review Azure Portal for infrastructure issues
3. Check Terraform state: `terraform show`

---

**Note**: Replace placeholder values (domain names, ACR names, email addresses) with your actual values before deployment.
