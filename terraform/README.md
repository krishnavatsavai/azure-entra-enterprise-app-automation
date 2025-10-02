# Terraform Scripts for Enterprise App Management

This directory contains Terraform configuration files for managing Azure Entra Enterprise Applications using Infrastructure as Code (IaC) principles.

## 🏗️ Files Overview

- **`main.tf`** - Main Terraform configuration with resources and data sources
- **`backend.tf`** - Backend configuration for remote state management
- **`terraform.tfvars.example`** - Example variables file
- **`README.md`** - This documentation file

## 🚀 Quick Start

### Prerequisites

1. **Terraform** (>= 1.0)
2. **Azure CLI** (authenticated)
3. **Permissions**: Application Administrator role in Azure Entra ID

### Basic Usage

```bash
# Clone the repository
git clone https://github.com/krishnavatsavai/azure-entra-enterprise-app-automation.git
cd azure-entra-enterprise-app-automation/terraform

# Copy and customize variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Initialize Terraform
terraform init

# Plan the deployment
terraform plan -var="config_file_path=../examples/salesforce.yaml"

# Apply the configuration
terraform apply -var="config_file_path=../examples/salesforce.yaml"
```

## 📝 Configuration

### Required Variables

```hcl
# Path to YAML configuration file
config_file_path = "../examples/salesforce.yaml"

# Target environment
environment = "development"  # development, staging, production
```

### Optional Variables

```hcl
# User who created the resources
created_by = "john.doe@company.com"

# Key Vault configuration (for provisioning)
key_vault_location = "East US"
resource_group_name = "rg-enterprise-apps-dev"

# Enable Terraform state backup
enable_state_backup = true
```

## 🔧 Advanced Configuration

### Remote State Backend

Configure Azure Storage for Terraform state:

```bash
# Create resource group for Terraform state
az group create --name rg-terraform-state-dev --location "East US"

# Create storage account
az storage account create \
  --name sttfstatedev12345678 \
  --resource-group rg-terraform-state-dev \
  --location "East US" \
  --sku Standard_LRS

# Create container
az storage container create \
  --name tfstate \
  --account-name sttfstatedev12345678
```

### Environment-Specific Configurations

Create separate `.tfvars` files for each environment:

```bash
# Development environment
echo 'environment = "development"' > dev.tfvars

# Staging environment  
echo 'environment = "staging"' > staging.tfvars

# Production environment
echo 'environment = "production"' > prod.tfvars
```

## 🎯 Terraform Commands

### Planning and Applying

```bash
# Plan with specific configuration
terraform plan \
  -var="config_file_path=../examples/salesforce.yaml" \
  -var="environment=production" \
  -out=tfplan

# Apply the plan
terraform apply tfplan

# Apply with auto-approval (use carefully)
terraform apply -auto-approve \
  -var="config_file_path=../examples/salesforce.yaml"
```

### Managing State

```bash
# Show current state
terraform show

# List resources in state
terraform state list

# Show specific resource
terraform state show azuread_application.main

# Import existing resource
terraform import azuread_application.main <application-id>
```

### Cleanup

```bash
# Plan destruction
terraform plan -destroy \
  -var="config_file_path=../examples/salesforce.yaml"

# Destroy resources
terraform destroy \
  -var="config_file_path=../examples/salesforce.yaml"
```

## 📊 Outputs

After successful deployment, Terraform provides these outputs:

```bash
# View all outputs
terraform output

# Specific outputs
terraform output application_id
terraform output service_principal_id
terraform output display_name
```

### Output Values

- **`application_id`** - The application (client) ID
- **`service_principal_id`** - The service principal object ID  
- **`display_name`** - The application display name
- **`user_assignments`** - Details of user assignments
- **`group_assignments`** - Details of group assignments
- **`saml_certificate`** - SAML certificate info (if SAML SSO enabled)
- **`key_vault_id`** - Key Vault ID (if provisioning enabled)

## 🔒 Security Best Practices

### Authentication

```bash
# Use Azure CLI authentication (recommended for local development)
az login

# For CI/CD, use service principal with environment variables:
export ARM_CLIENT_ID="your-client-id"
export ARM_CLIENT_SECRET="your-client-secret"  
export ARM_TENANT_ID="your-tenant-id"
export ARM_SUBSCRIPTION_ID="your-subscription-id"
```

### State File Security

- Store state files in encrypted Azure Storage
- Use Azure AD authentication for state access
- Enable versioning on state storage container
- Restrict access to state files using RBAC

### Sensitive Data

```hcl
# Mark sensitive outputs
output "sensitive_value" {
  value     = "secret-data"
  sensitive = true
}
```

## 🧪 Testing

### Validation

```bash
# Validate Terraform configuration
terraform validate

# Format check
terraform fmt -check -recursive

# Security scanning (using tfsec)
tfsec .
```

### Dry Run

```bash
# Plan without applying
terraform plan -var="config_file_path=../examples/test-validation.yaml"

# What-if analysis
terraform plan -detailed-exitcode
```

## 🔄 CI/CD Integration

### GitHub Actions

Use the provided workflow:

```yaml
# .github/workflows/terraform-deploy.yml
- uses: ./.github/workflows/terraform-deploy.yml
  with:
    config_file: "examples/salesforce.yaml"
    environment: "production"
    terraform_action: "apply"
    auto_approve: false
```

### Azure DevOps

```yaml
# azure-pipelines.yml
- task: TerraformTaskV3@3
  inputs:
    provider: 'azurerm'
    command: 'init'
    workingDirectory: '$(System.DefaultWorkingDirectory)/terraform'
    
- task: TerraformTaskV3@3
  inputs:
    provider: 'azurerm'
    command: 'plan'
    workingDirectory: '$(System.DefaultWorkingDirectory)/terraform'
    commandOptions: '-var="config_file_path=../examples/salesforce.yaml"'
```

## 🐛 Troubleshooting

### Common Issues

#### Authentication Errors
```bash
# Verify Azure CLI authentication
az account show

# Check Azure AD permissions
az ad app permission list --id <application-id>
```

#### State Lock Issues
```bash
# Force unlock state (use carefully)
terraform force-unlock <lock-id>
```

#### Resource Not Found
```bash
# Refresh state
terraform refresh

# Reimport resource
terraform import azuread_application.main <application-id>
```

#### Configuration Errors
```bash
# Validate YAML configuration
yq eval '.' ../examples/salesforce.yaml

# Check Terraform syntax
terraform validate
```

### Debug Mode

```bash
# Enable debug logging
export TF_LOG=DEBUG
terraform plan

# Log to file
export TF_LOG=TRACE
export TF_LOG_PATH=terraform.log
terraform apply
```

## 📈 Performance Optimization

### Parallelism

```bash
# Increase parallelism (default is 10)
terraform apply -parallelism=20
```

### State Management

```bash
# Use partial configuration for large states
terraform init -backend-config="key=enterprise-apps/app1/terraform.tfstate"
```

### Resource Targeting

```bash
# Apply only specific resources
terraform apply -target=azuread_application.main
```

## 🔗 Integration Examples

### With Azure Key Vault

```hcl
# Reference existing Key Vault
data "azurerm_key_vault" "existing" {
  name                = "existing-kv"
  resource_group_name = "existing-rg"
}

# Store application secrets
resource "azurerm_key_vault_secret" "app_secret" {
  name         = "app-secret"
  value        = azuread_application.main.application_id
  key_vault_id = data.azurerm_key_vault.existing.id
}
```

### With Azure Monitor

```hcl
# Application Insights for monitoring
resource "azurerm_application_insights" "main" {
  name                = "${local.display_name}-insights"
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type    = "web"
  
  tags = local.common_tags
}
```

This comprehensive guide covers all aspects of using Terraform for Azure Entra Enterprise App management.