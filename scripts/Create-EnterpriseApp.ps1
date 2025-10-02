#Requires -Version 7.0
#Requires -Modules @{ ModuleName="Az.Accounts"; ModuleVersion="2.0.0" }
#Requires -Modules @{ ModuleName="Microsoft.Graph.Authentication"; ModuleVersion="2.0.0" }
#Requires -Modules @{ ModuleName="Microsoft.Graph.Applications"; ModuleVersion="2.0.0" }
#Requires -Modules @{ ModuleName="Microsoft.Graph.Identity.DirectoryManagement"; ModuleVersion="2.0.0" }

<#
.SYNOPSIS
    Creates an Azure Entra Gallery Enterprise Application based on YAML configuration.

.DESCRIPTION
    This script automates the creation of Azure Entra Gallery Enterprise Applications
    using Microsoft Graph API with proper error handling, retry logic, and security best practices.

.PARAMETER ConfigPath
    Path to the YAML configuration file defining the enterprise application settings.

.PARAMETER Validate
    Switch to validate the configuration without creating the application.

.PARAMETER WhatIf
    Switch to show what would be created without making actual changes.

.PARAMETER Verbose
    Enable verbose logging for debugging purposes.

.EXAMPLE
    .\Create-EnterpriseApp.ps1 -ConfigPath ".\templates\my-app.yaml"
    
.EXAMPLE
    .\Create-EnterpriseApp.ps1 -ConfigPath ".\templates\my-app.yaml" -WhatIf -Verbose

.NOTES
    Author: Azure Automation Team
    Version: 1.0.0
    Requires: PowerShell 7.0+, Az.Accounts, Microsoft.Graph modules
    
    Authentication:
    - Uses Managed Identity when running in Azure (recommended)
    - Falls back to Service Principal authentication for CI/CD
    - Supports interactive authentication for local development
    
    Security:
    - Implements least privilege access
    - Uses secure credential storage
    - Enables comprehensive logging and monitoring
    - Implements retry logic with exponential backoff
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType 'Leaf' })]
    [string]$ConfigPath,
    
    [Parameter(Mandatory = $false)]
    [switch]$Validate,
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory = $false)]
    [switch]$Verbose
)

# Set error action preference for robust error handling
$ErrorActionPreference = 'Stop'
$VerbosePreference = if ($Verbose) { 'Continue' } else { 'SilentlyContinue' }

# Import required modules with error handling
try {
    Import-Module powershell-yaml -Force -ErrorAction Stop
    Import-Module Az.Accounts -Force -ErrorAction Stop
    Import-Module Microsoft.Graph.Authentication -Force -ErrorAction Stop
    Import-Module Microsoft.Graph.Applications -Force -ErrorAction Stop
    Import-Module Microsoft.Graph.Identity.DirectoryManagement -Force -ErrorAction Stop
}
catch {
    Write-Error "Failed to import required modules. Please ensure all dependencies are installed: $_"
    exit 1
}

# Global variables for retry logic
$script:MaxRetries = 3
$script:BaseDelaySeconds = 2
$script:MaxDelaySeconds = 30

# Logging configuration
$script:LogLevel = if ($Verbose) { "Debug" } else { "Info" }

#region Helper Functions

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("Debug", "Info", "Warning", "Error")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        "Debug" { if ($script:LogLevel -eq "Debug") { Write-Host $logMessage -ForegroundColor Gray } }
        "Info" { Write-Host $logMessage -ForegroundColor White }
        "Warning" { Write-Warning $logMessage }
        "Error" { Write-Error $logMessage }
    }
}

function Invoke-WithRetry {
    param(
        [scriptblock]$ScriptBlock,
        [string]$OperationName = "Operation",
        [int]$MaxRetries = $script:MaxRetries,
        [int]$BaseDelaySeconds = $script:BaseDelaySeconds
    )
    
    $attempt = 0
    $lastException = $null
    
    do {
        $attempt++
        try {
            Write-Log "Attempting $OperationName (attempt $attempt/$MaxRetries)" -Level Debug
            return & $ScriptBlock
        }
        catch {
            $lastException = $_
            Write-Log "Attempt $attempt failed for $OperationName`: $($_.Exception.Message)" -Level Warning
            
            if ($attempt -lt $MaxRetries) {
                $delay = [Math]::Min($BaseDelaySeconds * [Math]::Pow(2, $attempt - 1), $script:MaxDelaySeconds)
                Write-Log "Retrying in $delay seconds..." -Level Debug
                Start-Sleep -Seconds $delay
            }
        }
    } while ($attempt -lt $MaxRetries)
    
    Write-Log "All retry attempts failed for $OperationName" -Level Error
    throw $lastException
}

