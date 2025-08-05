#!/bin/bash
# Advanced Secrets and Configuration Management System
# Secure handling of passwords, API keys, certificates, and environment-specific configurations

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SECRETS_DIR="/etc/hass-secrets"
CONFIG_DIR="/opt/hass-config"
VAULT_FILE="$SECRETS_DIR/vault.encrypted"
KEYFILE="$SECRETS_DIR/.keyfile"
ENV_CONFIG_DIR="$CONFIG_DIR/environments"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
log() { echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"; }
error() { echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"; }
debug() { [[ "${VERBOSE:-}" == "true" ]] && echo -e "${PURPLE}[DEBUG]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"; }

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root for proper secrets management"
        exit 1
    fi
}

# Initialize secrets management structure
init_secrets_structure() {
    log "Initializing secrets management structure..."
    
    # Create directories with proper permissions
    mkdir -p "$SECRETS_DIR" "$CONFIG_DIR" "$ENV_CONFIG_DIR"
    chmod 700 "$SECRETS_DIR"
    chmod 755 "$CONFIG_DIR" "$ENV_CONFIG_DIR"
    
    # Create environment-specific directories
    local environments=("development" "staging" "production")
    for env in "${environments[@]}"; do
        mkdir -p "$ENV_CONFIG_DIR/$env"
        chmod 755 "$ENV_CONFIG_DIR/$env"
    done
    
    log "Secrets structure initialized"
}

# Generate encryption key
generate_key() {
    log "Generating encryption key..."
    
    if [[ -f "$KEYFILE" ]]; then
        warn "Encryption key already exists"
        return 0
    fi
    
    # Generate random key
    openssl rand -base64 32 > "$KEYFILE"
    chmod 600 "$KEYFILE"
    
    log "Encryption key generated and secured"
}

# Encrypt secret value
encrypt_secret() {
    local value="$1"
    local key_file="${2:-$KEYFILE}"
    
    if [[ ! -f "$key_file" ]]; then
        error "Encryption key not found: $key_file"
        return 1
    fi
    
    echo -n "$value" | openssl enc -aes-256-cbc -a -salt -pass file:"$key_file"
}

# Decrypt secret value
decrypt_secret() {
    local encrypted_value="$1"
    local key_file="${2:-$KEYFILE}"
    
    if [[ ! -f "$key_file" ]]; then
        error "Encryption key not found: $key_file"
        return 1
    fi
    
    echo -n "$encrypted_value" | openssl enc -aes-256-cbc -d -a -salt -pass file:"$key_file"
}

# Store secret in vault
store_secret() {
    local secret_name="$1"
    local secret_value="$2"
    local environment="${3:-default}"
    
    debug "Storing secret: $secret_name for environment: $environment"
    
    # Initialize vault if it doesn't exist
    if [[ ! -f "$VAULT_FILE" ]]; then
        echo '{}' > "$VAULT_FILE"
        chmod 600 "$VAULT_FILE"
    fi
    
    # Encrypt the secret value
    local encrypted_value
    encrypted_value=$(encrypt_secret "$secret_value")
    
    # Create temporary vault for update
    local temp_vault
    temp_vault=$(mktemp)
    chmod 600 "$temp_vault"
    
    # Decrypt current vault, update, and re-encrypt
    if [[ -s "$VAULT_FILE" ]]; then
        local current_vault
        current_vault=$(decrypt_vault_content)
    else
        current_vault='{}'
    fi
    
    # Update vault with new secret
    echo "$current_vault" | jq --arg env "$environment" --arg name "$secret_name" --arg value "$encrypted_value" \
        '.[$env] //= {} | .[$env][$name] = {
            "value": $value,
            "created": now | todate,
            "type": "encrypted"
        }' > "$temp_vault"
    
    # Encrypt updated vault
    encrypt_vault_content < "$temp_vault" > "$VAULT_FILE"
    rm "$temp_vault"
    
    log "Secret '$secret_name' stored for environment '$environment'"
}

