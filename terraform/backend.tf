# Backend configuration for Terraform state management
# This file configures remote state storage in Azure Storage Account

terraform {
  backend "azurerm" {
    # These values will be provided via backend-config during terraform init
    # resource_group_name  = "rg-terraform-state-{environment}"
    # storage_account_name = "sttfstate{environment}{subscription_prefix}"
    # container_name       = "tfstate"
    # key                  = "enterprise-apps/{environment}/terraform.tfstate"
    
    # Optional: Use a specific subscription for state storage
    # subscription_id = "your-subscription-id"
    
    # Use Azure AD authentication
    use_azuread_auth = true
  }
}