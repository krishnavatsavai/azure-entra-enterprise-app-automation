# Azure Entra Enterprise App Automation

This repository provides a comprehensive solution for automating the creation of Azure Entra ID Gallery Enterprise Applications using GitHub Actions, with flexible YAML-based configuration templates and robust error handling.

## 🚀 Features

- **Automated Enterprise App Creation**: Create Azure Entra Gallery applications using GitHub Actions
- **Flexible Configuration**: YAML-based templates with schema validation
- **Security Best Practices**: Managed Identity authentication, secure credential storage
- **Comprehensive Validation**: Configuration validation with detailed error reporting
- **Multi-Environment Support**: Development, staging, and production environments
- **Error Handling & Retry Logic**: Robust error handling with exponential backoff
- **Notification Support**: Email and webhook notifications for creation status
- **SSO Configuration**: Support for SAML, password, and linked sign-on modes
- **User & Group Assignment**: Automated user and group assignments with role-based access

## 📁 Repository Structure

```
ent-apps-automation/
├── .github/
│   └── workflows/
│       └── create-enterprise-app.yml    # Main GitHub Actions workflow
├── scripts/
│   ├── Create-EnterpriseApp.ps1         # PowerShell automation script
│   └── Validate-Config.ps1              # Configuration validation script
├── templates/
│   └── enterprise-app-template.yaml     # Base configuration template
├── examples/
│   ├── salesforce.yaml                  # Salesforce configuration example
│   ├── servicenow.yaml                  # ServiceNow configuration example
│   └── test-validation.yaml             # Test configuration for validation
├── schemas/
│   └── enterprise-app-config.schema.json # JSON schema for validation
└── README.md                            # This file
```

## 🛠️ Prerequisites

### Azure Requirements

1. **Azure Entra ID Premium License** (P1 or P2)
2. **Azure Subscription** with appropriate permissions
3. **Application Administrator** or **Global Administrator** role in Azure Entra ID

### GitHub Requirements

1. **GitHub repository** with Actions enabled
2. **GitHub Secrets** configured for Azure authentication
3. **Environment protection rules** (optional but recommended)

### PowerShell Modules

The following PowerShell modules are required (automatically installed by the workflow):
- `Az.Accounts` (v2.0.0+)
- `Microsoft.Graph.Authentication` (v2.0.0+)
- `Microsoft.Graph.Applications` (v2.0.0+)
- `Microsoft.Graph.Identity.DirectoryManagement` (v2.0.0+)
- `powershell-yaml`

## ⚙️ Setup Instructions

### 1. Azure Service Principal Setup

Create a service principal for GitHub Actions authentication:

```bash
# Create service principal
az ad sp create-for-rbac --name "github-actions-enterprise-apps" \
  --role "Application Administrator" \
  --scopes "/subscriptions/{subscription-id}" \
  --sdk-auth

# Note: Save the output for GitHub secrets configuration
```

### 2. Azure Permissions

The service principal needs the following permissions:

**Microsoft Graph API Permissions:**
- `Application.ReadWrite.All` (Application permissions)
- `Directory.Read.All` (Application permissions)
- `User.Read.All` (Application permissions)
- `Group.Read.All` (Application permissions)

**Azure RBAC Roles:**
- `Application Administrator` (Azure Entra ID role)

### 3. GitHub Configuration

#### Repository Variables

Configure the following repository variables in GitHub:

| Variable Name | Description | Example |
|---------------|-------------|---------|
| `AZURE_TENANT_ID` | Azure Entra tenant ID | `12345678-1234-1234-1234-123456789012` |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID | `87654321-4321-4321-4321-210987654321` |
| `AZURE_CLIENT_ID` | Service principal client ID | `abcdefgh-abcd-abcd-abcd-abcdefghijkl` |

#### Repository Secrets

Configure the following repository secrets in GitHub:

| Secret Name | Description |
|-------------|-------------|
| `AZURE_CLIENT_SECRET` | Service principal client secret |

#### Environment Configuration (Optional)

Create environments for better security:

1. Go to **Settings** > **Environments**
2. Create environments: `development`, `staging`, `production`
3. Configure protection rules and required reviewers
4. Add environment-specific variables if needed

## 📝 Configuration Guide

### Creating a Configuration File

1. Copy the template from `templates/enterprise-app-template.yaml`
2. Modify the configuration for your specific application
3. Place the file in your desired location (e.g., `configs/my-app.yaml`)