# Retrieve secret from vault
get_secret() {
    local secret_name="$1"
    local environment="${2:-default}"
    
    debug "Retrieving secret: $secret_name from environment: $environment"
    
    if [[ ! -f "$VAULT_FILE" ]]; then
        error "Vault file not found"
        return 1
    fi
    
    local vault_content
    vault_content=$(decrypt_vault_content)
    
    local encrypted_value
    encrypted_value=$(echo "$vault_content" | jq -r --arg env "$environment" --arg name "$secret_name" '.[$env][$name].value // empty')
    
    if [[ -z "$encrypted_value" || "$encrypted_value" == "null" ]]; then
        error "Secret '$secret_name' not found in environment '$environment'"
        return 1
    fi
    
    decrypt_secret "$encrypted_value"
}

# Encrypt entire vault content
encrypt_vault_content() {
    openssl enc -aes-256-cbc -a -salt -pass file:"$KEYFILE"
}

# Decrypt entire vault content
decrypt_vault_content() {
    if [[ ! -s "$VAULT_FILE" ]]; then
        echo '{}'
        return 0
    fi
    
    openssl enc -aes-256-cbc -d -a -salt -pass file:"$KEYFILE" < "$VAULT_FILE"
}

# List all secrets
list_secrets() {
    local environment="${1:-}"
    
    info "Listing secrets..."
    
    if [[ ! -f "$VAULT_FILE" ]]; then
        warn "No vault file found"
        return 0
    fi
    
    local vault_content
    vault_content=$(decrypt_vault_content)
    
    if [[ -n "$environment" ]]; then
        echo "$vault_content" | jq -r --arg env "$environment" \
            '.[$env] // {} | to_entries[] | "\(.key)\t\(.value.created)\t\(.value.type)"' | \
            column -t -s $'\t' -N "SECRET,CREATED,TYPE"
    else
        echo "$vault_content" | jq -r \
            'to_entries[] as {key: $env, value: $secrets} | 
             $secrets | to_entries[] | 
             "\($env)\t\(.key)\t\(.value.created)\t\(.value.type)"' | \
            column -t -s $'\t' -N "ENVIRONMENT,SECRET,CREATED,TYPE"
    fi
}

# Delete secret
delete_secret() {
    local secret_name="$1"
    local environment="${2:-default}"
    
    warn "Deleting secret: $secret_name from environment: $environment"
    
    if [[ ! -f "$VAULT_FILE" ]]; then
        error "Vault file not found"
        return 1
    fi
    
    local temp_vault
    temp_vault=$(mktemp)
    chmod 600 "$temp_vault"
    
    local current_vault
    current_vault=$(decrypt_vault_content)
    
    # Remove secret from vault
    echo "$current_vault" | jq --arg env "$environment" --arg name "$secret_name" \
        'del(.[$env][$name])' > "$temp_vault"
    
    # Encrypt updated vault
    encrypt_vault_content < "$temp_vault" > "$VAULT_FILE"
    rm "$temp_vault"
    
    log "Secret '$secret_name' deleted from environment '$environment'"
}

