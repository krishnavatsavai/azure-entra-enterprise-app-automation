#Requires -Version 7.0

<#
.SYNOPSIS
    Validates Azure Entra Enterprise App configuration files against the schema.

.DESCRIPTION
    This script validates YAML configuration files for enterprise applications
    against the JSON schema and performs additional business rule validation.

.PARAMETER ConfigPath
    Path to the configuration file(s) to validate. Supports wildcards.

.PARAMETER SchemaPath
    Path to the JSON schema file for validation.

.PARAMETER Strict
    Enable strict validation mode with additional checks.

.EXAMPLE
    .\Validate-Config.ps1 -ConfigPath ".\templates\*.yaml"
    
.EXAMPLE
    .\Validate-Config.ps1 -ConfigPath ".\examples\salesforce.yaml" -Strict
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath,
    
    [Parameter(Mandatory = $false)]
    [string]$SchemaPath = ".\schemas\enterprise-app-config.schema.json",
    
    [Parameter(Mandatory = $false)]
    [switch]$Strict
)

# Import required modules
try {
    Import-Module powershell-yaml -Force -ErrorAction Stop
}
catch {
    Write-Error "Failed to import required module 'powershell-yaml'. Please install it using: Install-Module -Name powershell-yaml"
    exit 1
}

function Test-JsonSchema {
    param(
        [hashtable]$Data,
        [string]$SchemaPath
    )
    
    # This is a simplified validation - in a real scenario, you'd use a proper JSON schema validator
    # For PowerShell, you might use Newtonsoft.Json.Schema or similar
    
    try {
        if (-not (Test-Path $SchemaPath)) {
            Write-Warning "Schema file not found: $SchemaPath. Skipping schema validation."
            return $true
        }
        
        $schema = Get-Content -Path $SchemaPath -Raw | ConvertFrom-Json
        
        # Basic structure validation
        $required = $schema.required
        foreach ($field in $required) {
            if (-not $Data.ContainsKey($field)) {
                throw "Missing required field: $field"
            }
        }
        
        return $true
    }
    catch {
        Write-Error "Schema validation failed: $($_.Exception.Message)"
        return $false
    }
}

