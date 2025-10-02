# Use official Microsoft PowerShell image as base
FROM mcr.microsoft.com/powershell:7.4-ubuntu-22.04

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    jq \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Azure CLI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Install yq for YAML processing
RUN wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
    && chmod +x /usr/local/bin/yq

# Pre-install PowerShell modules to avoid runtime installation
RUN pwsh -Command "Set-PSRepository -Name PSGallery -InstallationPolicy Trusted" && \
    pwsh -Command "Install-Module -Name Az.Accounts -Force -AllowClobber" && \
    pwsh -Command "Install-Module -Name Microsoft.Graph.Authentication -Force -AllowClobber" && \
    pwsh -Command "Install-Module -Name Microsoft.Graph.Applications -Force -AllowClobber" && \
    pwsh -Command "Install-Module -Name Microsoft.Graph.Identity.DirectoryManagement -Force -AllowClobber" && \
    pwsh -Command "Install-Module -Name powershell-yaml -Force -AllowClobber"

# Copy scripts
COPY scripts/ /app/scripts/
COPY schemas/ /app/schemas/

# Make scripts executable
RUN chmod +x /app/scripts/*.sh /app/scripts/*.ps1

# Set entrypoint
ENTRYPOINT ["/app/scripts/create-enterprise-app.sh"]

# Labels
LABEL maintainer="Azure Automation Team"
LABEL description="Azure Entra Enterprise App Creation Container"
LABEL version="2.0.0"