### Configuration Schema

The configuration file follows this structure:

```yaml
metadata:
  name: "unique-app-name"           # Required: Unique identifier
  description: "App description"    # Required: Human-readable description
  version: "1.0.0"                 # Required: Semantic version
  tags: ["tag1", "tag2"]           # Optional: Organization tags

application:
  galleryAppId: "guid"             # Required: Gallery app template ID
  displayName: "App Display Name"  # Required: Display name (max 120 chars)
  homepage: "https://app.com"      # Optional: Homepage URL
  logoUrl: "https://app.com/logo"  # Optional: Logo URL
  notes: "Additional notes"        # Optional: Additional information

assignment:
  assignmentRequired: true         # Optional: Require user assignment
  visibleToUsers: true            # Optional: Show in My Apps portal
  users:                          # Optional: User assignments
    - userPrincipalName: "user@domain.com"
      role: "User"
  groups:                         # Optional: Group assignments
    - displayName: "Group Name"
      role: "User"

sso:
  ssoMode: "saml"                 # Optional: SSO mode (saml/password/linkedSignOn/disabled)
  saml:                           # SAML configuration (when ssoMode is saml)
    identifier: "entity-id"
    replyUrl: "acs-url"
    signOnUrl: "sso-url"
    nameIdFormat: "email-format"
    attributes:
      - name: "claim-name"
        source: "user.attribute"

provisioning:
  enabled: false                  # Optional: Enable user provisioning
  mode: "manual"                  # Optional: Provisioning mode
  credentials:                    # Credentials stored in Key Vault
    keyVaultName: "vault-name"
    secretNames:
      username: "secret-name"
      password: "secret-name"

notifications:
  emailAddresses:                 # Optional: Notification emails
    - "admin@domain.com"
  webhookUrl: "webhook-url"       # Optional: Webhook for notifications
```

### Finding Gallery Application IDs

To find the correct Gallery Application ID:

1. Go to **Azure Portal** > **Entra ID** > **Enterprise Applications**
2. Click **New Application** > **Browse Azure AD Gallery**
3. Search for your application (e.g., "Salesforce")
4. Click on the application and note the URL
5. The GUID in the URL is your `galleryAppId`

Alternative method using PowerShell:

```powershell
# Connect to Microsoft Graph
Connect-MgGraph -Scopes "Application.Read.All"

# Search for applications
Get-MgApplicationTemplate -Filter "displayName eq 'Salesforce'"
```

## 🚀 Usage

### Manual Workflow Trigger

1. Go to **Actions** tab in your GitHub repository
2. Select **Create Azure Entra Enterprise Application** workflow
3. Click **Run workflow**
4. Fill in the parameters:
   - **Config File**: Path to your configuration file
   - **Environment**: Target environment (development/staging/production)
   - **Validate Only**: Check to validate without creating
   - **What If**: Check to preview changes

### Automated Workflow Trigger

You can also trigger the workflow programmatically:

```bash
# Using GitHub CLI
gh workflow run create-enterprise-app.yml \
  -f config_file="examples/salesforce.yaml" \
  -f environment="development" \
  -f validate_only=false \
  -f whatif=false

# Using REST API
curl -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/OWNER/REPO/actions/workflows/create-enterprise-app.yml/dispatches \
  -d '{"ref":"main","inputs":{"config_file":"examples/salesforce.yaml","environment":"development"}}'
```

### Workflow as a Reusable Component

You can call this workflow from other workflows:

```yaml
name: Deploy Application Stack
on:
  workflow_dispatch:

jobs:
  create-enterprise-app:
    uses: ./.github/workflows/create-enterprise-app.yml
    with:
      config_file: "configs/my-app.yaml"
      environment: "production"
      validate_only: false
      whatif: false
    secrets: inherit
```

## 🧪 Testing and Validation

### Local Validation

Before running the workflow, validate your configuration locally:

```powershell
# Validate a single configuration file
.\scripts\Validate-Config.ps1 -ConfigPath ".\examples\salesforce.yaml"

# Validate all configuration files
.\scripts\Validate-Config.ps1 -ConfigPath ".\examples\*.yaml"

# Strict validation with additional checks
.\scripts\Validate-Config.ps1 -ConfigPath ".\examples\salesforce.yaml" -Strict
```