function Test-ConfigurationFile {
    param([string]$Path)
    
    Write-Log "Validating configuration file: $Path" -Level Debug
    
    try {
        $yamlContent = Get-Content -Path $Path -Raw
        $config = ConvertFrom-Yaml $yamlContent
        
        # Basic validation
        if (-not $config.metadata) {
            throw "Missing required 'metadata' section"
        }
        if (-not $config.application) {
            throw "Missing required 'application' section"
        }
        if (-not $config.application.galleryAppId) {
            throw "Missing required 'application.galleryAppId'"
        }
        if (-not $config.application.displayName) {
            throw "Missing required 'application.displayName'"
        }
        
        # Validate GUID format
        if (-not [System.Guid]::TryParse($config.application.galleryAppId, [ref][System.Guid]::Empty)) {
            throw "Invalid GUID format for 'application.galleryAppId'"
        }
        
        Write-Log "Configuration validation passed" -Level Info
        return $config
    }
    catch {
        Write-Log "Configuration validation failed: $($_.Exception.Message)" -Level Error
        throw
    }
}

function Connect-ToAzureServices {
    param([bool]$UseManagedIdentity = $false)
    
    try {
        # Determine authentication method
        if ($UseManagedIdentity -or $env:AZURE_CLIENT_ID) {
            Write-Log "Authenticating using Managed Identity or Service Principal" -Level Info
            
            if ($env:AZURE_CLIENT_ID -and $env:AZURE_CLIENT_SECRET -and $env:AZURE_TENANT_ID) {
                # Service Principal authentication for CI/CD
                $securePassword = ConvertTo-SecureString $env:AZURE_CLIENT_SECRET -AsPlainText -Force
                $credential = New-Object System.Management.Automation.PSCredential($env:AZURE_CLIENT_ID, $securePassword)
                
                Connect-AzAccount -ServicePrincipal -Credential $credential -TenantId $env:AZURE_TENANT_ID | Out-Null
                Connect-MgGraph -ClientId $env:AZURE_CLIENT_ID -ClientSecret $securePassword -TenantId $env:AZURE_TENANT_ID | Out-Null
            }
            else {
                # Managed Identity authentication
                Connect-AzAccount -Identity | Out-Null
                Connect-MgGraph -Identity | Out-Null
            }
        }
        else {
            Write-Log "Authenticating interactively" -Level Info
            Connect-AzAccount | Out-Null
            Connect-MgGraph -Scopes "Application.ReadWrite.All", "Directory.Read.All", "User.Read.All", "Group.Read.All" | Out-Null
        }
        
        # Verify connections
        $azContext = Get-AzContext
        $mgContext = Get-MgContext
        
        if (-not $azContext -or -not $mgContext) {
            throw "Failed to establish Azure or Microsoft Graph connections"
        }
        
        Write-Log "Successfully authenticated to Azure (Tenant: $($azContext.Tenant.Id))" -Level Info
        Write-Log "Successfully authenticated to Microsoft Graph (Tenant: $($mgContext.TenantId))" -Level Info
        
        return @{
            AzureContext = $azContext
            GraphContext = $mgContext
        }
    }
    catch {
        Write-Log "Authentication failed: $($_.Exception.Message)" -Level Error
        throw
    }
}

function Get-GalleryApplication {
    param([string]$TemplateId)
    
    return Invoke-WithRetry -OperationName "Get Gallery Application" -ScriptBlock {
        Write-Log "Searching for gallery application template: $TemplateId" -Level Debug
        $template = Get-MgApplicationTemplate -ApplicationTemplateId $TemplateId -ErrorAction Stop
        
        if (-not $template) {
            throw "Gallery application template not found: $TemplateId"
        }
        
        Write-Log "Found gallery application: $($template.DisplayName)" -Level Info
        return $template
    }
}

