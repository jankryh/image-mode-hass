#!/bin/bash

# Home Assistant Podman Deployment Script
# This script provides easy management of the Home Assistant container using Podman and systemd

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PROJECT_DIR}/.env"
CONTAINER_NAME="home-assistant"
IMAGE_NAME="localhost/home-assistant:latest"

# Default values
ACTION=""
FORCE_REBUILD=false
CLEAN_BUILD=false

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    cat << EOF
Home Assistant Podman Deployment Script

Usage: $0 [OPTIONS] ACTION

Actions:
    build       Build the container image
    start       Start the container service
    stop        Stop the container service
    restart     Restart the container service
    status      Show container and service status
    logs        Show container logs
    shell       Access container shell
    backup      Create backup
    restore     Restore from backup
    update      Update container
    clean       Clean up resources
    health      Run health check
    setup       Initial setup
    enable      Enable systemd service
    disable     Disable systemd service

Options:
    -f, --force     Force rebuild
    -c, --clean     Clean build (remove cache)
    -e, --env       Environment file path
    -h, --help      Show this help

Examples:
    $0 build
    $0 start
    $0 logs
    $0 shell
    $0 backup
    $0 -f build

EOF
}

check_dependencies() {
    local deps=("podman" "systemctl")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "$dep is required but not installed"
            exit 1
        fi
    done
}

load_env() {
    if [[ -f "$ENV_FILE" ]]; then
        log_info "Loading environment from $ENV_FILE"
        export $(grep -v '^#' "$ENV_FILE" | xargs)
    else
        log_warning "Environment file $ENV_FILE not found, using defaults"
    fi
}

create_directories() {
    local dirs=(
        "/var/home-assistant/config"
        "/var/home-assistant/backups"
        "/var/home-assistant/secrets"
        "/var/log/home-assistant"
    )
    
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            log_info "Creating directory: $dir"
            sudo mkdir -p "$dir"
        fi
    done
    
    # Set proper ownership
    sudo chown -R 1000:1000 /var/home-assistant
    sudo chown -R 1000:1000 /var/log/home-assistant
}

build_image() {
    log_info "Building Home Assistant container image..."
    
    local build_cmd="podman build -t $IMAGE_NAME"
    
    if [[ "$FORCE_REBUILD" == true ]]; then
        build_cmd="$build_cmd --no-cache"
    fi
    
    if [[ "$CLEAN_BUILD" == true ]]; then
        log_info "Cleaning Podman cache..."
        podman system prune -f
    fi
    
    eval "$build_cmd ."
    log_success "Image build completed"
}

start_container() {
    log_info "Starting Home Assistant container service..."
    
    # Enable and start the systemd service
    sudo systemctl enable home-assistant
    sudo systemctl start home-assistant
    
    log_success "Container service started"
    
    # Wait for container to be ready
    log_info "Waiting for container to be ready..."
    sleep 10
    
    # Check health
    if systemctl is-active --quiet home-assistant; then
        log_success "Container service is active"
    else
        log_warning "Container service may not be fully ready yet"
    fi
}

stop_container() {
    log_info "Stopping Home Assistant container service..."
    sudo systemctl stop home-assistant
    log_success "Container service stopped"
}

restart_container() {
    log_info "Restarting Home Assistant container service..."
    sudo systemctl restart home-assistant
    log_success "Container service restarted"
}

show_status() {
    log_info "Container and service status:"
    echo "=== Systemd Service Status ==="
    systemctl status home-assistant --no-pager -l
    echo ""
    echo "=== Podman Container Status ==="
    podman ps -a --filter name=$CONTAINER_NAME
    echo ""
    echo "=== Container Health ==="
    podman healthcheck run $CONTAINER_NAME 2>/dev/null || echo "Health check not available"
}

show_logs() {
    log_info "Container logs:"
    journalctl -u home-assistant -f
}

access_shell() {
    log_info "Accessing container shell..."
    podman exec -it $CONTAINER_NAME /bin/bash
}

