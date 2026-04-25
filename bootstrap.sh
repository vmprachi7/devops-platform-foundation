# ═══════════════════════════════════════════════════════════════
# STEP 1 — Bootstrap: create storage account for Terraform state
# Run this ONCE manually before anything else
# This is the only resource NOT managed by Terraform
# ═══════════════════════════════════════════════════════════════

# Login first
az login

# Set your subscription
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Create a dedicated resource group for Terraform state
az group create \
  --name "terraform-state-rg" \
  --location "eastus"

# Create storage account (name must be globally unique, 3-24 chars, lowercase)
az storage account create \
  --name "tfstateprachi7"  \
  --resource-group "terraform-state-rg" \
  --location "eastus" \
  --sku "Standard_LRS" \
  --kind "StorageV2" \
  --allow-blob-public-access false

# Create container inside the storage account
az storage container create \
  --name "tfstate" \
  --account-name "tfstateprachi7"

# Verify it exists
az storage container list \
  --account-name "tfstateprachi7" \
  --output table

echo "✅ Terraform state backend ready"
echo "Storage account: tfstateprachi7"
echo "Container:        tfstate"
echo "Resource group:   terraform-state-rg"


# ═══════════════════════════════════════════════════════════════
# STEP 2 — Get the storage account key for GitHub Secrets
# ═══════════════════════════════════════════════════════════════

az storage account keys list \
  --account-name "tfstateprachi7" \
  --resource-group "terraform-state-rg" \
  --query "[0].value" \
  --output tsv

# Copy this value → add as GitHub Secret: TF_STATE_STORAGE_KEY


# ═══════════════════════════════════════════════════════════════
# STEP 3 — Fix "resource already exists" issue
# Run this if you have orphaned resources from failed runs
# ═══════════════════════════════════════════════════════════════

# Option A — if resources exist and you want to IMPORT them into state
# (use this if the resources are healthy and you want to keep them)

cd terraform/environments/dev
terraform init   # with backend config (see backend.tf below)

# Import existing resource group
terraform import azurerm_resource_group.main \
  /subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/devops-platform-rg

# Import existing AKS cluster
terraform import azurerm_kubernetes_cluster.aks \
  /subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/devops-platform-rg/providers/Microsoft.ContainerService/managedClusters/devops-platform-aks

# Import existing ACR
terraform import azurerm_container_registry.acr \
  /subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/devops-platform-rg/providers/Microsoft.ContainerRegistry/registries/devopsplatformacr

# Import existing Log Analytics workspace
terraform import azurerm_log_analytics_workspace.main \
  /subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/devops-platform-rg/providers/Microsoft.OperationalInsights/workspaces/devops-platform-aks-logs

# After import — run plan to confirm zero drift
terraform plan
# Expected: "No changes. Your infrastructure matches the configuration."


# Option B — if resources are broken/partial and you want to START CLEAN
# (nuke everything and let Terraform recreate)

az group delete --name "devops-platform-rg" --yes --no-wait
echo "Waiting 2 minutes for deletion..."
sleep 120
terraform apply -auto-approve


# ═══════════════════════════════════════════════════════════════
# STEP 4 — GitHub Secrets to add
# ═══════════════════════════════════════════════════════════════

# Existing secrets (you already have these):
# ARM_CLIENT_ID
# ARM_CLIENT_SECRET
# ARM_TENANT_ID
# ARM_SUBSCRIPTION_ID
# AZURE_CREDENTIALS

# NEW secret to add:
# TF_STATE_STORAGE_KEY  → value from Step 2 above