function New-EnterpriseApplicationFromGallery {
    param(
        [string]$TemplateId,
        [string]$DisplayName
    )
    
    return Invoke-WithRetry -OperationName "Create Enterprise Application" -ScriptBlock {
        Write-Log "Creating enterprise application from gallery template" -Level Info
        
        $instantiateParams = @{
            DisplayName = $DisplayName
        }
        
        $result = Invoke-MgInstantiateApplicationTemplate -ApplicationTemplateId $TemplateId -BodyParameter $instantiateParams -ErrorAction Stop
        
        if (-not $result) {
            throw "Failed to create enterprise application"
        }
        
        Write-Log "Enterprise application created successfully: $($result.Application.DisplayName)" -Level Info
        return $result
    }
}

function Set-ApplicationProperties {
    param(
        [string]$ApplicationId,
        [hashtable]$Properties
    )
    
    Invoke-WithRetry -OperationName "Update Application Properties" -ScriptBlock {
        Write-Log "Updating application properties" -Level Debug
        
        $updateParams = @{}
        
        if ($Properties.Homepage) {
            $updateParams.Web = @{ HomePageUrl = $Properties.Homepage }
        }
        
        if ($Properties.LogoUrl) {
            # Note: Logo should be uploaded as binary data, not URL
            Write-Log "Logo URL provided but logo upload requires binary data" -Level Warning
        }
        
        if ($Properties.Notes) {
            $updateParams.Notes = $Properties.Notes
        }
        
        if ($updateParams.Count -gt 0) {
            Update-MgApplication -ApplicationId $ApplicationId -BodyParameter $updateParams -ErrorAction Stop
            Write-Log "Application properties updated successfully" -Level Info
        }
    }
}

function Set-ServicePrincipalProperties {
    param(
        [string]$ServicePrincipalId,
        [hashtable]$AssignmentConfig
    )
    
    Invoke-WithRetry -OperationName "Update Service Principal Properties" -ScriptBlock {
        Write-Log "Updating service principal properties" -Level Debug
        
        $updateParams = @{}
        
        if ($null -ne $AssignmentConfig.AssignmentRequired) {
            $updateParams.AppRoleAssignmentRequired = $AssignmentConfig.AssignmentRequired
        }
        
        if ($null -ne $AssignmentConfig.VisibleToUsers) {
            $updateParams.Visible = $AssignmentConfig.VisibleToUsers
        }
        
        if ($updateParams.Count -gt 0) {
            Update-MgServicePrincipal -ServicePrincipalId $ServicePrincipalId -BodyParameter $updateParams -ErrorAction Stop
            Write-Log "Service principal properties updated successfully" -Level Info
        }
    }
}

function Add-UserAssignments {
    param(
        [string]$ServicePrincipalId,
        [array]$Users
    )
    
    if (-not $Users -or $Users.Count -eq 0) {
        Write-Log "No users to assign" -Level Debug
        return
    }
    
    foreach ($user in $Users) {
        Invoke-WithRetry -OperationName "Assign User $($user.userPrincipalName)" -ScriptBlock {
            Write-Log "Assigning user: $($user.userPrincipalName)" -Level Debug
            
            # Get user object
            $userObject = Get-MgUser -Filter "userPrincipalName eq '$($user.userPrincipalName)'" -ErrorAction Stop
            if (-not $userObject) {
                throw "User not found: $($user.userPrincipalName)"
            }
            
            # Create assignment
            $assignmentParams = @{
                PrincipalId = $userObject.Id
                ResourceId = $ServicePrincipalId
                AppRoleId = "00000000-0000-0000-0000-000000000000" # Default role
            }
            
            New-MgUserAppRoleAssignment -UserId $userObject.Id -BodyParameter $assignmentParams -ErrorAction Stop
            Write-Log "User assigned successfully: $($user.userPrincipalName)" -Level Info
        }
    }
}

