# Security Vulnerability Management Guide

This guide helps you identify, monitor, and resolve security vulnerabilities in the Home Assistant bootc image.

## 🚨 Current Status

**Last Scan:** Check GitHub Actions Security tab
**Current Vulnerabilities:** View latest scan results

## ⚡ Quick Start

### 1. Immediate Vulnerability Check
```bash
# Quick security scan
./scripts/security-check.sh quick

# Comprehensive scan with fix suggestions
./scripts/security-check.sh scan --fix-suggestions
```

### 2. Fix Common Vulnerabilities
```bash
# Rebuild with security updates
make build-secure

# Or use manual fixes in Containerfile:
# - Remove vulnerable packages (toolbox, golang)
# - Update base image to latest
# - Apply security patches
```

## 🔍 Understanding Vulnerabilities

### Severity Levels
- **🔴 Critical**: Immediate action required, may lead to system compromise
- **🟠 High**: Important security issue, should be fixed promptly  
- **🟡 Medium**: Moderate security risk, fix when convenient
- **🟢 Low**: Minor security issue, monitor for updates

### Common Vulnerability Sources
1. **Base Image Packages**: Outdated Fedora packages
2. **Go Runtime**: Vulnerable Go stdlib versions
3. **Container Tools**: Toolbox, Podman, Buildah packages
4. **Third-party Dependencies**: Application-specific libraries

## 🛠️ Resolution Strategies

### 1. Update Base Image
Always use the latest Fedora bootc base image:

```dockerfile
# ✅ Good - Latest stable
FROM quay.io/fedora/fedora-bootc:42

# ❌ Avoid - Older versions
FROM quay.io/fedora/fedora-bootc:41
```

### 2. Remove Vulnerable Packages
Aggressively remove unnecessary packages:

```dockerfile
# Remove vulnerable development and container tools
RUN dnf -y remove toolbox* container-tools* golang* buildah* skopeo* \
    go-toolset* golang-*mapstructure* golang-github* && \
    dnf -y autoremove
```

### 3. Apply Security Updates
Force security patches:

```dockerfile
# Security-focused updates
RUN dnf makecache --refresh && \
    dnf -y upgrade --security && \
    dnf -y install-updates --security && \
    dnf clean all
```

### 4. Minimize Attack Surface
```dockerfile
# Remove unnecessary files and documentation
RUN dnf -y remove *-doc *-devel && \
    rm -rf /usr/share/doc/* /usr/share/man/* /tmp/* /var/tmp/*
```

## 🔄 Automated Monitoring

### GitHub Actions Integration
The project includes automated security scanning:

- **Daily Scans**: Runs every day at 2 AM UTC
- **PR Scans**: On every pull request
- **Manual Triggers**: Via GitHub Actions web interface

### Local Monitoring
Set up continuous monitoring on your development machine:

```bash
# Set up automated daily scans
./scripts/security-check.sh monitor

# Add to crontab (runs daily at 2 AM)
echo "0 2 * * * $PWD/scripts/security-check.sh quick" | crontab -
```

### Real-time Alerts
Configure notifications for critical vulnerabilities:

```bash
# Install notification tools
dnf install -y mailx  # For email alerts
dnf install -y libnotify-tools  # For desktop notifications

# Create alert script
cat > ~/.local/bin/security-alert << 'EOF'
#!/bin/bash
if ./scripts/security-check.sh quick | grep -q "CRITICAL"; then
    notify-send "Security Alert" "Critical vulnerabilities found in bootc image"
    # Optional: send email
    # echo "Critical vulnerabilities detected" | mail -s "Security Alert" admin@example.com
fi
EOF
chmod +x ~/.local/bin/security-alert
```

## 📊 Available Tools

### Scripts
- `./scripts/security-check.sh` - Main security scanning tool
- `make security-scan` - Quick Makefile target
- `make build-secure` - Build with security optimizations

### GitHub Actions Workflows
- `.github/workflows/security-monitoring.yml` - Automated scanning
- `.github/workflows/security.yml` - Security-focused CI
- `.github/workflows/ci.yml` - Includes security scanning

### External Tools Integration
- **Trivy**: Comprehensive vulnerability scanner
- **Grype**: Anchore vulnerability scanner  
- **GitHub Security Tab**: Centralized vulnerability management
- **Dependabot**: Automated dependency updates

## 🎯 Best Practices

### 1. Proactive Security
- **Scan Early**: Run security scans during development
- **Update Regularly**: Keep base images and dependencies current
- **Monitor Continuously**: Set up automated scanning
- **Review Dependencies**: Regularly audit included packages

### 2. Vulnerability Response
- **Prioritize Critical**: Address critical vulnerabilities immediately
- **Batch Updates**: Group non-critical updates for efficiency
- **Test Changes**: Verify fixes don't break functionality
- **Document Actions**: Keep track of security improvements

### 3. Security-First Development
- **Minimal Images**: Include only necessary packages
- **Latest Base Images**: Always use current versions
- **Security Updates**: Apply patches promptly
- **Regular Audits**: Schedule periodic security reviews

## 🚀 Quick Fix Checklist

When vulnerabilities are detected:

- [ ] **Immediate Assessment**
  - [ ] Check severity levels (Critical/High first)
  - [ ] Identify affected packages
  - [ ] Assess exploitation risk

- [ ] **Apply Fixes**
  - [ ] Update base image version
  - [ ] Remove vulnerable packages
  - [ ] Apply security patches
  - [ ] Rebuild and test image

- [ ] **Verify Resolution**
  - [ ] Run security scan on new image
  - [ ] Confirm vulnerabilities resolved
  - [ ] Test functionality still works
  - [ ] Update documentation

- [ ] **Deploy and Monitor**
  - [ ] Deploy fixed image
  - [ ] Monitor for new vulnerabilities
  - [ ] Set up alerts for future issues
  - [ ] Schedule regular reviews

## 📞 Getting Help

### Resources
- **GitHub Security Tab**: View detailed vulnerability reports
- **Trivy Documentation**: https://aquasecurity.github.io/trivy/
- **Fedora Security**: https://fedoraproject.org/security/
- **CVE Database**: https://cve.mitre.org/

### Community Support
- **GitHub Issues**: Report security concerns
- **Fedora Community**: Security-focused discussions
- **Home Assistant Community**: Platform-specific guidance

### Emergency Response
For critical security issues:
1. **Stop**: Halt deployment of vulnerable images
2. **Assess**: Determine scope and impact  
3. **Fix**: Apply patches or workarounds
4. **Test**: Verify fix resolves issue
5. **Deploy**: Roll out secure version
6. **Monitor**: Watch for new issues

---

**Remember**: Security is an ongoing process, not a one-time task. Regular monitoring and proactive updates are key to maintaining a secure Home Assistant deployment.