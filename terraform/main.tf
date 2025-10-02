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
  }
}

# Configure the Azure AD Provider
provider "azuread" {
  # Authentication via Azure CLI, Managed Identity, or Service Principal
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
  homepage_url = try(local.config.application.homepage, null)
  notes        = try(local.config.application.notes, null)
  
  # Tags for organization
  tags = concat(
    try(local.config.metadata.tags, []),
    [
      "Environment:${var.environment}",
      "ManagedBy:Terraform",
      "ConfigVersion:${local.config.metadata.version}"
    ]
  )
}

# Create service principal for the application
resource "azuread_service_principal" "main" {
  application_id               = azuread_application.main.application_id
  app_role_assignment_required = local.assignment_required
  visible                      = local.visible_to_users
  
  # Notification email addresses
  notification_email_addresses = try(local.config.notifications.emailAddresses, [])
  
  tags = azuread_application.main.tags
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
  count                = try(local.config.sso.ssoMode, "") == "saml" ? 1 : 0
  service_principal_id = azuread_service_principal.main.object_id
  display_name         = "${local.display_name} SAML Certificate"
  end_date             = timeadd(timestamp(), "8760h") # 1 year
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
  value       = azuread_application.main.homepage_url
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
  })
  filename = "${path.module}/terraform-output.json"
}