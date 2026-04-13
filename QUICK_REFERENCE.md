# OpenClaw AKS - Quick Reference Guide

## 🚀 Quick Start

### Automated Deployment
```bash
# One-command deployment
./deploy.sh
```

### Manual Deployment
```bash
# 1. Initialize and deploy infrastructure
terraform init
terraform plan
terraform apply

# 2. Configure kubectl
az aks get-credentials --resource-group openclaw-production-rg --name openclaw-aks-cluster

# 3. Deploy applications
kubectl apply -f kubernetes/rbac.yaml
kubectl apply -f kubernetes/openclaw-deployments.yaml
```

## 📊 Common Commands

### Cluster Information
```bash
# View all nodes
kubectl get nodes

# View nodes by pool
kubectl get nodes -L agentpool

# View cluster info
kubectl cluster-info

# Get AKS details
az aks show --resource-group openclaw-production-rg --name openclaw-aks-cluster
```

### Pod Management
```bash
# View all pods
kubectl get pods -A

# View pods for specific team
kubectl get pods -n openclaw-alpha

# Get pod logs
kubectl logs -n openclaw-alpha <pod-name>

# Follow pod logs
kubectl logs -n openclaw-alpha <pod-name> -f

# Describe pod (for troubleshooting)
kubectl describe pod -n openclaw-alpha <pod-name>

# Execute command in pod
kubectl exec -it -n openclaw-alpha <pod-name> -- /bin/bash
```

### Scaling Operations
```bash
# Scale deployment
kubectl scale deployment openclaw-alpha -n openclaw-alpha --replicas=5

# View HPA status
kubectl get hpa -A

# Update HPA
kubectl autoscale deployment openclaw-alpha -n openclaw-alpha --min=3 --max=15 --cpu-percent=70

# Scale node pool
az aks nodepool scale \
  --resource-group openclaw-production-rg \
  --cluster-name openclaw-aks-cluster \
  --name production \
  --node-count 10
```

### Resource Monitoring
```bash
# View resource usage
kubectl top nodes
kubectl top pods -A

# View resource usage for specific namespace
kubectl top pods -n openclaw-alpha

# View events
kubectl get events -A --sort-by='.lastTimestamp'

# View resource quotas
kubectl get resourcequotas -A
```

### Service & Networking
```bash
# View all services
kubectl get svc -A

# View ingress
kubectl get ingress -A

# View network policies
kubectl get networkpolicies -A

# Test service connectivity
kubectl run -it --rm debug --image=busybox --restart=Never -- wget -O- http://openclaw-alpha-service.openclaw-alpha.svc.cluster.local
```

### Configuration Management
```bash
# View ConfigMaps
kubectl get configmaps -A

# View Secrets
kubectl get secrets -A

# Edit deployment
kubectl edit deployment openclaw-alpha -n openclaw-alpha

# Apply changes
kubectl apply -f kubernetes/openclaw-deployments.yaml

# Restart deployment
kubectl rollout restart deployment openclaw-alpha -n openclaw-alpha

# View rollout status
kubectl rollout status deployment openclaw-alpha -n openclaw-alpha
```

### Troubleshooting
```bash
# Check pod status
kubectl get pods -n openclaw-alpha -o wide

# View pod events
kubectl describe pod -n openclaw-alpha <pod-name>

# View container logs
kubectl logs -n openclaw-alpha <pod-name> -c <container-name>

# Previous pod logs (if crashed)
kubectl logs -n openclaw-alpha <pod-name> --previous

# Debug network issues
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- /bin/bash

# Check DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup openclaw-alpha-service.openclaw-alpha.svc.cluster.local
```

## 🔐 Security Commands

### RBAC
```bash
# View service accounts
kubectl get serviceaccounts -A

# View roles
kubectl get roles -A

# View role bindings
kubectl get rolebindings -A

# Check permissions
kubectl auth can-i get pods -n openclaw-alpha --as=system:serviceaccount:openclaw-alpha:openclaw-alpha-sa
```

### Secrets Management
```bash
# Create secret
kubectl create secret generic my-secret -n openclaw-alpha --from-literal=key1=value1

# View secret (base64 encoded)
kubectl get secret my-secret -n openclaw-alpha -o yaml

# Decode secret
kubectl get secret my-secret -n openclaw-alpha -o jsonpath='{.data.key1}' | base64 -d
```

## 📦 Container Registry
```bash
# Login to ACR
az acr login --name openclaw-aks-clusteracr

# List repositories
az acr repository list --name openclaw-aks-clusteracr

# List tags
az acr repository show-tags --name openclaw-aks-clusteracr --repository openclaw

# Build and push image
docker build -t openclaw-aks-clusteracr.azurecr.io/openclaw:v1.0 .
docker push openclaw-aks-clusteracr.azurecr.io/openclaw:v1.0
```

