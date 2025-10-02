# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-10-02

### Added
- ✨ **Core automation framework** for Azure Entra Enterprise App creation
- 📝 **YAML configuration templates** with comprehensive schema validation
- 🚀 **GitHub Actions workflow** with multi-environment support
- 🔧 **PowerShell automation scripts** with robust error handling and retry logic
- ✅ **Configuration validation** with detailed error reporting
- 🔐 **Security best practices** including Managed Identity authentication
- 📧 **Notification support** for email and webhook notifications
- 🎯 **SSO configuration** support for SAML, password, and linked sign-on modes
- 👥 **User and group assignment** automation with role-based access
- 🏗️ **Multi-environment support** (development, staging, production)
- 📊 **Comprehensive logging** and monitoring capabilities
- 🧪 **Example configurations** for Salesforce, ServiceNow, and test scenarios
- 📚 **Detailed documentation** with setup instructions and best practices
- 🤝 **Contributing guidelines** and development standards

### Features
- Automated enterprise application creation from Azure Gallery
- Flexible YAML-based configuration system
- JSON schema validation for configuration files
- GitHub Actions workflow with manual and programmatic triggers
- PowerShell scripts with comprehensive error handling
- Support for multiple SSO modes and SAML configuration
- Automatic user and group assignments
- Integration with Azure Key Vault for secure credential storage
- Notification system for deployment status
- Validation-only and WhatIf modes for testing
- Environment-specific deployment support
- Automatic issue creation for production failures

### Security
- Managed Identity authentication for Azure-hosted scenarios
- Service Principal authentication for CI/CD pipelines
- Secure credential storage in Azure Key Vault
- Least privilege access principles
- Comprehensive audit logging
- Support for conditional access policies

### Documentation
- Complete README with setup and usage instructions
- Configuration schema documentation
- Troubleshooting guide with common issues
- Security considerations and best practices
- Contributing guidelines for developers
- Example configurations for popular applications

---

## [Unreleased]

### Planned Features
- Support for custom SAML certificate management
- Integration with Azure Monitor for enhanced logging
- Bulk application creation from CSV files
- Template marketplace for common applications
- PowerShell module packaging
- Azure Resource Manager (ARM) template support
- Terraform provider integration
- Advanced role mapping capabilities
- Application lifecycle management
- Automated compliance reporting

---

## Version History

- **v1.0.0** - Initial release with core functionality
- **v0.1.0** - Internal development version

---

## Migration Notes

This is the initial release, so no migration is required. Future versions will include migration guides for breaking changes.

## Support

For questions about releases or version compatibility:
- Check the [README](README.md) for current version requirements
- Review [GitHub Issues](https://github.com/your-org/ent-apps-automation/issues) for known issues
- Create a new issue for version-specific problems