# Generate configuration templates
generate_config_templates() {
    log "Generating configuration templates..."
    
    # Development environment template
    cat > "$ENV_CONFIG_DIR/development/config.yaml" << 'EOF'
# Development Environment Configuration
environment: development
debug: true
log_level: DEBUG

database:
  host: localhost
  port: 5432
  name: hass_dev
  ssl_mode: disable

home_assistant:
  base_url: http://localhost:8123
  webhook_url: http://localhost:8123/api/webhook/
  
external_services:
  weather_api:
    enabled: false
    rate_limit: 1000
  
security:
  session_timeout: 7200
  csrf_protection: false
  
backup:
  enabled: true
  interval: "0 2 * * *"
  retention_days: 7
EOF

    # Production environment template
    cat > "$ENV_CONFIG_DIR/production/config.yaml" << 'EOF'
# Production Environment Configuration
environment: production
debug: false
log_level: INFO

database:
  host: "${DB_HOST}"
  port: "${DB_PORT}"
  name: "${DB_NAME}"
  ssl_mode: require

home_assistant:
  base_url: "${HA_BASE_URL}"
  webhook_url: "${HA_WEBHOOK_URL}"
  
external_services:
  weather_api:
    enabled: true
    rate_limit: 10000
  
security:
  session_timeout: 3600
  csrf_protection: true
  
backup:
  enabled: true
  interval: "0 2 * * *"
  retention_days: 30
  remote_backup: true
EOF

    # Staging environment template
    cat > "$ENV_CONFIG_DIR/staging/config.yaml" << 'EOF'
# Staging Environment Configuration
environment: staging
debug: false
log_level: INFO

database:
  host: "${DB_HOST}"
  port: "${DB_PORT}"
  name: "${DB_NAME}"
  ssl_mode: require

home_assistant:
  base_url: "${HA_BASE_URL}"
  webhook_url: "${HA_WEBHOOK_URL}"
  
external_services:
  weather_api:
    enabled: true
    rate_limit: 5000
  
security:
  session_timeout: 3600
  csrf_protection: true
  
backup:
  enabled: true
  interval: "0 3 * * *"
  retention_days: 14
EOF

    log "Configuration templates generated"
}

# Process configuration with secrets injection
process_config() {
    local environment="$1"
    local input_file="$2"
    local output_file="$3"
    
    debug "Processing configuration for environment: $environment"
    
    # Read configuration template
    local config_content
    config_content=$(cat "$input_file")
    
    # Replace environment variables with secrets
    while IFS= read -r line; do
        if [[ "$line" =~ \$\{([^}]+)\} ]]; then
            local var_name="${BASH_REMATCH[1]}"
            local secret_value
            
            # Try to get value from secrets vault first
            if secret_value=$(get_secret "$var_name" "$environment" 2>/dev/null); then
                config_content=$(echo "$config_content" | sed "s/\${$var_name}/$secret_value/g")
                debug "Replaced $var_name with value from secrets vault"
            elif [[ -n "${!var_name:-}" ]]; then
                # Fallback to environment variable
                config_content=$(echo "$config_content" | sed "s/\${$var_name}/${!var_name}/g")
                debug "Replaced $var_name with environment variable"
            else
                warn "No value found for variable: $var_name"
            fi
        fi
    done <<< "$config_content"
    
    # Write processed configuration
    echo "$config_content" > "$output_file"
    chmod 644 "$output_file"
    
    log "Configuration processed and written to: $output_file"
}

# Setup secrets for specific environment
setup_environment_secrets() {
    local environment="$1"
    
    info "Setting up secrets for environment: $environment"
    
    case "$environment" in
        "development")
            store_secret "DB_HOST" "localhost" "$environment"
            store_secret "DB_PORT" "5432" "$environment"
            store_secret "DB_NAME" "hass_dev" "$environment"
            store_secret "HA_BASE_URL" "http://localhost:8123" "$environment"
            store_secret "HA_WEBHOOK_URL" "http://localhost:8123/api/webhook/" "$environment"
            ;;
        "staging")
            echo "Enter staging database host:"
            read -r db_host
            echo "Enter staging database password:"
            read -rs db_password
            echo "Enter staging Home Assistant URL:"
            read -r ha_url
            
            store_secret "DB_HOST" "$db_host" "$environment"
            store_secret "DB_PASSWORD" "$db_password" "$environment"
            store_secret "HA_BASE_URL" "$ha_url" "$environment"
            store_secret "HA_WEBHOOK_URL" "$ha_url/api/webhook/" "$environment"
            ;;
        "production")
            echo "Enter production database host:"
            read -r db_host
            echo "Enter production database password:"
            read -rs db_password
            echo "Enter production Home Assistant URL:"
            read -r ha_url
            echo "Enter ZeroTier network ID:"
            read -r zerotier_id
            
            store_secret "DB_HOST" "$db_host" "$environment"
            store_secret "DB_PASSWORD" "$db_password" "$environment"
            store_secret "HA_BASE_URL" "$ha_url" "$environment"
            store_secret "HA_WEBHOOK_URL" "$ha_url/api/webhook/" "$environment"
            store_secret "ZEROTIER_NETWORK_ID" "$zerotier_id" "$environment"
            ;;
    esac
    
    log "Secrets setup completed for environment: $environment"
}

