# Contributing to VPN DevOps Project

Thank you for your interest in contributing to the VPN DevOps Project! This document provides guidelines and information for contributors.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Contributing Process](#contributing-process)
- [Coding Standards](#coding-standards)
- [Testing Guidelines](#testing-guidelines)
- [Documentation](#documentation)
- [Release Process](#release-process)

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you agree to uphold this code.

## Getting Started

### Prerequisites

- Docker and Docker Compose
- kubectl (for Kubernetes development)
- terraform (for infrastructure development)
- Python 3.11+ (for API development)
- Node.js 18+ (for frontend development)
- Git

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/vpn-devops.git
   cd vpn-devops
   git remote add upstream https://github.com/ORIGINAL_OWNER/vpn-devops.git
   ```

## Development Setup

### Local Development Environment

1. **Start the development environment:**
   ```bash
   ./scripts/setup.sh
   ```

2. **Verify services are running:**
   ```bash
   docker-compose ps
   curl http://localhost:8080/health
   ```

3. **Run tests:**
   ```bash
   # API tests
   cd src/api
   python -m pytest tests/ -v

   # Integration tests
   ./scripts/test-integration.sh

   # End-to-end tests
   ./scripts/test-e2e.sh
   ```

### Kubernetes Development

1. **Set up local Kubernetes cluster:**
   ```bash
   # Using minikube
   minikube start
   ./scripts/deploy-local-k8s.sh

   # Using kind
   kind create cluster
   ./scripts/deploy-local-k8s.sh

   # Using k3s
   curl -sfL https://get.k3s.io | sh -
   ./scripts/deploy-local-k8s.sh
   ```

2. **Verify deployment:**
   ```bash
   kubectl get pods -n vpn-system
   kubectl get services -n vpn-system
   ```

## Contributing Process

### 1. Create an Issue

Before starting work, please:
- Check existing issues to avoid duplicates
- Create an issue describing the problem or feature
- Wait for maintainer approval before starting work

### 2. Create a Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/your-bug-fix
```

### 3. Make Changes

- Write clean, readable code
- Follow the coding standards
- Add tests for new functionality
- Update documentation as needed

### 4. Test Your Changes

```bash
# Run all tests
./scripts/test-all.sh

# Run specific test suites
./scripts/test-unit.sh
./scripts/test-integration.sh
./scripts/test-e2e.sh
```

### 5. Commit Changes

```bash
git add .
git commit -m "feat: add new VPN client management feature"
```

Use conventional commit messages:
- `feat:` for new features
- `fix:` for bug fixes
- `docs:` for documentation changes
- `style:` for formatting changes
- `refactor:` for code refactoring
- `test:` for test additions
- `chore:` for maintenance tasks

### 6. Push and Create Pull Request

```bash
git push origin feature/your-feature-name
```

Then create a pull request on GitHub with:
- Clear description of changes
- Reference to related issues
- Screenshots (if applicable)
- Testing instructions

## Coding Standards

### Python (API)

- Follow PEP 8 style guide
- Use type hints
- Maximum line length: 88 characters
- Use Black for formatting
- Use isort for import sorting

```python
# Example
from typing import List, Optional
import logging

logger = logging.getLogger(__name__)

def create_vpn_client(
    name: str, 
    config: Optional[dict] = None
) -> VPNClient:
    """Create a new VPN client with given name and configuration."""
    if not name:
        raise ValueError("Client name cannot be empty")
    
    client = VPNClient(name=name, config=config or {})
    db.session.add(client)
    db.session.commit()
    
    logger.info(f"Created VPN client: {name}")
    return client
```

### YAML (Kubernetes, Docker Compose)

- Use 2 spaces for indentation
- Use consistent naming conventions
- Add comments for complex configurations

```yaml
# Example
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vpn-api
  namespace: vpn-system
  labels:
    app: vpn-api
    version: v1.0.0
spec:
  replicas: 3
  selector:
    matchLabels:
      app: vpn-api
```

### Terraform

- Use consistent formatting
- Add descriptions for all variables
- Use meaningful resource names
- Follow naming conventions

```hcl
# Example
variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "vpn-cluster"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.cluster_name))
    error_message = "Cluster name must contain only lowercase letters, numbers, and hyphens."
  }
}
```

### Docker

- Use multi-stage builds
- Minimize image size
- Use specific base image tags
- Add health checks

```dockerfile
# Example
FROM python:3.11-slim as builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

FROM python:3.11-slim
WORKDIR /app
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY . .
USER 1000
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1
CMD ["python", "app.py"]
```

## Testing Guidelines

### Unit Tests

- Test individual functions and methods
- Use mocking for external dependencies
- Aim for 90%+ code coverage
- Test both success and error cases

```python
# Example
def test_create_vpn_client_success():
    """Test successful VPN client creation."""
    client = create_vpn_client("testclient")
    assert client.name == "testclient"
    assert client.is_active == True

def test_create_vpn_client_empty_name():
    """Test VPN client creation with empty name."""
    with pytest.raises(ValueError, match="Client name cannot be empty"):
        create_vpn_client("")
```

### Integration Tests

- Test component interactions
- Use test databases and services
- Test API endpoints
- Test database operations

```python
# Example
def test_vpn_client_api_integration(client, auth_headers):
    """Test VPN client API integration."""
    # Create client
    response = client.post('/api/clients', 
                         json={'name': 'testclient'},
                         headers=auth_headers)
    assert response.status_code == 201
    
    # Get client
    response = client.get('/api/clients', headers=auth_headers)
    assert response.status_code == 200
    assert len(response.json) == 1
```

### End-to-End Tests

- Test complete user workflows
- Use real infrastructure when possible
- Test deployment and configuration
- Test monitoring and alerting

```bash
# Example
#!/bin/bash
# test-e2e.sh

echo "Running end-to-end tests..."

# Deploy infrastructure
terraform apply -auto-approve

# Deploy applications
kubectl apply -f k8s/

# Wait for deployment
kubectl wait --for=condition=available --timeout=300s deployment/vpn-api

# Test VPN connectivity
./scripts/test-vpn-connectivity.sh

# Cleanup
terraform destroy -auto-approve
```

## Documentation

### Code Documentation

- Add docstrings to all functions and classes
- Use clear, concise descriptions
- Include parameter and return value descriptions
- Add usage examples

```python
def create_vpn_client(name: str, config: dict = None) -> VPNClient:
    """
    Create a new VPN client with the specified name and configuration.
    
    Args:
        name: The name of the VPN client (must be unique)
        config: Optional configuration dictionary for the client
        
    Returns:
        VPNClient: The created VPN client object
        
    Raises:
        ValueError: If the name is empty or already exists
        
    Example:
        >>> client = create_vpn_client("myclient")
        >>> print(client.name)
        myclient
    """
```

### API Documentation

- Use OpenAPI/Swagger specifications
- Document all endpoints and parameters
- Include request/response examples
- Add authentication requirements

```yaml
# Example
paths:
  /api/clients:
    post:
      summary: Create a new VPN client
      description: Creates a new VPN client with the specified name
      parameters:
        - name: name
          in: body
          required: true
          schema:
            type: string
            example: "myclient"
      responses:
        201:
          description: Client created successfully
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/VPNClient'
```

### README Updates

- Keep README.md up to date
- Include installation instructions
- Add usage examples
- Document configuration options

## Release Process

### Version Numbering

We use [Semantic Versioning](https://semver.org/):
- MAJOR: Incompatible API changes
- MINOR: New functionality (backward compatible)
- PATCH: Bug fixes (backward compatible)

### Release Checklist

- [ ] All tests pass
- [ ] Documentation is updated
- [ ] CHANGELOG.md is updated
- [ ] Version numbers are updated
- [ ] Release notes are written
- [ ] Docker images are built and pushed
- [ ] Helm charts are updated

### Creating a Release

1. **Update version numbers:**
   ```bash
   # Update version in all files
   ./scripts/update-version.sh 1.2.0
   ```

2. **Create release branch:**
   ```bash
   git checkout -b release/1.2.0
   git commit -m "chore: bump version to 1.2.0"
   git push origin release/1.2.0
   ```

3. **Create pull request:**
   - Title: "Release 1.2.0"
   - Description: List of changes
   - Assign reviewers

4. **Merge and tag:**
   ```bash
   git tag v1.2.0
   git push origin v1.2.0
   ```

5. **Create GitHub release:**
   - Use the tag as the release name
   - Copy changelog content
   - Attach release artifacts

## Community Guidelines

### Getting Help

- **Documentation**: Check the docs/ directory first
- **Issues**: Search existing issues before creating new ones
- **Discussions**: Use GitHub Discussions for questions
- **Slack**: Join our community Slack channel

### Reporting Issues

When reporting issues, please include:
- Clear description of the problem
- Steps to reproduce
- Expected vs actual behavior
- Environment details (OS, versions, etc.)
- Logs and error messages

### Feature Requests

When requesting features, please include:
- Clear description of the feature
- Use case and motivation
- Proposed implementation (if you have ideas)
- Any relevant examples or references

### Code Reviews

When reviewing code:
- Be constructive and respectful
- Focus on the code, not the person
- Suggest improvements, don't just criticize
- Approve when you're confident in the changes

## Recognition

Contributors will be recognized in:
- CONTRIBUTORS.md file
- Release notes
- Project documentation
- Community acknowledgments

Thank you for contributing to the VPN DevOps Project! 🚀



