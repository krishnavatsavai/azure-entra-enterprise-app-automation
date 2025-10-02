# Terraform configuration for Azure Entra Enterprise Applications
# This approach uses Terraform's azuread provider for consistent, declarative management

terraform {
  required_version = ">= 1.0"
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# Configure the Azure AD Provider
provider "azuread" {
  # Authentication via Azure CLI, Managed Identity, or Service Principal
}

provider "azurerm" {
  features {}
}

# Local variables for configuration parsing
locals {
  # Parse YAML configuration file
  config = yamldecode(file(var.config_file_path))
  
  # Extract configuration values
  gallery_app_id      = local.config.application.galleryAppId
  display_name        = local.config.application.displayName
  assignment_required = try(local.config.assignment.assignmentRequired, false)
  visible_to_users    = try(local.config.assignment.visibleToUsers, true)
  
  # User assignments
  user_assignments = try(local.config.assignment.users, [])
  
  # Group assignments
  group_assignments = try(local.config.assignment.groups, [])
  
  # SSO configuration
  sso_config = try(local.config.sso, {})
  
  # Provisioning configuration
  provisioning_config = try(local.config.provisioning, {})
  
  # Tags for resource management
  common_tags = concat(
    try(local.config.metadata.tags, []),
    [
      "Environment:${var.environment}",
      "ManagedBy:Terraform",
      "ConfigVersion:${local.config.metadata.version}",
      "CreatedBy:${var.created_by}"
    ]
  )
}

# Variable definitions
variable "config_file_path" {
  description = "Path to the YAML configuration file"
  type        = string
}

variable "environment" {
  description = "Target environment"
  type        = string
  default     = "development"
  
  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be one of: development, staging, production."
  }
}

variable "created_by" {
  description = "User or system that created this resource"
  type        = string
  default     = "terraform"
}

variable "enable_state_backup" {
  description = "Enable Terraform state backup to Azure Storage"
  type        = bool
  default     = true
}

# Data source for gallery application template
data "azuread_application_template" "main" {
  template_id = local.gallery_app_id
}

# Create enterprise application from gallery
resource "azuread_application" "main" {
  display_name     = local.display_name
  template_id      = local.gallery_app_id
  
  # Optional configurations from YAML
  web {
    homepage_url = try(local.config.application.homepage, null)
    
    # SAML redirect URIs
    dynamic "redirect_uris" {
      for_each = local.sso_config.ssoMode == "saml" ? [local.sso_config.saml.replyUrl] : []
      content {
        redirect_uris = [redirect_uris.value]
      }
    }
  }
  
  # Application notes
  notes = try(local.config.application.notes, null)
  
  # SAML SSO configuration
  dynamic "single_sign_on" {
    for_each = local.sso_config.ssoMode == "saml" ? [1] : []
    content {
      redirect_uris = [local.sso_config.saml.replyUrl]
    }
  }
  
  # App roles (if defined in configuration)
  dynamic "app_role" {
    for_each = try(local.config.appRoles, [])
    content {
      allowed_member_types = app_role.value.allowedMemberTypes
      description         = app_role.value.description
      display_name        = app_role.value.displayName
      enabled            = try(app_role.value.enabled, true)
      id                 = app_role.value.id
      value              = app_role.value.value
    }
  }
  
  # Tags for organization
  tags = local.common_tags
}

# Create service principal for the application
resource "azuread_service_principal" "main" {
  application_id               = azuread_application.main.application_id
  app_role_assignment_required = local.assignment_required
  visible                      = local.visible_to_users
  
  # Notification email addresses
  notification_email_addresses = try(local.config.notifications.emailAddresses, [])
  
  # Login URL (for SAML applications)
  login_url = local.sso_config.ssoMode == "saml" ? local.sso_config.saml.signOnUrl : null
  
  tags = local.common_tags
  
  # Feature settings
  feature_tags {
    custom_single_sign_on = local.sso_config.ssoMode == "saml"
    enterprise           = true
    gallery             = true
  }
}

# Data sources for users
data "azuread_user" "users" {
  for_each            = {
    for user in local.user_assignments : user.userPrincipalName => user
  }
  user_principal_name = each.key
}

# Data sources for groups
data "azuread_group" "groups" {
  for_each     = {
    for group in local.group_assignments : group.displayName => group
  }
  display_name = each.key
}

# User assignments
resource "azuread_app_role_assignment" "user_assignments" {
  for_each = {
    for user in local.user_assignments : user.userPrincipalName => user
  }
  
  app_role_id         = "00000000-0000-0000-0000-000000000000" # Default role
  principal_object_id = data.azuread_user.users[each.key].object_id
  resource_object_id  = azuread_service_principal.main.object_id
}

# Group assignments
resource "azuread_app_role_assignment" "group_assignments" {
  for_each = {
    for group in local.group_assignments : group.displayName => group
  }
  
  app_role_id         = "00000000-0000-0000-0000-000000000000" # Default role
  principal_object_id = data.azuread_group.groups[each.key].object_id
  resource_object_id  = azuread_service_principal.main.object_id
}