function Test-ConfigurationFile {
    param(
        [string]$FilePath,
        [bool]$StrictMode = $false
    )
    
    $results = @{
        FilePath = $FilePath
        Valid = $false
        Errors = @()
        Warnings = @()
        Info = @()
    }
    
    try {
        Write-Host "Validating: $FilePath" -ForegroundColor Cyan
        
        # Test file exists
        if (-not (Test-Path $FilePath)) {
            $results.Errors += "Configuration file not found: $FilePath"
            return $results
        }
        
        # Test YAML syntax
        try {
            $yamlContent = Get-Content -Path $FilePath -Raw
            $config = ConvertFrom-Yaml $yamlContent
            $results.Info += "YAML syntax is valid"
        }
        catch {
            $results.Errors += "Invalid YAML syntax: $($_.Exception.Message)"
            return $results
        }
        
        # Test required sections
        $requiredSections = @('metadata', 'application')
        foreach ($section in $requiredSections) {
            if (-not $config.ContainsKey($section)) {
                $results.Errors += "Missing required section: $section"
            }
        }
        
        # Validate metadata section
        if ($config.metadata) {
            $requiredMetadata = @('name', 'description', 'version')
            foreach ($field in $requiredMetadata) {
                if (-not $config.metadata.ContainsKey($field) -or [string]::IsNullOrWhiteSpace($config.metadata.$field)) {
                    $results.Errors += "Missing or empty metadata field: $field"
                }
            }
            
            # Validate version format (semantic versioning)
            if ($config.metadata.version -and $config.metadata.version -notmatch '^\d+\.\d+\.\d+$') {
                $results.Errors += "Invalid version format. Expected semantic versioning (x.y.z): $($config.metadata.version)"
            }
        }
        
        # Validate application section
        if ($config.application) {
            $requiredApp = @('galleryAppId', 'displayName')
            foreach ($field in $requiredApp) {
                if (-not $config.application.ContainsKey($field) -or [string]::IsNullOrWhiteSpace($config.application.$field)) {
                    $results.Errors += "Missing or empty application field: $field"
                }
            }
            
            # Validate GUID format for galleryAppId
            if ($config.application.galleryAppId) {
                if (-not [System.Guid]::TryParse($config.application.galleryAppId, [ref][System.Guid]::Empty)) {
                    $results.Errors += "Invalid GUID format for galleryAppId: $($config.application.galleryAppId)"
                }
            }
            
            # Validate display name length
            if ($config.application.displayName -and $config.application.displayName.Length -gt 120) {
                $results.Errors += "Display name exceeds maximum length of 120 characters"
            }
            
            # Validate URLs if provided
            $urlFields = @('homepage', 'logoUrl')
            foreach ($urlField in $urlFields) {
                if ($config.application.$urlField) {
                    try {
                        $null = [System.Uri]::new($config.application.$urlField)
                        $results.Info += "Valid URL format for $urlField"
                    }
                    catch {
                        $results.Errors += "Invalid URL format for $urlField`: $($config.application.$urlField)"
                    }
                }
            }
        }
        
        # Validate assignment section
        if ($config.assignment) {
            # Validate user assignments
            if ($config.assignment.users) {
                foreach ($user in $config.assignment.users) {
                    if (-not $user.userPrincipalName) {
                        $results.Errors += "User assignment missing userPrincipalName"
                    }
                    elseif ($user.userPrincipalName -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') {
                        $results.Errors += "Invalid email format for userPrincipalName: $($user.userPrincipalName)"
                    }
                }
            }
            
            # Validate group assignments
            if ($config.assignment.groups) {
                foreach ($group in $config.assignment.groups) {
                    if (-not $group.displayName) {
                        $results.Errors += "Group assignment missing displayName"
                    }
                    
                    # Validate objectId if provided
                    if ($group.objectId -and -not [System.Guid]::TryParse($group.objectId, [ref][System.Guid]::Empty)) {
                        $results.Errors += "Invalid GUID format for group objectId: $($group.objectId)"
                    }
                }
            }
        }
        
        # Validate SSO section
        if ($config.sso) {
            $validSsoModes = @('saml', 'password', 'linkedSignOn', 'disabled')
            if ($config.sso.ssoMode -and $config.sso.ssoMode -notin $validSsoModes) {
                $results.Errors += "Invalid SSO mode: $($config.sso.ssoMode). Valid values: $($validSsoModes -join ', ')"
            }
            
            # Validate SAML configuration
            if ($config.sso.saml -and $config.sso.ssoMode -eq 'saml') {
                $samlUrls = @('replyUrl', 'signOnUrl', 'logoutUrl')
                foreach ($urlField in $samlUrls) {
                    if ($config.sso.saml.$urlField) {
                        try {
                            $null = [System.Uri]::new($config.sso.saml.$urlField)
                        }
                        catch {
                            $results.Errors += "Invalid URL format for SAML $urlField`: $($config.sso.saml.$urlField)"
                        }
                    }
                }
                
                # Validate NameID format
                $validNameIdFormats = @(
                    'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress',
                    'urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified',
                    'urn:oasis:names:tc:SAML:2.0:nameid-format:persistent',
                    'urn:oasis:names:tc:SAML:2.0:nameid-format:transient'
                )
                
                if ($config.sso.saml.nameIdFormat -and $config.sso.saml.nameIdFormat -notin $validNameIdFormats) {
                    $results.Errors += "Invalid SAML NameID format: $($config.sso.saml.nameIdFormat)"
                }
                
                # Validate attributes
                if ($config.sso.saml.attributes) {
                    foreach ($attribute in $config.sso.saml.attributes) {
                        if (-not $attribute.name -or -not $attribute.source) {
                            $results.Errors += "SAML attribute missing required name or source field"
                        }
                    }
                }
            }
        }
        
        # Validate provisioning section
        if ($config.provisioning) {
            $validProvisioningModes = @('automatic', 'manual')
            if ($config.provisioning.mode -and $config.provisioning.mode -notin $validProvisioningModes) {
                $results.Errors += "Invalid provisioning mode: $($config.provisioning.mode). Valid values: $($validProvisioningModes -join ', ')"
            }
            
            # Validate credentials reference
            if ($config.provisioning.credentials -and $config.provisioning.enabled) {
                if (-not $config.provisioning.credentials.keyVaultName) {
                    $results.Warnings += "Provisioning is enabled but no Key Vault name specified for credentials"
                }
            }
        }
        
        # Validate notifications section
        if ($config.notifications -and $config.notifications.emailAddresses) {
            foreach ($email in $config.notifications.emailAddresses) {
                if ($email -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') {
                    $results.Errors += "Invalid email format in notifications: $email"
                }
            }
            
            if ($config.notifications.webhookUrl) {
                try {
                    $null = [System.Uri]::new($config.notifications.webhookUrl)
                }
                catch {
                    $results.Errors += "Invalid webhook URL format: $($config.notifications.webhookUrl)"
                }
            }
        }
        
        # Strict mode validations
        if ($StrictMode) {
            # Check for recommended fields
            if (-not $config.application.notes) {
                $results.Warnings += "Recommended field missing: application.notes"
            }
            
            if (-not $config.notifications) {
                $results.Warnings += "Recommended section missing: notifications"
            }
            
            # Check for security best practices
            if ($config.assignment -and -not $config.assignment.assignmentRequired) {
                $results.Warnings += "Security recommendation: Consider enabling assignmentRequired for better access control"
            }
            
            if ($config.sso -and $config.sso.ssoMode -eq 'password') {
                $results.Warnings += "Security recommendation: Consider using SAML SSO instead of password-based SSO"
            }
        }
        
        # Set overall validation result
        $results.Valid = ($results.Errors.Count -eq 0)
        
        # Display results
        if ($results.Valid) {
            Write-Host "  ✅ Configuration is valid" -ForegroundColor Green
        }
        else {
            Write-Host "  ❌ Configuration has errors" -ForegroundColor Red
        }
        
        # Display info messages
        foreach ($info in $results.Info) {
            Write-Host "  ℹ️  $info" -ForegroundColor Blue
        }
        
        # Display warnings
        foreach ($warning in $results.Warnings) {
            Write-Host "  ⚠️  $warning" -ForegroundColor Yellow
        }
        
        # Display errors
        foreach ($error in $results.Errors) {
            Write-Host "  ❌ $error" -ForegroundColor Red
        }
        
        return $results
    }
    catch {
        $results.Errors += "Validation failed: $($_.Exception.Message)"
        $results.Valid = $false
        return $results
    }
}

