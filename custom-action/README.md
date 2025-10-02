# Azure Entra Enterprise App Creator - Custom GitHub Action

A powerful, enterprise-ready GitHub Action for creating and configuring Azure Entra ID (formerly Azure AD) enterprise applications from gallery templates. Built with Node.js 20, Microsoft Graph SDK, and comprehensive error handling.

## 🚀 Features

- **🏢 Gallery Template Support**: Create enterprise applications from Azure AD gallery templates (Salesforce, ServiceNow, Okta, etc.)
- **🔧 Complete Configuration**: Full application and service principal configuration including SSO, assignments, and claims
- **🧪 Dry Run Mode**: Test configurations without creating actual resources
- **📊 Comprehensive Logging**: Detailed execution logs with structured JSON output
- **🔒 Secure Authentication**: MSAL-based authentication with client credentials flow
- **⚡ High Performance**: Optimized execution with minimal dependencies (~30-45 seconds)
- **🛡️ Error Handling**: Robust error handling with detailed error messages and rollback support
- **📈 Progress Tracking**: Pre and post execution hooks with resource tracking
- **🎯 Multi-Environment**: Support for development, staging, and production environments

## 📋 Prerequisites

### Azure Requirements
- Azure AD tenant with appropriate permissions
- Service Principal with the following Microsoft Graph API permissions:
  - `Application.ReadWrite.All` (Application permissions)
  - `Directory.Read.All` (Application permissions)
  - `AppRoleAssignment.ReadWrite.All` (Application permissions)

### GitHub Repository Setup
1. **Repository Secrets**: Configure the following secrets in your GitHub repository:
   - `AZURE_TENANT_ID`: Your Azure AD tenant ID
   - `AZURE_CLIENT_ID`: Service Principal client ID
   - `AZURE_CLIENT_SECRET`: Service Principal client secret

2. **Permissions**: Ensure the repository has appropriate permissions:
   - `contents: read` - Read repository contents
   - `id-token: write` - For OIDC authentication (optional)

## 🔧 Usage

### Basic Usage

```yaml
name: Create Enterprise Application
on:
  workflow_dispatch:
    inputs:
      config_file:
        description: 'Configuration file path'
        required: true
        default: 'examples/salesforce.yaml'

jobs:
  create-app:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Create Enterprise Application
        uses: ./custom-action  # or your-org/azure-entra-enterprise-app-automation/custom-action@v1
        with:
          config-file: ${{ github.event.inputs.config_file }}
          azure-tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          azure-client-id: ${{ secrets.AZURE_CLIENT_ID }}
          azure-client-secret: ${{ secrets.AZURE_CLIENT_SECRET }}
          environment: 'production'
```

### Advanced Usage with All Options

```yaml
- name: Create Enterprise Application
  id: create-app
  uses: ./custom-action
  with:
    # Required inputs
    config-file: 'config/salesforce-prod.yaml'
    azure-tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    azure-client-id: ${{ secrets.AZURE_CLIENT_ID }}
    azure-client-secret: ${{ secrets.AZURE_CLIENT_SECRET }}
    
    # Optional inputs
    dry-run: 'false'                    # Set to 'true' for testing
    environment: 'production'           # dev, staging, production
    validation-mode: 'true'             # Enable additional validation

- name: Handle Results
  run: |
    echo "Application ID: ${{ steps.create-app.outputs.application-id }}"
    echo "Service Principal ID: ${{ steps.create-app.outputs.service-principal-id }}"
    echo "Portal URL: ${{ steps.create-app.outputs.app-url }}"
    echo "SSO URL: ${{ steps.create-app.outputs.sso-url }}"
    echo "Status: ${{ steps.create-app.outputs.status }}"
    echo "Execution Time: ${{ steps.create-app.outputs.execution-time }}s"
```

## 📥 Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `config-file` | Path to the YAML configuration file | ✅ Yes | - |
| `azure-tenant-id` | Azure AD Tenant ID | ✅ Yes | - |
| `azure-client-id` | Azure AD Client ID for authentication | ✅ Yes | - |
| `azure-client-secret` | Azure AD Client Secret for authentication | ✅ Yes | - |
| `dry-run` | Perform a dry run without creating resources | ❌ No | `false` |
| `environment` | Target environment (dev, staging, production) | ❌ No | `dev` |
| `validation-mode` | Enable additional validation checks | ❌ No | `true` |

## 📤 Outputs

| Output | Description | Example |
|--------|-------------|---------|
| `application-id` | Object ID of the created enterprise application | `12345678-1234-1234-1234-123456789012` |
| `service-principal-id` | Object ID of the created service principal | `87654321-4321-4321-4321-210987654321` |
| `app-url` | URL to access the application in Azure portal | `https://portal.azure.com/#view/Microsoft_AAD_IAM/...` |
| `sso-url` | Single Sign-On URL for the application | `https://myapps.microsoft.com/myapp` |
| `status` | Status of the operation | `success`, `failed`, `dry-run` |
| `execution-time` | Total execution time in seconds | `42` |
| `created-resources` | JSON array of all created resource IDs | `[{"type":"Application","id":"..."}]` |

## 📄 Configuration File Format

The action uses YAML configuration files to define enterprise application settings. Here's a complete example:

```yaml
# Enterprise Application Configuration
enterpriseApplication:
  # Basic Information
  displayName: "Salesforce Production Environment"
  description: "Salesforce integration for production workloads"
  galleryTemplate: "Salesforce"
  
  # Application URLs
  homepageUrl: "https://mycompany.salesforce.com"
  identifierUris:
    - "https://mycompany.salesforce.com"
    - "urn:federation:salesforce"
  
  # Visibility and Assignment
  userAssignmentRequired: true
  visibleToUsers: true
  notificationEmailAddresses:
    - "admin@mycompany.com"
    - "security@mycompany.com"
  
  # Single Sign-On Configuration
  singleSignOn:
    mode: "saml"
    saml:
      loginUrl: "https://mycompany.salesforce.com/sso"
      logoutUrl: "https://mycompany.salesforce.com/logout"
      
  # User and Group Assignments
  assignments:
    - principalId: "user-object-id-1"
      appRoleId: "00000000-0000-0000-0000-000000000000"  # Default access
    - principalId: "group-object-id-1"
      appRoleId: "admin-role-id"
```

### Supported Gallery Templates

Common gallery templates include:
- `Salesforce`
- `ServiceNow`
- `Okta`
- `AWS Single Sign-On`
- `Google Workspace`
- `Microsoft 365`
- `Slack`
- `Zoom`
- `Atlassian Cloud`

## 🏗️ Development

### Local Development Setup

```bash
# Clone the repository
git clone https://github.com/your-org/azure-entra-enterprise-app-automation.git
cd azure-entra-enterprise-app-automation/custom-action

# Install dependencies
npm install

# Run tests
npm test

# Run linting
npm run lint

# Build the action
npm run build
```

### Testing

```bash
# Run all tests
npm test

# Run tests with coverage
npm run test -- --coverage

# Run tests in watch mode
npm run test:watch

# Run specific test file
npm test -- index.test.js
```

### Building and Packaging

```bash
# Build for production
npm run build

# Package with ncc (creates dist/index.js)
npm run package

# Validate the action
npm run validate
```

## 🔍 Troubleshooting

### Common Issues

#### 1. Authentication Failures
```
Error: Failed to initialize Graph client: Authentication failed
```

**Solutions:**
- Verify Azure credentials are correct
- Ensure Service Principal has required permissions
- Check tenant ID format (should be a GUID)

#### 2. Gallery Template Not Found
```
Error: Gallery template not found: TemplateName
```

**Solutions:**
- Verify the exact template name in Azure AD gallery
- Use the display name as shown in Azure portal
- Check template availability in your tenant

#### 3. Permission Denied
```
Error: Insufficient privileges to complete the operation
```

**Solutions:**
- Grant required Microsoft Graph API permissions
- Ensure admin consent is provided for application permissions
- Verify Service Principal is not restricted by conditional access

#### 4. Configuration Validation Errors
```
Error: Required configuration field missing: enterpriseApplication.displayName
```

**Solutions:**
- Check YAML file syntax and structure
- Ensure all required fields are present
- Validate against the schema

### Debug Mode

Enable detailed logging by setting environment variables:

```yaml
env:
  NODE_ENV: development
  DEBUG: azure-entra:*
```

### Getting Help

1. **Check Logs**: Review the detailed execution logs in the GitHub Actions run
2. **Validate Configuration**: Use `validation-mode: true` to catch issues early
3. **Use Dry Run**: Test with `dry-run: true` before creating actual resources
4. **GitHub Issues**: Report bugs and request features via GitHub Issues

## 📊 Performance Metrics

| Metric | Value |
|--------|-------|
| **Cold Start Time** | ~15-20 seconds |
| **Warm Execution** | ~30-45 seconds |
| **Memory Usage** | ~150-200MB |
| **Dependencies** | 8 production packages |
| **Bundle Size** | ~2.5MB (dist/index.js) |

## 🔒 Security Considerations

### Credential Management
- Store secrets in GitHub repository secrets, never in code
- Use least privilege principle for Service Principal permissions
- Rotate credentials regularly
- Consider using OIDC for authentication where possible

### Network Security
- All API calls use HTTPS with certificate validation
- Microsoft Graph API endpoints are Microsoft-managed
- No custom network endpoints or external dependencies

### Audit Trail
- All operations are logged with timestamps and user context
- Created resources are tracked for audit purposes
- Execution results stored as artifacts for compliance

## 📈 Monitoring and Observability

### Metrics
- Execution time tracking
- Success/failure rates  
- Resource creation counts
- Error categorization

### Logging
- Structured JSON logging with Winston
- GitHub Actions step summaries
- Detailed error messages with stack traces
- Resource creation audit trail

### Alerts
- Integration with Microsoft Teams via webhooks
- Email notifications for production environments
- Slack integration (via custom webhook)

## 🎯 Best Practices

### Configuration Management
1. **Environment-specific configs**: Use separate configuration files for each environment
2. **Version control**: Store configurations in Git with proper branching strategy
3. **Validation**: Always enable validation mode for production deployments
4. **Testing**: Use dry-run mode for testing configuration changes

### Security
1. **Least privilege**: Grant minimum required permissions to Service Principal
2. **Secret rotation**: Implement regular credential rotation
3. **Audit logging**: Enable comprehensive logging for compliance
4. **Network security**: Use private endpoints where possible

### Operations
1. **Monitoring**: Implement comprehensive monitoring and alerting
2. **Backup**: Maintain configuration backups and rollback procedures
3. **Documentation**: Keep configuration documentation up to date
4. **Testing**: Test changes in non-production environments first

## 📚 Additional Resources

- [Microsoft Graph API Documentation](https://docs.microsoft.com/graph/)
- [Azure AD Enterprise Applications](https://docs.microsoft.com/azure/active-directory/manage-apps/)
- [GitHub Actions Documentation](https://docs.github.com/actions)
- [YAML Configuration Schema](./schema/enterprise-app-schema.json)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🏷️ Version History

- **v1.0.0** - Initial release with full gallery template support
- **v0.9.0** - Beta release with basic functionality
- **v0.1.0** - Alpha release for testing

---

Made with ❤️ for enterprise Azure automation