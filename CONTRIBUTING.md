# Contributing to Home Assistant bootc

Thank you for your interest in contributing to the Home Assistant bootc project! This document provides guidelines for contributing to the project.

## 🤝 How to Contribute

### Reporting Issues

1. **Search existing issues** first to avoid duplicates
2. **Use issue templates** when available
3. **Provide detailed information** including:
   - OS version and architecture
   - bootc version
   - Home Assistant version
   - Steps to reproduce the issue
   - Expected vs actual behavior
   - Relevant logs

### Suggesting Enhancements

1. **Check existing feature requests** to avoid duplicates
2. **Clearly describe the enhancement** with use cases
3. **Explain why this would be useful** to the community
4. **Consider implementation complexity** and breaking changes

### Pull Requests

1. **Fork the repository** and create a feature branch
2. **Follow the coding standards** outlined below
3. **Test your changes** thoroughly
4. **Update documentation** if needed
5. **Write clear commit messages**
6. **Submit a pull request** with a detailed description

## 📝 Development Guidelines

### Coding Standards

#### Shell Scripts
- Use `#!/bin/bash` shebang
- Follow Google Shell Style Guide
- Use `set -euo pipefail` for error handling
- Add comments for complex logic
- Use consistent indentation (4 spaces)
- Validate scripts with `shellcheck`

#### Containerfile/Dockerfile
- Use official base images
- Minimize layers
- Clean up package caches
- Use specific package versions when possible
- Add appropriate labels

#### Documentation
- Use clear, concise language
- Include code examples
- Update table of contents
- Test all commands
- Use proper markdown formatting

### Testing

Before submitting a PR, ensure:
- [ ] Scripts pass `shellcheck` validation
- [ ] Container builds successfully
- [ ] VM deployment works
- [ ] ISO creation completes
- [ ] All automation scripts function correctly
- [ ] Documentation is accurate

### Commit Messages

Use conventional commits format:
```
type(scope): description

[optional body]

[optional footer]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

Examples:
```
feat(scripts): add automatic SSL certificate renewal
fix(container): resolve permission issues for USB devices
docs(readme): update deployment instructions
```

## 🏗️ Development Setup

### Prerequisites
- Linux system (Fedora/RHEL recommended)
- Podman or Docker
- Git
- Make
- ShellCheck (for script validation)

### Local Development
```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/home-assistant-bootc.git
cd home-assistant-bootc

# Create development configuration
cp config-example.json config-dev.json
# Edit config-dev.json with your settings

# Build development image
make dev-build

# Test deployment
make dev-qcow2
make dev-deploy
```

### Testing Changes
```bash
# Validate shell scripts
find scripts/ -name "*.sh" -exec shellcheck {} \;

# Test container build
make build

# Test all image formats
make all

# Run health checks
sudo /opt/hass-scripts/health-check.sh --verbose
```

## 📋 Pull Request Checklist

Before submitting:
- [ ] Code follows project conventions
- [ ] Tests pass locally
- [ ] Documentation updated
- [ ] CHANGELOG.md updated (if applicable)
- [ ] No merge conflicts
- [ ] Clear commit messages
- [ ] PR description explains changes

## 🐛 Bug Report Template

When reporting bugs, please include:

```markdown
**Environment:**
- OS: [e.g., Fedora 42]
- Architecture: [e.g., x86_64]
- bootc version: [e.g., 1.0.0]
- Home Assistant version: [e.g., 2024.1.0]

**Steps to Reproduce:**
1. Step one
2. Step two
3. ...

**Expected Behavior:**
[What you expected to happen]

**Actual Behavior:**
[What actually happened]

**Logs:**
```
[Paste relevant logs here]
```

**Additional Context:**
[Any other relevant information]
```

## 💡 Feature Request Template

```markdown
**Is your feature request related to a problem?**
[Clear description of the problem]

**Describe the solution you'd like**
[Clear description of what you want to happen]

**Describe alternatives you've considered**
[Other solutions you've considered]

**Additional context**
[Screenshots, mockups, or other relevant information]

**Implementation notes**
[Technical considerations, if any]
```

## 📞 Getting Help

- **Documentation**: Check README.md and other docs first
- **Issues**: Search existing issues for answers
- **Discussions**: Use GitHub Discussions for questions
- **Security**: Report security issues privately via email

## 🎯 Areas for Contribution

We especially welcome contributions in these areas:
- **Security improvements**: Hardening configurations, vulnerability fixes
- **Documentation**: User guides, troubleshooting, translations
- **Testing**: Automated tests, platform compatibility
- **Features**: New deployment options, integrations
- **Performance**: Optimization, resource usage improvements

## 📜 Code of Conduct

- Be respectful and inclusive
- Help others learn and grow
- Focus on constructive feedback
- Respect different perspectives
- Follow project maintainer decisions

Thank you for contributing to making Home Assistant deployment easier and more secure! 🚀