# SAML SSO configuration (if specified)
resource "azuread_service_principal_token_signing_certificate" "main" {
  count                = local.sso_config.ssoMode == "saml" ? 1 : 0
  service_principal_id = azuread_service_principal.main.object_id
  display_name         = "${local.display_name} SAML Certificate"
  end_date             = timeadd(timestamp(), "8760h") # 1 year
}

# SAML Claim mapping (if SAML SSO is enabled)
resource "azuread_claims_mapping_policy" "main" {
  count        = local.sso_config.ssoMode == "saml" ? 1 : 0
  display_name = "${local.display_name} Claims Mapping"
  
  definition = [jsonencode({
    ClaimsMappingPolicy = {
      Version = 1
      IncludeBasicClaimSet = "true"
      ClaimsSchema = [
        for attr in try(local.sso_config.saml.attributes, []) : {
          Source = attr.source
          ID = attr.name
          SamlClaimType = attr.name
          JwtClaimType = attr.name
        }
      ]
    }
  })]
}

# Apply claims mapping policy to service principal
resource "azuread_service_principal_claims_mapping_policy_assignment" "main" {
  count                   = local.sso_config.ssoMode == "saml" ? 1 : 0
  claims_mapping_policy_id = azuread_claims_mapping_policy.main[0].id
  service_principal_id     = azuread_service_principal.main.object_id
}

# Create Key Vault for storing provisioning credentials (if provisioning is enabled)
resource "azurerm_key_vault" "provisioning" {
  count               = local.provisioning_config.enabled == true ? 1 : 0
  name                = "${substr(replace(lower(local.display_name), " ", ""), 0, 20)}-kv-${random_id.kv_suffix[0].hex}"
  location            = var.key_vault_location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name           = "standard"
  
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    
    secret_permissions = [
      "Get", "List", "Set", "Delete", "Recover", "Backup", "Restore"
    ]
  }
  
  tags = {
    for k, v in local.common_tags : k => v if k != "Environment"
  }
}

# Random ID for Key Vault naming
resource "random_id" "kv_suffix" {
  count       = local.provisioning_config.enabled == true ? 1 : 0
  byte_length = 4
}

# Azure client configuration
data "azurerm_client_config" "current" {}

# Additional variables for Key Vault
variable "key_vault_location" {
  description = "Location for Key Vault (required if provisioning is enabled)"
  type        = string
  default     = "East US"
}

variable "resource_group_name" {
  description = "Resource group name for Key Vault (required if provisioning is enabled)"
  type        = string
  default     = "rg-enterprise-apps"
}

# Output values
output "application_id" {
  description = "The application (client) ID"
  value       = azuread_application.main.application_id
}

output "service_principal_id" {
  description = "The service principal object ID"
  value       = azuread_service_principal.main.object_id
}

output "display_name" {
  description = "The application display name"
  value       = azuread_application.main.display_name
}

output "application_object_id" {
  description = "The application object ID"
  value       = azuread_application.main.object_id
}

output "service_principal_object_id" {
  description = "The service principal object ID" 
  value       = azuread_service_principal.main.object_id
}

output "homepage_url" {
  description = "The application homepage URL"
  value       = try(azuread_application.main.web[0].homepage_url, null)
}

output "user_assignments" {
  description = "User assignment details"
  value = {
    for k, v in azuread_app_role_assignment.user_assignments : k => {
      user_principal_name = k
      object_id          = v.principal_object_id
      app_role_id        = v.app_role_id
    }
  }
}

output "group_assignments" {
  description = "Group assignment details"
  value = {
    for k, v in azuread_app_role_assignment.group_assignments : k => {
      group_display_name = k
      object_id         = v.principal_object_id
      app_role_id       = v.app_role_id
    }
  }
}

output "saml_certificate" {
  description = "SAML signing certificate details (if SAML SSO is enabled)"
  value = local.sso_config.ssoMode == "saml" ? {
    certificate_id = azuread_service_principal_token_signing_certificate.main[0].id
    thumbprint    = azuread_service_principal_token_signing_certificate.main[0].thumbprint
    end_date      = azuread_service_principal_token_signing_certificate.main[0].end_date
  } : null
}

output "key_vault_id" {
  description = "Key Vault ID for provisioning credentials (if provisioning is enabled)"
  value       = local.provisioning_config.enabled == true ? azurerm_key_vault.provisioning[0].id : null
}

output "terraform_state" {
  description = "Terraform state information"
  value = {
    configuration_file = var.config_file_path
    environment       = var.environment
    created_by        = var.created_by
    created_timestamp = timestamp()
    terraform_version = terraform.version
  }
}

# Local file output for GitHub Actions integration
resource "local_file" "output" {
  content = jsonencode({
    application_id           = azuread_application.main.application_id
    service_principal_id     = azuread_service_principal.main.object_id
    display_name            = azuread_application.main.display_name
    status                  = "Success"
    environment             = var.environment
    config_version          = local.config.metadata.version
    created_timestamp       = timestamp()
    terraform_version       = terraform.version
    user_assignments        = length(local.user_assignments)
    group_assignments       = length(local.group_assignments)
    sso_mode               = try(local.sso_config.ssoMode, "none")
    provisioning_enabled   = try(local.provisioning_config.enabled, false)
  })
  filename = "${path.module}/terraform-output.json"
}