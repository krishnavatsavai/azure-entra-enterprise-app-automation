# Docker Development Guide

This guide explains how to develop, test, and deploy the Docker-based Azure Entra Enterprise App creation solution.

## 🛠️ Development Setup

### Prerequisites
- Docker Desktop or Docker Engine
- Docker Compose
- Azure CLI (for local testing)
- Git

### Local Development

```bash
# Clone the repository
git clone https://github.com/krishnavatsavai/azure-entra-enterprise-app-automation.git
cd azure-entra-enterprise-app-automation

# Switch to Docker branch
git checkout feature/docker-container-approach

# Build the Docker image
docker build -t enterprise-app-creator:dev -f docker/Dockerfile .

# Run with a test configuration
docker run --rm \
  -e AZURE_CLIENT_ID="your-client-id" \
  -e AZURE_TENANT_ID="your-tenant-id" \
  -v "./examples/test-validation.yaml:/app/config.yaml:ro" \
  enterprise-app-creator:dev \
  -ConfigPath /app/config.yaml -Validate -Verbose
```

### Interactive Development

```bash
# Start interactive development container
docker-compose -f docker/docker-compose.yml run enterprise-app-creator-dev

# Inside the container, you can:
# - Test configurations: pwsh /app/scripts/Create-EnterpriseApp.ps1 -ConfigPath /app/examples/test-validation.yaml -Validate
# - Debug issues: pwsh -c "Get-Module -ListAvailable"
# - Validate tools: az --version && yq --version
```

## 🧪 Testing

### Unit Tests
```bash
# Test container build
docker build -t enterprise-app-creator:test -f docker/Dockerfile .

# Test basic functionality
docker run --rm enterprise-app-creator:test \
  -ConfigPath /app/templates/enterprise-app-template.yaml \
  -Validate

# Test with invalid config (should fail gracefully)
docker run --rm enterprise-app-creator:test \
  -ConfigPath /app/invalid-config.yaml \
  -Validate
```

### Integration Tests
```bash
# Test full workflow with Docker Compose
export AZURE_CLIENT_ID="your-client-id"
export AZURE_CLIENT_SECRET="your-client-secret"
export AZURE_TENANT_ID="your-tenant-id"
export AZURE_SUBSCRIPTION_ID="your-subscription-id"

docker-compose -f docker/docker-compose.yml up enterprise-app-creator
```

## 📦 Building and Publishing

### Local Build
```bash
# Build for local testing
docker build -t enterprise-app-creator:local -f docker/Dockerfile .

# Build with BuildKit for optimization
DOCKER_BUILDKIT=1 docker build -t enterprise-app-creator:optimized -f docker/Dockerfile .
```

### GitHub Actions Build
The GitHub Actions workflow automatically builds and publishes images:

```yaml
# Triggered on:
# - Push to main branch
# - Changes to docker/, scripts/, schemas/, templates/ directories
# - Manual workflow dispatch

# Publishes to:
# - ghcr.io/krishnavatsavai/azure-entra-enterprise-app-automation:latest
# - ghcr.io/krishnavatsavai/azure-entra-enterprise-app-automation:main
# - ghcr.io/krishnavatsavai/azure-entra-enterprise-app-automation:sha-<commit>
```

### Manual Publishing
```bash
# Tag the image
docker tag enterprise-app-creator:local ghcr.io/krishnavatsavai/azure-entra-enterprise-app-automation:manual

# Login to GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Push the image
docker push ghcr.io/krishnavatsavai/azure-entra-enterprise-app-automation:manual
```

## 🔧 Customization

### Adding New Dependencies
```dockerfile
# In docker/Dockerfile, add to the system dependencies section:
RUN apt-get update && apt-get install -y \
    curl \
    jq \
    wget \
    ca-certificates \
    your-new-package \
    && rm -rf /var/lib/apt/lists/*
```

### Adding PowerShell Modules
```dockerfile
# In docker/Dockerfile, add to the PowerShell modules section:
RUN pwsh -Command "Install-Module -Name YourModule -Force -AllowClobber"
```

