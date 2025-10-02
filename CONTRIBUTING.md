# Contributing to Azure Entra Enterprise App Automation

Thank you for your interest in contributing to this project! This document provides guidelines and information for contributors.

## 🎯 How to Contribute

### Reporting Issues

1. **Search existing issues** to avoid duplicates
2. **Use issue templates** when available
3. **Provide detailed information**:
   - Configuration files (sanitized)
   - Error messages and logs
   - Steps to reproduce
   - Expected vs actual behavior
   - Environment details

### Suggesting Features

1. **Check existing feature requests** first
2. **Provide clear use cases** and business justification
3. **Consider implementation complexity** and maintenance impact
4. **Be open to discussion** and alternative approaches

### Code Contributions

1. **Fork the repository** and create a feature branch
2. **Follow coding standards** and best practices
3. **Add tests** for new functionality
4. **Update documentation** as needed
5. **Submit a pull request** with clear description

## 🛠️ Development Setup

### Prerequisites

- PowerShell 7.0 or later
- Git
- Visual Studio Code (recommended)
- Azure CLI
- Access to Azure Entra ID tenant for testing

### Local Development

```bash
# Clone your fork
git clone https://github.com/YOUR-USERNAME/ent-apps-automation.git
cd ent-apps-automation

# Create a feature branch
git checkout -b feature/your-feature-name

# Install required PowerShell modules
pwsh -Command "Install-Module -Name Az.Accounts, Microsoft.Graph.Authentication, Microsoft.Graph.Applications, powershell-yaml -Force"
```

### Testing Changes

1. **Validate configuration files**:
   ```powershell
   .\scripts\Validate-Config.ps1 -ConfigPath ".\examples\*.yaml" -Strict
   ```

2. **Test PowerShell scripts**:
   ```powershell
   # Validate syntax
   .\scripts\Create-EnterpriseApp.ps1 -ConfigPath ".\examples\test-validation.yaml" -Validate -Verbose
   
   # Test in WhatIf mode
   .\scripts\Create-EnterpriseApp.ps1 -ConfigPath ".\examples\test-validation.yaml" -WhatIf -Verbose
   ```

3. **Test GitHub Actions workflow**:
   - Push changes to your fork
   - Create a test configuration
   - Run the workflow with `validate_only=true`

## 📝 Coding Standards

### PowerShell Standards

1. **Follow PowerShell best practices**:
   - Use approved verbs for function names
   - Include comprehensive help documentation
   - Implement proper error handling
   - Use parameter validation attributes

2. **Code formatting**:
   - Use 4 spaces for indentation
   - Keep lines under 120 characters
   - Use consistent naming conventions
   - Add comments for complex logic

3. **Error handling**:
   - Use `$ErrorActionPreference = 'Stop'`
   - Implement try-catch blocks for operations
   - Provide meaningful error messages
   - Include retry logic for transient failures

### YAML Standards

1. **Configuration files**:
   - Use 2 spaces for indentation
   - Follow consistent naming conventions
   - Include comprehensive comments
   - Validate against JSON schema

2. **GitHub Actions workflows**:
   - Use descriptive job and step names
   - Include proper error handling
   - Add appropriate timeouts
   - Use secure authentication methods

### Documentation Standards

1. **README updates**:
   - Keep documentation current with code changes
   - Include examples for new features
   - Update version information
   - Add troubleshooting information

2. **Code comments**:
   - Explain complex business logic
   - Document security considerations
   - Include examples for functions
   - Keep comments concise and relevant

## 🧪 Testing Guidelines

### Unit Testing

- Test individual functions in isolation
- Mock external dependencies (Azure APIs)
- Cover both success and failure scenarios
- Test edge cases and boundary conditions

### Integration Testing

- Test end-to-end workflows
- Validate against real Azure environments
- Test with different configuration scenarios
- Verify error handling and retry logic

### Security Testing

- Test authentication and authorization
- Validate input sanitization
- Check for credential exposure
- Test permission boundaries

## 🔍 Code Review Process

### Pull Request Requirements

1. **Clear description** of changes and motivation
2. **Updated documentation** for any new features
3. **Test coverage** for new functionality
4. **No breaking changes** without major version bump
5. **Security review** for authentication/authorization changes

### Review Criteria

- **Functionality**: Does the code work as intended?
- **Security**: Are there any security vulnerabilities?
- **Performance**: Will this impact performance negatively?
- **Maintainability**: Is the code readable and maintainable?
- **Documentation**: Is the documentation complete and accurate?

## 🏷️ Versioning

We follow [Semantic Versioning](https://semver.org/):

- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### Release Process

1. Update version numbers in relevant files
2. Update CHANGELOG.md with release notes
3. Create a release tag
4. Publish release notes

## 🤝 Community Guidelines

### Code of Conduct

- Be respectful and inclusive
- Provide constructive feedback
- Focus on the issue, not the person
- Help others learn and grow

### Communication

- Use clear and concise language
- Provide context for discussions
- Be patient with responses
- Share knowledge and resources

## 🆘 Getting Help

If you need help contributing:

1. **Documentation**: Check README and inline comments
2. **Issues**: Search existing issues and discussions
3. **Discussions**: Start a new discussion for questions
4. **Maintainers**: Tag maintainers for complex issues

## 📋 Contribution Checklist

Before submitting a pull request, ensure:

- [ ] Code follows established patterns and standards
- [ ] All tests pass locally
- [ ] Documentation is updated
- [ ] Configuration schema is updated (if applicable)
- [ ] Examples are provided for new features
- [ ] Security implications are considered
- [ ] Breaking changes are documented
- [ ] Commit messages are clear and descriptive

## 🙏 Recognition

Contributors will be recognized in:

- Release notes
- Contributors section
- Special mentions for significant contributions

Thank you for helping make this project better! 🚀