## 🎯 Team-Specific Commands

### Team Alpha
```bash
# View resources
kubectl get all -n openclaw-alpha

# Scale
kubectl scale deployment openclaw-alpha -n openclaw-alpha --replicas=5

# Update image
kubectl set image deployment/openclaw-alpha openclaw=openclaw-aks-clusteracr.azurecr.io/openclaw:v2.0 -n openclaw-alpha
```

### Team Beta
```bash
kubectl get all -n openclaw-beta
kubectl scale deployment openclaw-beta -n openclaw-beta --replicas=4
```

### Team Gamma (Compute-Intensive)
```bash
kubectl get all -n openclaw-gamma
kubectl scale deployment openclaw-gamma -n openclaw-gamma --replicas=3
```

### Team Delta (Memory-Intensive)
```bash
kubectl get all -n openclaw-delta
kubectl scale deployment openclaw-delta -n openclaw-delta --replicas=3
```

## 💰 Cost Management
```bash
# View cost estimate
./cost-estimate.sh

# View actual costs in Azure
az consumption usage list --start-date 2024-01-01 --end-date 2024-01-31

# Set budget alerts
az consumption budget create \
  --resource-group openclaw-production-rg \
  --budget-name monthly-budget \
  --amount 3000 \
  --time-grain Monthly \
  --start-date 2024-01-01
```

## 🧹 Cleanup Commands

### Delete Specific Resources
```bash
# Delete deployment
kubectl delete deployment openclaw-alpha -n openclaw-alpha

# Delete namespace (deletes all resources in it)
kubectl delete namespace openclaw-alpha

# Delete ingress
kubectl delete ingress -n openclaw-alpha openclaw-alpha-ingress
```

### Full Cleanup
```bash
# Delete all Kubernetes resources
kubectl delete -f kubernetes/openclaw-deployments.yaml
kubectl delete -f kubernetes/ingress.yaml
kubectl delete -f kubernetes/rbac.yaml

# Destroy Terraform infrastructure
terraform destroy

# Or delete resource group (faster but destroys everything)
az group delete --name openclaw-production-rg --yes --no-wait
```

## 📈 Monitoring Commands

### Prometheus/Grafana (if installed)
```bash
# Port forward Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Port forward Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# View alerts
kubectl get prometheusrules -n monitoring
```

### Azure Monitor
```bash
# View logs
az monitor log-analytics query \
  --workspace $(az aks show -g openclaw-production-rg -n openclaw-aks-cluster --query addonProfiles.omsagent.config.logAnalyticsWorkspaceResourceID -o tsv) \
  --analytics-query "ContainerLog | limit 100"
```

## 🔄 Update & Upgrade

### Update Application
```bash
# Update deployment with new image
kubectl set image deployment/openclaw-alpha openclaw=openclaw-aks-clusteracr.azurecr.io/openclaw:v2.0 -n openclaw-alpha

# Or edit deployment file and apply
kubectl apply -f kubernetes/openclaw-deployments.yaml
```

### Upgrade Kubernetes Version
```bash
# Check available versions
az aks get-upgrades --resource-group openclaw-production-rg --name openclaw-aks-cluster

# Upgrade cluster
az aks upgrade \
  --resource-group openclaw-production-rg \
  --name openclaw-aks-cluster \
  --kubernetes-version 1.29.0
```

### Update Terraform
```bash
# Update resources
terraform plan
terraform apply

# Or update specific resource
terraform apply -target=azurerm_kubernetes_cluster_node_pool.production
```

## 📝 Backup & Restore

### Backup with Velero (optional)
```bash
# Install Velero
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm install velero vmware-tanzu/velero --namespace velero --create-namespace

# Create backup
velero backup create openclaw-backup --include-namespaces openclaw-alpha,openclaw-beta,openclaw-gamma,openclaw-delta

# Restore
velero restore create --from-backup openclaw-backup
```

## 🆘 Emergency Procedures

### Node Issues
```bash
# Drain node for maintenance
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Cordon node (prevent scheduling)
kubectl cordon <node-name>

# Uncordon node
kubectl uncordon <node-name>

# Delete problematic node
kubectl delete node <node-name>
```

### Cluster Recovery
```bash
# Restart all pods in namespace
kubectl delete pods --all -n openclaw-alpha

# Force delete stuck pod
kubectl delete pod <pod-name> -n openclaw-alpha --force --grace-period=0

# Recreate failed deployments
kubectl replace --force -f kubernetes/openclaw-deployments.yaml
```

## 📞 Support Resources

- [Azure AKS Documentation](https://docs.microsoft.com/azure/aks/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [OpenClaw Documentation](https://openclaw.ai/docs)

---

**Tip**: Save this file and use it as a cheat sheet for daily operations!
