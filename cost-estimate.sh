#!/bin/bash

# Azure AKS Cost Estimator for OpenClaw Deployment

echo "=================================================="
echo "Azure AKS Cost Estimator - OpenClaw Deployment"
echo "=================================================="
echo ""

# VM Pricing (East US region - adjust for your region)
# Prices as of 2024 (approximate)

# System pool
SYSTEM_VM="Standard_D2s_v3"
SYSTEM_COUNT=3
SYSTEM_PRICE_PER_HOUR=0.096
SYSTEM_HOURS_PER_MONTH=730

# Production pool
PROD_VM="Standard_D4s_v3"
PROD_COUNT=8
PROD_PRICE_PER_HOUR=0.192
PROD_HOURS_PER_MONTH=730

# Compute pool
COMPUTE_VM="Standard_F8s_v2"
COMPUTE_COUNT=5
COMPUTE_PRICE_PER_HOUR=0.190
COMPUTE_HOURS_PER_MONTH=730

# Memory pool
MEMORY_VM="Standard_E4s_v3"
MEMORY_COUNT=4
MEMORY_PRICE_PER_HOUR=0.252
MEMORY_HOURS_PER_MONTH=730

# Additional services
LB_PRICE_PER_MONTH=25
MONITOR_PRICE_PER_MONTH=50
ACR_PRICE_PER_MONTH=20
STORAGE_PRICE_PER_MONTH=30
BANDWIDTH_PRICE_PER_MONTH=50

# Calculate costs
SYSTEM_COST=$(echo "$SYSTEM_COUNT * $SYSTEM_PRICE_PER_HOUR * $SYSTEM_HOURS_PER_MONTH" | bc)
PROD_COST=$(echo "$PROD_COUNT * $PROD_PRICE_PER_HOUR * $PROD_HOURS_PER_MONTH" | bc)
COMPUTE_COST=$(echo "$COMPUTE_COUNT * $COMPUTE_PRICE_PER_HOUR * $COMPUTE_HOURS_PER_MONTH" | bc)
MEMORY_COST=$(echo "$MEMORY_COUNT * $MEMORY_PRICE_PER_HOUR * $MEMORY_HOURS_PER_MONTH" | bc)

COMPUTE_TOTAL=$(echo "$SYSTEM_COST + $PROD_COST + $COMPUTE_COST + $MEMORY_COST" | bc)
SERVICES_TOTAL=$(echo "$LB_PRICE_PER_MONTH + $MONITOR_PRICE_PER_MONTH + $ACR_PRICE_PER_MONTH + $STORAGE_PRICE_PER_MONTH + $BANDWIDTH_PRICE_PER_MONTH" | bc)
TOTAL_MONTHLY=$(echo "$COMPUTE_TOTAL + $SERVICES_TOTAL" | bc)
TOTAL_YEARLY=$(echo "$TOTAL_MONTHLY * 12" | bc)

