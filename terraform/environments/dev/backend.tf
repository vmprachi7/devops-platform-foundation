# terraform/environments/dev/backend.tf
#
# Stores Terraform state in Azure Blob Storage.
# WHY NOT GITHUB:
#   - State is a binary file — git diffs are meaningless
#   - No locking — two pipeline runs simultaneously = corrupted state
#   - Contains sensitive data (kubeconfig, passwords in plaintext)
#   - Azure Blob gives free state locking via lease mechanism
#
# This file is safe to commit — it contains no secrets.
# The storage account key is injected via environment variable
# or GitHub Secret at runtime.

terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstateprachi7"
    container_name       = "tfstate"
    key                  = "devops-platform/dev/terraform.tfstate"
    # key = ARM_ACCESS_KEY env var or TF_STATE_STORAGE_KEY secret
    # Never hardcode the storage account key here
  }
}
