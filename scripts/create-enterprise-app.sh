#!/bin/bash

# Azure Entra Enterprise App Creation Script using Azure CLI and REST API
# This script eliminates the need for PowerShell module installations
# and provides faster execution in GitHub Actions

set -euo pipefail

# Configuration
CONFIG_FILE="$1"
VALIDATE_ONLY="${2:-false}"
WHATIF="${3:-false}"
VERBOSE="${4:-false}"

# Global variables
MAX_RETRIES=3
BASE_DELAY=2
MAX_DELAY=30

# Logging functions
log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $1" >&2
}

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] [DEBUG] $1"
    fi
}

# Retry function with exponential backoff
retry_with_backoff() {
    local command="$1"
    local operation_name="$2"
    local attempt=1
    
    while (( attempt <= MAX_RETRIES )); do
        log_debug "Attempting $operation_name (attempt $attempt/$MAX_RETRIES)"
        
        if eval "$command"; then
            log_debug "$operation_name succeeded on attempt $attempt"
            return 0
        fi
        
        if (( attempt < MAX_RETRIES )); then
            local delay=$((BASE_DELAY * (2 ** (attempt - 1))))
            delay=$((delay > MAX_DELAY ? MAX_DELAY : delay))
            log_debug "Retrying $operation_name in $delay seconds..."
            sleep $delay
        fi
        
        ((attempt++))
    done
    
    log_error "All retry attempts failed for $operation_name"
    return 1
}

# Parse YAML configuration using yq
parse_config() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Configuration file not found: $config_file"
        exit 1
    fi
    
    # Validate YAML syntax
    if ! yq eval '.' "$config_file" > /dev/null 2>&1; then
        log_error "Invalid YAML syntax in configuration file"
        exit 1
    fi
    
    # Extract key configuration values
    GALLERY_APP_ID=$(yq eval '.application.galleryAppId' "$config_file")
    DISPLAY_NAME=$(yq eval '.application.displayName' "$config_file")
    ASSIGNMENT_REQUIRED=$(yq eval '.assignment.assignmentRequired // false' "$config_file")
    VISIBLE_TO_USERS=$(yq eval '.assignment.visibleToUsers // true' "$config_file")
    
    log_info "Parsed configuration:"
    log_info "  Gallery App ID: $GALLERY_APP_ID"
    log_info "  Display Name: $DISPLAY_NAME"
    log_info "  Assignment Required: $ASSIGNMENT_REQUIRED"
    log_info "  Visible to Users: $VISIBLE_TO_USERS"
}