function Add-GroupAssignments {
    param(
        [string]$ServicePrincipalId,
        [array]$Groups
    )
    
    if (-not $Groups -or $Groups.Count -eq 0) {
        Write-Log "No groups to assign" -Level Debug
        return
    }
    
    foreach ($group in $Groups) {
        Invoke-WithRetry -OperationName "Assign Group $($group.displayName)" -ScriptBlock {
            Write-Log "Assigning group: $($group.displayName)" -Level Debug
            
            # Get group object
            $groupObject = if ($group.objectId) {
                Get-MgGroup -GroupId $group.objectId -ErrorAction Stop
            } else {
                Get-MgGroup -Filter "displayName eq '$($group.displayName)'" -ErrorAction Stop | Select-Object -First 1
            }
            
            if (-not $groupObject) {
                throw "Group not found: $($group.displayName)"
            }
            
            # Create assignment
            $assignmentParams = @{
                PrincipalId = $groupObject.Id
                ResourceId = $ServicePrincipalId
                AppRoleId = "00000000-0000-0000-0000-000000000000" # Default role
            }
            
            New-MgGroupAppRoleAssignment -GroupId $groupObject.Id -BodyParameter $assignmentParams -ErrorAction Stop
            Write-Log "Group assigned successfully: $($group.displayName)" -Level Info
        }
    }
}

function Send-NotificationEmail {
    param(
        [array]$EmailAddresses,
        [string]$Subject,
        [string]$Body
    )
    
    if (-not $EmailAddresses -or $EmailAddresses.Count -eq 0) {
        Write-Log "No email addresses configured for notifications" -Level Debug
        return
    }
    
    try {
        Write-Log "Sending notification emails to $($EmailAddresses.Count) recipients" -Level Info
        
        # This would typically integrate with Azure Communication Services or Logic Apps
        # For now, just log the notification
        Write-Log "Email notification would be sent to: $($EmailAddresses -join ', ')" -Level Info
        Write-Log "Subject: $Subject" -Level Debug
        Write-Log "Body: $Body" -Level Debug
    }
    catch {
        Write-Log "Failed to send notification emails: $($_.Exception.Message)" -Level Warning
    }
}

#endregion

#region Main Functions

function New-EnterpriseAppFromConfig {
    param([hashtable]$Config)
    
    Write-Log "Starting enterprise application creation process" -Level Info
    
    try {
        # Step 1: Get gallery application template
        $template = Get-GalleryApplication -TemplateId $Config.application.galleryAppId
        
        # Step 2: Create enterprise application
        $result = New-EnterpriseApplicationFromGallery -TemplateId $Config.application.galleryAppId -DisplayName $Config.application.displayName
        
        $applicationId = $result.Application.Id
        $servicePrincipalId = $result.ServicePrincipal.Id
        
        Write-Log "Application ID: $applicationId" -Level Info
        Write-Log "Service Principal ID: $servicePrincipalId" -Level Info
        
        # Step 3: Update application properties
        if ($Config.application.homepage -or $Config.application.logoUrl -or $Config.application.notes) {
            Set-ApplicationProperties -ApplicationId $applicationId -Properties $Config.application
        }
        
        # Step 4: Update service principal properties
        if ($Config.assignment) {
            Set-ServicePrincipalProperties -ServicePrincipalId $servicePrincipalId -AssignmentConfig $Config.assignment
        }
        
        # Step 5: Assign users
        if ($Config.assignment -and $Config.assignment.users) {
            Add-UserAssignments -ServicePrincipalId $servicePrincipalId -Users $Config.assignment.users
        }
        
        # Step 6: Assign groups
        if ($Config.assignment -and $Config.assignment.groups) {
            Add-GroupAssignments -ServicePrincipalId $servicePrincipalId -Groups $Config.assignment.groups
        }
        
        # Step 7: Send notifications
        if ($Config.notifications -and $Config.notifications.emailAddresses) {
            $subject = "Enterprise Application Created: $($Config.application.displayName)"
            $body = @"
Enterprise Application has been successfully created:

Application Name: $($Config.application.displayName)
Application ID: $applicationId
Service Principal ID: $servicePrincipalId
Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')

Configuration: $($Config.metadata.name) v$($Config.metadata.version)
"@
            Send-NotificationEmail -EmailAddresses $Config.notifications.emailAddresses -Subject $subject -Body $body
        }
        
        Write-Log "Enterprise application creation completed successfully" -Level Info
        
        return @{
            ApplicationId = $applicationId
            ServicePrincipalId = $servicePrincipalId
            DisplayName = $Config.application.displayName
            Status = "Success"
        }
    }
    catch {
        Write-Log "Enterprise application creation failed: $($_.Exception.Message)" -Level Error
        
        # Send failure notification
        if ($Config.notifications -and $Config.notifications.emailAddresses) {
            $subject = "Enterprise Application Creation Failed: $($Config.application.displayName)"
            $body = @"
Enterprise Application creation failed:

Application Name: $($Config.application.displayName)
Error: $($_.Exception.Message)
Failed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')

Configuration: $($Config.metadata.name) v$($Config.metadata.version)
"@
            Send-NotificationEmail -EmailAddresses $Config.notifications.emailAddresses -Subject $subject -Body $body
        }
        
        throw
    }
}

