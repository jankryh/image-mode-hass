# Security Vulnerabilities Management Guide

This document provides comprehensive guidance on managing security vulnerabilities in your Home Assistant bootc image.

## 📊 Understanding Security Scans

### What are Container Vulnerabilities?

Container vulnerabilities are security flaws found in:
- **System packages** (dnf/rpm installed)
- **Programming language dependencies** (Python, Go, Node.js libraries)
- **Base operating system components**
- **Container runtime dependencies**

### Common Vulnerability Sources

| Component | Example Vulnerabilities | Impact |
|-----------|------------------------|---------|
| **Python packages** | urllib3, requests | Network security |
| **System libraries** | openssl, glibc | Core security |
| **Go dependencies** | stdlib, third-party modules | Application security |
| **OS packages** | toolbox, systemd | System security |

## 🔍 Identifying Vulnerabilities

### Registry Scanning

Most container registries provide built-in security scanning:

#### Quay.io Security Scanner
- **Automatic scanning** when you push images
- **Severity levels**: Critical, High, Medium, Low, Unknown
- **Patch availability** information
- **CVSS scores** for severity assessment

#### Example Vulnerability Report
```
Advisory: GHSA-fv92-fjc5-jj9h
Severity: Medium
Package: github.com/go-viper/mapstructure/v2
Current: v2.2.1
Fixed in: 2.3.0
Introduced in: toolbox-0.1.2-1.fc42.x86_64
```

### Local Scanning Tools

#### Trivy (Recommended)
```bash
# Install trivy
dnf install trivy

# Scan your image
trivy image quay.io/your-registry/fedora-bootc-hass:latest

# Save report
trivy image --format json -o vulnerability-report.json \
  quay.io/your-registry/fedora-bootc-hass:latest
```

#### Podman/Skopeo Integration
```bash
# Basic vulnerability scan
podman run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image your-image:tag
```

## 🛠️ Fixing Vulnerabilities

### 1. Update Base Packages (Most Effective)

The most common fix is updating system packages to their latest versions:

```dockerfile
# Add this early in your Containerfile
RUN dnf -y upgrade --refresh
```

### 2. Remove Unnecessary Packages

Remove packages that aren't needed for your use case:

```dockerfile
# Remove toolbox if not needed (common source of vulnerabilities)
RUN dnf -y remove toolbox || true

# Remove development tools if not needed
RUN dnf -y remove gcc gcc-c++ make || true

# Remove documentation packages
RUN dnf -y remove *-doc *-devel || true
```

### 3. Target Specific Package Updates

For specific vulnerable packages:

```dockerfile
# Update specific packages
RUN dnf -y upgrade python3-urllib3 golang openssl || true

# Install security updates only
RUN dnf -y upgrade --security
```

### 4. Use Security-Focused Build

Use the security build target:

```bash
# Build with latest packages and no cache
sudo make build-security

# Or with environment override
FORCE_REBUILD=true USE_CACHE=false make build
```

## 🚀 Automated Vulnerability Management

### 1. Makefile Integration

Your Makefile includes security-focused builds:

```makefile
# Security-focused build (no cache, latest packages)
make build-security

# Regular build with cache
make build
```

### 2. CI/CD Pipeline Integration

Add vulnerability scanning to your build pipeline:

```yaml
# Example GitHub Actions
- name: Build Security Image
  run: sudo make build-security

- name: Scan for Vulnerabilities  
  run: |
    trivy image --exit-code 1 --severity HIGH,CRITICAL \
      quay.io/your-registry/fedora-bootc-hass:latest
```

### 3. Scheduled Rebuilds

Set up regular rebuilds to get latest security updates:

```bash
# Weekly security rebuild
0 2 * * 0 cd /path/to/project && make build-security && make push
```

## 📋 Vulnerability Response Workflow

### 1. Assessment Phase
```bash
# Step 1: Identify vulnerabilities
trivy image your-image:latest

# Step 2: Categorize by severity
# Critical/High: Fix immediately
# Medium: Fix within 30 days  
# Low: Fix during next regular update
```