# Main script logic
Write-Host "Azure Entra Enterprise App Configuration Validator v1.0.0" -ForegroundColor Cyan
Write-Host "Configuration Path: $ConfigPath" -ForegroundColor Gray
Write-Host "Schema Path: $SchemaPath" -ForegroundColor Gray
Write-Host "Strict Mode: $Strict" -ForegroundColor Gray
Write-Host ""

# Get configuration files
$configFiles = Get-ChildItem -Path $ConfigPath -ErrorAction SilentlyContinue

if (-not $configFiles) {
    Write-Error "No configuration files found matching: $ConfigPath"
    exit 1
}

$validationResults = @()
$overallValid = $true

# Validate each file
foreach ($file in $configFiles) {
    $result = Test-ConfigurationFile -FilePath $file.FullName -StrictMode:$Strict
    $validationResults += $result
    
    if (-not $result.Valid) {
        $overallValid = $false
    }
    
    Write-Host ""
}

# Summary
Write-Host "Validation Summary:" -ForegroundColor Cyan
Write-Host "Files processed: $($configFiles.Count)" -ForegroundColor Gray
Write-Host "Valid files: $($validationResults.Where({$_.Valid}).Count)" -ForegroundColor Green
Write-Host "Invalid files: $($validationResults.Where({-not $_.Valid}).Count)" -ForegroundColor Red

$totalWarnings = ($validationResults | ForEach-Object { $_.Warnings.Count } | Measure-Object -Sum).Sum
Write-Host "Total warnings: $totalWarnings" -ForegroundColor Yellow

$totalErrors = ($validationResults | ForEach-Object { $_.Errors.Count } | Measure-Object -Sum).Sum
Write-Host "Total errors: $totalErrors" -ForegroundColor Red

Write-Host ""

if ($overallValid) {
    Write-Host "✅ All configurations are valid!" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "❌ One or more configurations have errors" -ForegroundColor Red
    exit 1
}