# Get access token for Microsoft Graph API
get_access_token() {
    log_debug "Getting access token for Microsoft Graph API"
    
    # Use Azure CLI to get access token
    local token
    token=$(az account get-access-token --resource https://graph.microsoft.com --query accessToken -o tsv 2>/dev/null)
    
    if [[ -z "$token" ]]; then
        log_error "Failed to get access token"
        exit 1
    fi
    
    echo "$token"
}

# Create enterprise application from gallery
create_enterprise_app() {
    local gallery_app_id="$1"
    local display_name="$2"
    local access_token="$3"
    
    log_info "Creating enterprise application from gallery template"
    
    local request_body
    request_body=$(jq -n \
        --arg displayName "$display_name" \
        '{displayName: $displayName}')
    
    local response
    response=$(curl -s -X POST \
        "https://graph.microsoft.com/v1.0/applicationTemplates/$gallery_app_id/instantiate" \
        -H "Authorization: Bearer $access_token" \
        -H "Content-Type: application/json" \
        -d "$request_body")
    
    # Check for errors
    if echo "$response" | jq -e '.error' > /dev/null 2>&1; then
        local error_message
        error_message=$(echo "$response" | jq -r '.error.message')
        log_error "Failed to create enterprise application: $error_message"
        exit 1
    fi
    
    # Extract application and service principal IDs
    APPLICATION_ID=$(echo "$response" | jq -r '.application.id')
    SERVICE_PRINCIPAL_ID=$(echo "$response" | jq -r '.servicePrincipal.id')
    
    log_info "Enterprise application created successfully"
    log_info "  Application ID: $APPLICATION_ID"
    log_info "  Service Principal ID: $SERVICE_PRINCIPAL_ID"
}

# Update service principal properties
update_service_principal() {
    local service_principal_id="$1"
    local assignment_required="$2"
    local visible_to_users="$3"
    local access_token="$4"
    
    log_debug "Updating service principal properties"
    
    local request_body
    request_body=$(jq -n \
        --argjson assignmentRequired "$assignment_required" \
        --argjson visible "$visible_to_users" \
        '{
            appRoleAssignmentRequired: $assignmentRequired,
            visible: $visible
        }')
    
    local response
    response=$(curl -s -X PATCH \
        "https://graph.microsoft.com/v1.0/servicePrincipals/$service_principal_id" \
        -H "Authorization: Bearer $access_token" \
        -H "Content-Type: application/json" \
        -d "$request_body")
    
    # Check for errors
    if echo "$response" | jq -e '.error' > /dev/null 2>&1; then
        local error_message
        error_message=$(echo "$response" | jq -r '.error.message')
        log_error "Failed to update service principal: $error_message"
        exit 1
    fi
    
    log_info "Service principal properties updated successfully"
}

# Assign users to application
assign_users() {
    local service_principal_id="$1"
    local config_file="$2"
    local access_token="$3"
    
    # Get users from configuration
    local users_count
    users_count=$(yq eval '.assignment.users | length' "$config_file")
    
    if [[ "$users_count" == "0" ]] || [[ "$users_count" == "null" ]]; then
        log_debug "No users to assign"
        return 0
    fi
    
    log_info "Assigning $users_count users to the application"
    
    for ((i=0; i<users_count; i++)); do
        local user_principal_name
        user_principal_name=$(yq eval ".assignment.users[$i].userPrincipalName" "$config_file")
        
        log_debug "Assigning user: $user_principal_name"
        
        # Get user ID
        local user_response
        user_response=$(curl -s -G \
            "https://graph.microsoft.com/v1.0/users" \
            -H "Authorization: Bearer $access_token" \
            --data-urlencode "\$filter=userPrincipalName eq '$user_principal_name'" \
            --data-urlencode "\$select=id")
        
        local user_id
        user_id=$(echo "$user_response" | jq -r '.value[0].id // empty')
        
        if [[ -z "$user_id" ]]; then
            log_error "User not found: $user_principal_name"
            continue
        fi
        
        # Create assignment
        local assignment_body
        assignment_body=$(jq -n \
            --arg principalId "$user_id" \
            --arg resourceId "$service_principal_id" \
            '{
                principalId: $principalId,
                resourceId: $resourceId,
                appRoleId: "00000000-0000-0000-0000-000000000000"
            }')
        
        local assignment_response
        assignment_response=$(curl -s -X POST \
            "https://graph.microsoft.com/v1.0/users/$user_id/appRoleAssignments" \
            -H "Authorization: Bearer $access_token" \
            -H "Content-Type: application/json" \
            -d "$assignment_body")
        
        if echo "$assignment_response" | jq -e '.error' > /dev/null 2>&1; then
            local error_message
            error_message=$(echo "$assignment_response" | jq -r '.error.message')
            log_error "Failed to assign user $user_principal_name: $error_message"
        else
            log_info "User assigned successfully: $user_principal_name"
        fi
    done
}

# Send notification
send_notification() {
    local status="$1"
    local application_id="$2"
    local service_principal_id="$3"
    local display_name="$4"
    local config_file="$5"
    
    # Get notification email addresses
    local email_count
    email_count=$(yq eval '.notifications.emailAddresses | length' "$config_file" 2>/dev/null || echo "0")
    
    if [[ "$email_count" == "0" ]] || [[ "$email_count" == "null" ]]; then
        log_debug "No notification emails configured"
        return 0
    fi
    
    log_info "Notification would be sent to $email_count recipients"
    log_info "Status: $status"
    log_info "Application: $display_name"
    log_info "Application ID: $application_id"
    log_info "Service Principal ID: $service_principal_id"
}

# Main execution function
main() {
    log_info "Azure Entra Enterprise App Creation Script v2.0.0"
    log_info "Using Azure CLI and REST API (faster execution)"
    log_info "Configuration file: $CONFIG_FILE"
    
    # Validate prerequisites
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v yq &> /dev/null; then
        log_error "yq is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed or not in PATH"
        exit 1
    fi
    
    # Parse configuration
    parse_config "$CONFIG_FILE"
    
    if [[ "$VALIDATE_ONLY" == "true" ]]; then
        log_info "✅ Configuration validation completed successfully"
        exit 0
    fi
    
    if [[ "$WHATIF" == "true" ]]; then
        log_info "WhatIf: Would create enterprise application with configuration:"
        log_info "  Display Name: $DISPLAY_NAME"
        log_info "  Gallery App ID: $GALLERY_APP_ID"
        log_info "  Assignment Required: $ASSIGNMENT_REQUIRED"
        exit 0
    fi
    
    # Get access token
    local access_token
    access_token=$(get_access_token)
    
    # Create enterprise application
    retry_with_backoff \
        "create_enterprise_app '$GALLERY_APP_ID' '$DISPLAY_NAME' '$access_token'" \
        "Create Enterprise Application"
    
    # Update service principal properties
    retry_with_backoff \
        "update_service_principal '$SERVICE_PRINCIPAL_ID' '$ASSIGNMENT_REQUIRED' '$VISIBLE_TO_USERS' '$access_token'" \
        "Update Service Principal"
    
    # Assign users
    retry_with_backoff \
        "assign_users '$SERVICE_PRINCIPAL_ID' '$CONFIG_FILE' '$access_token'" \
        "Assign Users"
    
    # Send notification
    send_notification "Success" "$APPLICATION_ID" "$SERVICE_PRINCIPAL_ID" "$DISPLAY_NAME" "$CONFIG_FILE"
    
    # Output for GitHub Actions
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
        echo "application-id=$APPLICATION_ID" >> "$GITHUB_OUTPUT"
        echo "service-principal-id=$SERVICE_PRINCIPAL_ID" >> "$GITHUB_OUTPUT"
        echo "display-name=$DISPLAY_NAME" >> "$GITHUB_OUTPUT"
        echo "status=Success" >> "$GITHUB_OUTPUT"
    fi
    
    log_info "✅ Enterprise application creation completed successfully!"
}

# Execute main function
main "$@"