### 2. Remediation Phase
```bash
# Step 1: Security build
sudo make build-security

# Step 2: Test the updated image
sudo make dev-deploy CONFIG_MK=security-test.mk

# Step 3: Scan the new image
trivy image your-image:latest

# Step 4: Deploy if clean
sudo make push
```

### 3. Verification Phase
```bash
# Verify vulnerabilities are fixed
trivy image --severity HIGH,CRITICAL your-image:latest

# Should return: "No vulnerabilities found"
```

## 🔧 Advanced Security Techniques

### 1. Multi-Stage Builds for Minimal Attack Surface

```dockerfile
# Build stage
FROM quay.io/fedora/fedora-bootc:42 as builder
# Install build dependencies
RUN dnf -y install gcc make
# Build your application

# Runtime stage  
FROM quay.io/fedora/fedora-bootc:42
# Copy only runtime artifacts
COPY --from=builder /app/binary /usr/local/bin/
# Minimal runtime packages only
```

### 2. Use Specific Package Versions

Pin specific versions for critical security packages:

```dockerfile
# Pin to specific secure versions
RUN dnf -y install openssl-3.0.7-1.fc42 python3-urllib3-2.5.0-1.fc42
```

### 3. Regular Base Image Updates

Stay current with base image updates:

```dockerfile
# Always pull latest base image
FROM quay.io/fedora/fedora-bootc:42@sha256:latest-digest
```

## 📊 Monitoring and Alerting

### 1. Registry Integration
- **Quay.io**: Enable vulnerability notifications
- **Docker Hub**: Use Docker Scout
- **Harbor**: Configure CVE allowlists

### 2. Webhook Integration
```bash
# Set up Quay.io webhook for vulnerability updates
curl -X POST "https://your-ci-system.com/webhook" \
  -H "Content-Type: application/json" \
  -d '{"image": "updated", "vulnerabilities": "found"}'
```

### 3. Automated Scanning Schedule
```bash
# Daily vulnerability scan
0 6 * * * trivy image your-image:latest | \
  grep -E "(HIGH|CRITICAL)" && \
  echo "Critical vulnerabilities found!" | \
  mail -s "Security Alert" admin@company.com
```

## 🎯 Best Practices Summary

### ✅ Do's
- **Regular Updates**: Update base packages frequently
- **Minimal Images**: Remove unnecessary packages
- **Automated Scanning**: Integrate into CI/CD
- **Version Pinning**: Pin critical package versions
- **Security Builds**: Use `make build-security` for critical updates
- **Documentation**: Track vulnerability fixes

### ❌ Don'ts
- **Ignore Medium/High**: Don't ignore medium+ severity vulnerabilities
- **Skip Testing**: Don't skip testing after security updates
- **Cache Security Builds**: Don't use cache for security-focused builds
- **Old Base Images**: Don't use outdated base images
- **Manual Only**: Don't rely only on manual vulnerability checks

## 🚨 Emergency Response

### Critical Vulnerability (CVSS 9.0+)
```bash
# 1. Immediate security build
sudo make build-security

# 2. Fast-track testing
sudo make dev-deploy

# 3. Emergency deployment
sudo make push

# 4. Verify fix
trivy image --severity CRITICAL your-image:latest
```

### High Vulnerability (CVSS 7.0-8.9)
```bash
# 1. Plan fix within 24-48 hours
# 2. Security build during maintenance window
# 3. Standard testing process
# 4. Scheduled deployment
```

## 📚 Additional Resources

- **[Quay.io Security Scanner Documentation](https://docs.quay.io/guides/vulnerability-scanning.html)**
- **[Trivy Documentation](https://aquasecurity.github.io/trivy/)**
- **[NIST Vulnerability Database](https://nvd.nist.gov/)**
- **[Fedora Security Advisories](https://fedoraproject.org/security/)**
- **[CVE Details](https://www.cvedetails.com/)**

## 🔄 Regular Maintenance

### Weekly Tasks
- Review vulnerability scan reports
- Apply security updates if available
- Test updated images

### Monthly Tasks  
- Rebuild images with latest base packages
- Review and update security policies
- Audit container security configurations

### Quarterly Tasks
- Security architecture review
- Update vulnerability response procedures
- Review and update this documentation

Remember: **Security is a continuous process, not a one-time fix!**