### Test in Development Environment

1. Create a test configuration in `examples/test-validation.yaml`
2. Run the workflow with `whatif=true` to preview changes
3. Run the workflow with `validate_only=true` to test validation
4. Run the workflow normally in development environment

### Automated Testing

The workflow includes several validation steps:

1. **Input Validation**: Checks file existence and basic structure
2. **YAML Syntax Validation**: Ensures valid YAML format
3. **Schema Validation**: Validates against JSON schema
4. **Business Rule Validation**: Custom validation logic
5. **Pre-flight Checks**: Azure connectivity and permissions

## 🔍 Monitoring and Troubleshooting

### Workflow Monitoring

Monitor workflow execution through:

1. **GitHub Actions Tab**: View real-time execution logs
2. **Workflow Summary**: Review success/failure status and outputs
3. **Job Artifacts**: Download logs and outputs for analysis

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Authentication Failed | Invalid service principal credentials | Verify Azure secrets in GitHub |
| Permission Denied | Insufficient Azure permissions | Check service principal roles |
| Gallery App Not Found | Invalid `galleryAppId` | Verify the GUID in Azure portal |
| User Not Found | Invalid `userPrincipalName` | Check user exists in Azure Entra |
| Group Not Found | Invalid group `displayName` | Check group exists in Azure Entra |
| YAML Validation Failed | Invalid YAML syntax | Use YAML validator or IDE extension |

### Debugging

Enable verbose logging by setting the workflow input `whatif=true` or by adding debug steps:

```yaml
- name: Debug Configuration
  run: |
    echo "Configuration file contents:"
    cat ${{ inputs.config_file }}
    echo "Environment variables:"
    env | grep AZURE_
```

### Error Notifications

The workflow automatically creates GitHub issues for production failures and sends notifications if configured in the YAML file.

## 🔐 Security Considerations

### Authentication

- **Managed Identity**: Preferred for Azure-hosted runners
- **Service Principal**: Used for GitHub-hosted runners
- **Credential Rotation**: Regularly rotate service principal secrets
- **Least Privilege**: Grant minimum required permissions

### Secret Management

- Store sensitive data in **Azure Key Vault**
- Use **GitHub Secrets** for authentication credentials
- Never commit secrets to repository
- Use **environment-specific** secrets when needed

### Access Control

- Enable **assignment required** for production applications
- Use **Azure Entra groups** for scalable access management
- Implement **approval workflows** for production deployments
- Regular **access reviews** and auditing

### Network Security

- Restrict service principal access to specific IP ranges
- Use **conditional access policies** for enhanced security
- Monitor authentication logs for suspicious activity

## 📊 Best Practices

### Configuration Management

1. **Version Control**: Store configurations in Git with proper versioning
2. **Environment Separation**: Use different configs for dev/staging/prod
3. **Documentation**: Include comprehensive notes in configurations
4. **Validation**: Always validate configurations before deployment

### Workflow Management

1. **Environment Protection**: Use GitHub environments for production
2. **Approval Gates**: Require manual approval for critical deployments
3. **Rollback Plans**: Have rollback procedures for failed deployments
4. **Monitoring**: Set up alerts for workflow failures

### Security

1. **Regular Updates**: Keep PowerShell modules and actions updated
2. **Permission Reviews**: Regularly review and audit permissions
3. **Secret Rotation**: Implement automated secret rotation
4. **Compliance**: Ensure configurations meet compliance requirements

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes and add tests
4. Commit your changes (`git commit -m 'Add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

### Development Guidelines

- Follow PowerShell best practices and style guidelines
- Add comprehensive error handling and logging
- Include unit tests for new functionality
- Update documentation for any changes
- Test in multiple environments before submitting

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

For support and questions:

1. **GitHub Issues**: Create an issue for bugs or feature requests
2. **Discussions**: Use GitHub Discussions for questions and ideas
3. **Documentation**: Check this README and inline code documentation
4. **Community**: Join the Azure community forums

## 🔄 Changelog

### Version 1.0.0 (Initial Release)
- ✅ Core automation framework
- ✅ YAML configuration templates
- ✅ GitHub Actions workflow
- ✅ PowerShell automation scripts
- ✅ Configuration validation
- ✅ Error handling and retry logic
- ✅ Multi-environment support
- ✅ Comprehensive documentation

---

**Made with ❤️ for the Azure community**