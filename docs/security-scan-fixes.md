# Security Scan Fixes and Troubleshooting

## Issue Summary

The GitHub Actions security vulnerability scan was failing with the error:
```
FATAL Fatal error run error: image scan error: scan error: unable to initialize a scan service: unable to initialize an image scan service: unable to find the specified image "quay.io/jankryh/fedora-bootc-hass:latest"
```

## Root Cause

The security monitoring workflow was trying to scan an image that:
1. Was not built in the current workflow
2. Was not available in the registry
3. Had no proper fallback mechanism

## Fixes Applied

### 1. Improved Image Detection Logic

The security workflow now uses a more robust image detection strategy:

1. **Local Build**: First tries to build the image locally
2. **Registry Pull**: If build fails, tries to pull from registry
3. **Fallback Base**: If registry pull fails, uses base image
4. **Error Handling**: Proper error handling for each step

### 2. Enhanced Registry Connectivity

- Added registry authentication support
- Added connectivity testing
- Multiple methods to check image existence
- Better error messages and debugging

### 3. Improved Error Handling

- Graceful degradation when scans fail
- Better logging and debugging information
- Proper exit codes and status reporting

### 4. Added Debugging Tools

Created `scripts/test-security-scan.sh` for local testing and debugging.

## How to Resolve the Issue

### Option 1: Ensure Image is Built and Pushed

1. **Check CI Workflow**: Ensure the CI workflow successfully builds and pushes the image
2. **Verify Registry**: Check that the image exists in Quay.io
3. **Check Credentials**: Ensure Quay.io credentials are properly configured

### Option 2: Use Local Build in Security Workflow

The security workflow now attempts to build the image locally if it can't find it in the registry.

### Option 3: Use Fallback Base Image

If neither local build nor registry pull works, the workflow will scan the base Fedora BootC image.

## Testing the Fix

### Local Testing

Run the test script to verify security scanning works:

```bash
./scripts/test-security-scan.sh
```

### GitHub Actions Testing

1. Push changes to trigger the security workflow
2. Check the workflow logs for improved debugging information
3. Verify that the scan completes successfully

## Configuration Requirements

### Required Secrets

For registry access, ensure these secrets are configured:
- `QUAY_USERNAME`: Quay.io username
- `QUAY_PASSWORD`: Quay.io password/token

### Environment Variables

The workflow uses these environment variables:
- `REGISTRY`: Registry URL (default: quay.io)
- `IMAGE_NAME`: Image name (default: ${{ github.repository_owner }}/fedora-bootc-hass)

## Troubleshooting Steps

### 1. Check Registry Access

```bash
# Test registry connectivity
curl -s --max-time 10 "https://quay.io/v2/"

# Check if image exists
podman manifest inspect quay.io/jankryh/fedora-bootc-hass:latest
```

### 2. Check Local Build

```bash
# Try building locally
podman build -t test-image:latest .

# Check if build succeeded
podman images | grep test-image
```

### 3. Check Security Tools

```bash
# Verify Trivy installation
trivy --version

# Verify Grype installation
grype --version
```

### 4. Run Security Scan Test

```bash
# Run the test script
./scripts/test-security-scan.sh
```

## Expected Behavior After Fix

1. **Successful Build**: If image builds locally, scan the built image
2. **Registry Pull**: If build fails but image exists in registry, pull and scan
3. **Fallback Scan**: If neither works, scan base image with warning
4. **Proper Reporting**: Clear indication of which scan type was used
5. **Error Handling**: Graceful handling of failures with helpful messages

## Monitoring

After implementing the fixes:

1. **Check Workflow Logs**: Look for improved debugging information
2. **Verify Scan Results**: Ensure scans complete and upload results
3. **Monitor Issues**: Check if security issues are created appropriately
4. **Review Reports**: Verify security summary reports are generated

## Future Improvements

1. **Caching**: Cache built images between workflow runs
2. **Parallel Scans**: Run multiple security tools in parallel
3. **Custom Policies**: Add custom security policies
4. **Integration**: Better integration with GitHub Security tab
5. **Notifications**: Add notifications for critical findings 