#endregion

#region Main Script Logic

function Main {
    Write-Log "Azure Entra Enterprise App Creation Script v1.0.0" -Level Info
    Write-Log "Configuration file: $ConfigPath" -Level Info
    
    try {
        # Step 1: Validate configuration
        Write-Log "Step 1: Validating configuration" -Level Info
        $config = Test-ConfigurationFile -Path $ConfigPath
        
        if ($Validate) {
            Write-Log "Configuration validation completed successfully" -Level Info
            return
        }
        
        # Step 2: Connect to Azure services
        Write-Log "Step 2: Connecting to Azure services" -Level Info
        $connections = Connect-ToAzureServices -UseManagedIdentity:($env:AZURE_CLIENT_ID -or $env:MSI_ENDPOINT)
        
        # Step 3: Create enterprise application
        if ($WhatIf) {
            Write-Log "WhatIf: Would create enterprise application with the following configuration:" -Level Info
            Write-Log "  Display Name: $($config.application.displayName)" -Level Info
            Write-Log "  Gallery App ID: $($config.application.galleryAppId)" -Level Info
            Write-Log "  Assignment Required: $($config.assignment.assignmentRequired)" -Level Info
            Write-Log "  Users to Assign: $($config.assignment.users.Count)" -Level Info
            Write-Log "  Groups to Assign: $($config.assignment.groups.Count)" -Level Info
            return
        }
        
        Write-Log "Step 3: Creating enterprise application" -Level Info
        $result = New-EnterpriseAppFromConfig -Config $config
        
        Write-Log "Enterprise application creation completed successfully!" -Level Info
        Write-Log "Application ID: $($result.ApplicationId)" -Level Info
        Write-Log "Service Principal ID: $($result.ServicePrincipalId)" -Level Info
        
        # Output result for GitHub Actions
        if ($env:GITHUB_OUTPUT) {
            Add-Content -Path $env:GITHUB_OUTPUT -Value "application-id=$($result.ApplicationId)"
            Add-Content -Path $env:GITHUB_OUTPUT -Value "service-principal-id=$($result.ServicePrincipalId)"
            Add-Content -Path $env:GITHUB_OUTPUT -Value "display-name=$($result.DisplayName)"
        }
    }
    catch {
        Write-Log "Script execution failed: $($_.Exception.Message)" -Level Error
        
        # Output error for GitHub Actions
        if ($env:GITHUB_OUTPUT) {
            Add-Content -Path $env:GITHUB_OUTPUT -Value "error=$($_.Exception.Message)"
            Add-Content -Path $env:GITHUB_OUTPUT -Value "status=Failed"
        }
        
        exit 1
    }
    finally {
        # Cleanup connections
        try {
            Disconnect-AzAccount -ErrorAction SilentlyContinue | Out-Null
            Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
            Write-Log "Disconnected from Azure services" -Level Debug
        }
        catch {
            Write-Log "Warning: Failed to disconnect from Azure services: $($_.Exception.Message)" -Level Warning
        }
    }
}

# Execute main function
Main

#endregion