create_backup() {
    local backup_dir="/var/home-assistant/backups"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${backup_dir}/hass_backup_${timestamp}.tar.gz"
    
    log_info "Creating backup: $backup_file"
    
    # Create backup using container
    podman exec $CONTAINER_NAME tar -czf - -C /var/home-assistant config secrets > "$backup_file"
    
    if [[ $? -eq 0 ]]; then
        log_success "Backup created: $backup_file"
        
        # Clean old backups
        local retention_days="${BACKUP_RETENTION_DAYS:-7}"
        find "$backup_dir" -name "hass_backup_*.tar.gz" -mtime +$retention_days -delete
        log_info "Cleaned backups older than $retention_days days"
    else
        log_error "Backup failed"
        exit 1
    fi
}

restore_backup() {
    if [[ $# -eq 0 ]]; then
        log_error "Please specify backup file to restore"
        exit 1
    fi
    
    local backup_file="$1"
    
    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        exit 1
    fi
    
    log_warning "This will overwrite current configuration. Continue? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log_info "Restore cancelled"
        exit 0
    fi
    
    log_info "Restoring from backup: $backup_file"
    
    # Stop container
    stop_container
    
    # Restore backup
    tar -xzf "$backup_file" -C /var/home-assistant
    
    # Fix permissions
    sudo chown -R 1000:1000 /var/home-assistant
    
    # Start container
    start_container
    
    log_success "Backup restored"
}

update_container() {
    log_info "Updating Home Assistant container..."
    
    # Pull latest changes
    git pull origin main
    
    # Rebuild and restart
    build_image
    restart_container
    
    log_success "Container updated"
}

clean_resources() {
    log_info "Cleaning up resources..."
    
    # Stop and remove containers
    podman stop $CONTAINER_NAME 2>/dev/null || true
    podman rm $CONTAINER_NAME 2>/dev/null || true
    
    # Remove unused images
    podman image prune -f
    
    # Remove unused volumes
    podman volume prune -f
    
    # Remove unused networks
    podman network prune -f
    
    log_success "Cleanup completed"
}

run_health_check() {
    log_info "Running health check..."
    
    if podman exec $CONTAINER_NAME /usr/local/bin/health-check.sh; then
        log_success "Health check passed"
    else
        log_error "Health check failed"
        exit 1
    fi
}

enable_service() {
    log_info "Enabling Home Assistant systemd service..."
    sudo systemctl enable home-assistant
    log_success "Service enabled"
}

disable_service() {
    log_info "Disabling Home Assistant systemd service..."
    sudo systemctl disable home-assistant
    log_success "Service disabled"
}

initial_setup() {
    log_info "Running initial setup..."
    
    # Check dependencies
    check_dependencies
    
    # Load environment
    load_env
    
    # Create directories
    create_directories
    
    # Build image
    build_image
    
    # Enable and start service
    enable_service
    start_container
    
    log_success "Initial setup completed"
    log_info "Home Assistant should be available at: http://localhost:8123"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE_REBUILD=true
            shift
            ;;
        -c|--clean)
            CLEAN_BUILD=true
            shift
            ;;
        -e|--env)
            ENV_FILE="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        build|start|stop|restart|status|logs|shell|backup|restore|update|clean|health|setup|enable|disable)
            ACTION="$1"
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Check if action is provided
if [[ -z "$ACTION" ]]; then
    log_error "No action specified"
    show_help
    exit 1
fi

# Main execution
case "$ACTION" in
    build)
        load_env
        build_image
        ;;
    start)
        load_env
        create_directories
        start_container
        ;;
    stop)
        stop_container
        ;;
    restart)
        restart_container
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    shell)
        access_shell
        ;;
    backup)
        load_env
        create_backup
        ;;
    restore)
        load_env
        restore_backup "$@"
        ;;
    update)
        update_container
        ;;
    clean)
        clean_resources
        ;;
    health)
        run_health_check
        ;;
    enable)
        enable_service
        ;;
    disable)
        disable_service
        ;;
    setup)
        initial_setup
        ;;
    *)
        log_error "Unknown action: $ACTION"
        show_help
        exit 1
        ;;
esac