### Custom Entrypoint
```bash
# Create custom entrypoint script
cat > custom-entrypoint.sh << 'EOF'
#!/bin/bash
echo "Custom initialization..."
# Your custom logic here
exec pwsh /app/scripts/Create-EnterpriseApp.ps1 "$@"
EOF

# Use in Dockerfile
COPY custom-entrypoint.sh /app/custom-entrypoint.sh
RUN chmod +x /app/custom-entrypoint.sh
ENTRYPOINT ["/app/custom-entrypoint.sh"]
```

## 🐛 Troubleshooting

### Common Issues

#### Container Won't Start
```bash
# Check container logs
docker logs enterprise-app-creator

# Run interactively to debug
docker run -it --entrypoint /bin/bash enterprise-app-creator:latest
```

#### PowerShell Module Issues
```bash
# Check installed modules
docker run --rm enterprise-app-creator:latest pwsh -c "Get-Module -ListAvailable"

# Reinstall modules
docker run --rm enterprise-app-creator:latest pwsh -c "Install-Module -Name Az.Accounts -Force"
```

#### Authentication Issues
```bash
# Test Azure authentication
docker run --rm \
  -e AZURE_CLIENT_ID="$AZURE_CLIENT_ID" \
  -e AZURE_TENANT_ID="$AZURE_TENANT_ID" \
  enterprise-app-creator:latest \
  pwsh -c "Connect-AzAccount -Identity; Get-AzContext"
```

#### Configuration Issues
```bash
# Validate configuration file
docker run --rm \
  -v "./your-config.yaml:/app/config.yaml:ro" \
  enterprise-app-creator:latest \
  -ConfigPath /app/config.yaml -Validate -Verbose
```

### Performance Optimization

#### Reduce Image Size
```dockerfile
# Use multi-stage builds
FROM mcr.microsoft.com/powershell:7.4-ubuntu-22.04 AS builder
# Install and configure everything

FROM mcr.microsoft.com/powershell:7.4-ubuntu-22.04 AS runtime
# Copy only necessary files from builder
COPY --from=builder /app /app
```

#### Cache Dependencies
```dockerfile
# Copy requirements first for better caching
COPY requirements.txt /tmp/
RUN pip install -r /tmp/requirements.txt

# Copy application code later
COPY . /app
```

## 📊 Monitoring and Logging

### Container Health Checks
```dockerfile
# Add health check to Dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD pwsh -c "Get-Module Az.Accounts" || exit 1
```

### Logging Configuration
```bash
# Run with structured logging
docker run --rm \
  --log-driver json-file \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  enterprise-app-creator:latest \
  -ConfigPath /app/config.yaml -Verbose
```

### Monitoring Container Metrics
```bash
# Monitor resource usage
docker stats enterprise-app-creator

# Get detailed container info
docker inspect enterprise-app-creator
```

## 🚀 Production Deployment

### Kubernetes Deployment
```yaml
apiVersion: apps/v1
kind: Job
metadata:
  name: enterprise-app-creator
spec:
  template:
    spec:
      containers:
      - name: creator
        image: ghcr.io/krishnavatsavai/azure-entra-enterprise-app-automation:latest
        env:
        - name: AZURE_CLIENT_ID
          valueFrom:
            secretKeyRef:
              name: azure-credentials
              key: client-id
        volumeMounts:
        - name: config
          mountPath: /app/config.yaml
          subPath: config.yaml
      volumes:
      - name: config
        configMap:
          name: enterprise-app-config
      restartPolicy: OnFailure
```

### Docker Swarm Deployment
```yaml
version: '3.8'
services:
  enterprise-app-creator:
    image: ghcr.io/krishnavatsavai/azure-entra-enterprise-app-automation:latest
    environment:
      - AZURE_CLIENT_ID_FILE=/run/secrets/azure_client_id
      - AZURE_CLIENT_SECRET_FILE=/run/secrets/azure_client_secret
    secrets:
      - azure_client_id
      - azure_client_secret
    configs:
      - source: app_config
        target: /app/config.yaml
        
secrets:
  azure_client_id:
    external: true
  azure_client_secret:
    external: true
    
configs:
  app_config:
    file: ./examples/production-config.yaml
```

This guide provides comprehensive information for developing, testing, and deploying the Docker-based solution.