# Print breakdown
echo "NODE POOL COSTS:"
echo "----------------------------------------"
printf "System Pool (%dx %s):\n" $SYSTEM_COUNT "$SYSTEM_VM"
printf "  \$%.2f/hour × %d hours × %d nodes = \$%.2f/month\n" $SYSTEM_PRICE_PER_HOUR $SYSTEM_HOURS_PER_MONTH $SYSTEM_COUNT $SYSTEM_COST
echo ""
printf "Production Pool (%dx %s):\n" $PROD_COUNT "$PROD_VM"
printf "  \$%.2f/hour × %d hours × %d nodes = \$%.2f/month\n" $PROD_PRICE_PER_HOUR $PROD_HOURS_PER_MONTH $PROD_COUNT $PROD_COST
echo ""
printf "Compute Pool (%dx %s):\n" $COMPUTE_COUNT "$COMPUTE_VM"
printf "  \$%.2f/hour × %d hours × %d nodes = \$%.2f/month\n" $COMPUTE_PRICE_PER_HOUR $COMPUTE_HOURS_PER_MONTH $COMPUTE_COUNT $COMPUTE_COST
echo ""
printf "Memory Pool (%dx %s):\n" $MEMORY_COUNT "$MEMORY_VM"
printf "  \$%.2f/hour × %d hours × %d nodes = \$%.2f/month\n" $MEMORY_PRICE_PER_HOUR $MEMORY_HOURS_PER_MONTH $MEMORY_COUNT $MEMORY_COST
echo ""
echo "----------------------------------------"
printf "Total Compute: \$%.2f/month\n" $COMPUTE_TOTAL
echo ""
echo "ADDITIONAL SERVICES:"
echo "----------------------------------------"
printf "Load Balancer:          \$%.2f/month\n" $LB_PRICE_PER_MONTH
printf "Azure Monitor/Logs:     \$%.2f/month\n" $MONITOR_PRICE_PER_MONTH
printf "Container Registry:     \$%.2f/month\n" $ACR_PRICE_PER_MONTH
printf "Storage:                \$%.2f/month\n" $STORAGE_PRICE_PER_MONTH
printf "Bandwidth:              \$%.2f/month\n" $BANDWIDTH_PRICE_PER_MONTH
echo "----------------------------------------"
printf "Total Services: \$%.2f/month\n" $SERVICES_TOTAL
echo ""
echo "=================================================="
printf "TOTAL MONTHLY COST:  \$%.2f\n" $TOTAL_MONTHLY
printf "TOTAL YEARLY COST:   \$%.2f\n" $TOTAL_YEARLY
echo "=================================================="
echo ""
echo "COST OPTIMIZATION TIPS:"
echo "1. Use Azure Reserved Instances (save up to 72%)"
echo "2. Enable autoscaling to scale down during low usage"
echo "3. Use spot instances for non-critical workloads"
echo "4. Right-size VMs based on actual usage metrics"
echo "5. Set up budgets and alerts in Azure Cost Management"
echo ""
echo "COST BREAKDOWN BY TEAM (approximate):"
echo "----------------------------------------"
TEAM_ALPHA_PODS=3
TEAM_BETA_PODS=3
TEAM_GAMMA_PODS=2
TEAM_DELTA_PODS=2
TOTAL_PODS=$(echo "$TEAM_ALPHA_PODS + $TEAM_BETA_PODS + $TEAM_GAMMA_PODS + $TEAM_DELTA_PODS" | bc)

# Distribute compute costs based on pod count
TEAM_ALPHA_COST=$(echo "$COMPUTE_TOTAL * $TEAM_ALPHA_PODS / $TOTAL_PODS" | bc)
TEAM_BETA_COST=$(echo "$COMPUTE_TOTAL * $TEAM_BETA_PODS / $TOTAL_PODS" | bc)
TEAM_GAMMA_COST=$(echo "$COMPUTE_TOTAL * $TEAM_GAMMA_PODS / $TOTAL_PODS" | bc)
TEAM_DELTA_COST=$(echo "$COMPUTE_TOTAL * $TEAM_DELTA_PODS / $TOTAL_PODS" | bc)

printf "Team Alpha (%d pods):  \$%.2f/month\n" $TEAM_ALPHA_PODS $TEAM_ALPHA_COST
printf "Team Beta (%d pods):   \$%.2f/month\n" $TEAM_BETA_PODS $TEAM_BETA_COST
printf "Team Gamma (%d pods):  \$%.2f/month\n" $TEAM_GAMMA_PODS $TEAM_GAMMA_COST
printf "Team Delta (%d pods):  \$%.2f/month\n" $TEAM_DELTA_PODS $TEAM_DELTA_COST
echo ""
echo "Note: Prices are approximate and may vary by region."
echo "Use Azure Pricing Calculator for exact estimates:"
echo "https://azure.microsoft.com/pricing/calculator/"