# Backup secrets vault
backup_vault() {
    local backup_dir="${1:-/var/home-assistant/backups}"
    
    log "Backing up secrets vault..."
    
    mkdir -p "$backup_dir"
    local backup_file="$backup_dir/secrets_backup_$(date '+%Y%m%d_%H%M%S').tar.gz"
    
    tar -czf "$backup_file" -C "$(dirname "$SECRETS_DIR")" "$(basename "$SECRETS_DIR")"
    chmod 600 "$backup_file"
    
    log "Secrets vault backed up to: $backup_file"
}

# Restore secrets vault
restore_vault() {
    local backup_file="$1"
    
    warn "Restoring secrets vault from: $backup_file"
    
    if [[ ! -f "$backup_file" ]]; then
        error "Backup file not found: $backup_file"
        return 1
    fi
    
    # Create backup of current vault
    if [[ -d "$SECRETS_DIR" ]]; then
        local current_backup
        current_backup="/tmp/secrets_current_$(date '+%Y%m%d_%H%M%S').tar.gz"
        tar -czf "$current_backup" -C "$(dirname "$SECRETS_DIR")" "$(basename "$SECRETS_DIR")"
        warn "Current vault backed up to: $current_backup"
    fi
    
    # Restore from backup
    tar -xzf "$backup_file" -C "$(dirname "$SECRETS_DIR")"
    
    log "Secrets vault restored successfully"
}

# Main execution
main() {
    echo "=============================================="
    echo "    Advanced Secrets Management System"
    echo "=============================================="
    echo ""
    
    # Parse command line arguments
    local command="${1:-help}"
    shift || true
    
    case "$command" in
        "init")
            check_root
            init_secrets_structure
            generate_key
            generate_config_templates
            ;;
        "store")
            check_root
            if [[ $# -lt 2 ]]; then
                error "Usage: $0 store <secret_name> <secret_value> [environment]"
                exit 1
            fi
            store_secret "$1" "$2" "${3:-default}"
            ;;
        "get")
            check_root
            if [[ $# -lt 1 ]]; then
                error "Usage: $0 get <secret_name> [environment]"
                exit 1
            fi
            get_secret "$1" "${2:-default}"
            ;;
        "list")
            check_root
            list_secrets "${1:-}"
            ;;
        "delete")
            check_root
            if [[ $# -lt 1 ]]; then
                error "Usage: $0 delete <secret_name> [environment]"
                exit 1
            fi
            delete_secret "$1" "${2:-default}"
            ;;
        "setup-env")
            check_root
            if [[ $# -lt 1 ]]; then
                error "Usage: $0 setup-env <environment>"
                exit 1
            fi
            setup_environment_secrets "$1"
            ;;
        "process-config")
            check_root
            if [[ $# -lt 3 ]]; then
                error "Usage: $0 process-config <environment> <input_file> <output_file>"
                exit 1
            fi
            process_config "$1" "$2" "$3"
            ;;
        "backup")
            check_root
            backup_vault "${1:-}"
            ;;
        "restore")
            check_root
            if [[ $# -lt 1 ]]; then
                error "Usage: $0 restore <backup_file>"
                exit 1
            fi
            restore_vault "$1"
            ;;
        "help"|*)
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  init                           Initialize secrets management"
            echo "  store <name> <value> [env]     Store a secret"
            echo "  get <name> [env]               Retrieve a secret"
            echo "  list [env]                     List all secrets"
            echo "  delete <name> [env]            Delete a secret"
            echo "  setup-env <environment>        Interactive environment setup"
            echo "  process-config <env> <in> <out> Process configuration with secrets"
            echo "  backup [dir]                   Backup secrets vault"
            echo "  restore <file>                 Restore secrets vault"
            echo ""
            echo "Environments: development, staging, production, default"
            ;;
    esac
}

# Check if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi