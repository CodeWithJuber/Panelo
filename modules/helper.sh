#!/bin/bash

# Helper functions for server panel installation modules

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")
            echo -e "${BLUE}[$timestamp] INFO: $message${NC}" | tee -a /var/log/server-panel/install.log
            ;;
        "SUCCESS")
            echo -e "${GREEN}[$timestamp] SUCCESS: $message${NC}" | tee -a /var/log/server-panel/install.log
            ;;
        "WARNING")
            echo -e "${YELLOW}[$timestamp] WARNING: $message${NC}" | tee -a /var/log/server-panel/install.log
            ;;
        "ERROR")
            echo -e "${RED}[$timestamp] ERROR: $message${NC}" | tee -a /var/log/server-panel/install.log
            ;;
        *)
            echo -e "[$timestamp] $level: $message" | tee -a /var/log/server-panel/install.log
            ;;
    esac
}

# Check if service is running
is_service_running() {
    local service_name="$1"
    systemctl is-active --quiet "$service_name"
}

# Wait for service to be ready
wait_for_service() {
    local service_name="$1"
    local max_attempts="${2:-30}"
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if is_service_running "$service_name"; then
            log "SUCCESS" "$service_name is running"
            return 0
        fi
        
        log "INFO" "Waiting for $service_name to start (attempt $attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done
    
    log "ERROR" "$service_name failed to start after $max_attempts attempts"
    return 1
}

# Check if port is available
is_port_available() {
    local port="$1"
    ! ss -tuln | grep -q ":$port "
}

# Generate random password
generate_password() {
    local length="${1:-16}"
    openssl rand -base64 "$length" | tr -d "=+/" | cut -c1-"$length"
}

# Create system user
create_system_user() {
    local username="$1"
    local home_dir="$2"
    
    if ! id "$username" &>/dev/null; then
        useradd -r -s /bin/false -d "$home_dir" "$username"
        log "SUCCESS" "Created system user: $username"
    else
        log "INFO" "System user $username already exists"
    fi
}

# Download file with retry
download_file() {
    local url="$1"
    local output="$2"
    local max_attempts="${3:-3}"
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -fsSL -o "$output" "$url"; then
            log "SUCCESS" "Downloaded $url to $output"
            return 0
        fi
        
        log "WARNING" "Download attempt $attempt failed for $url"
        ((attempt++))
        sleep 2
    done
    
    log "ERROR" "Failed to download $url after $max_attempts attempts"
    return 1
}

# Check if Docker is installed and running
check_docker() {
    if ! command -v docker &>/dev/null; then
        log "ERROR" "Docker is not installed"
        return 1
    fi
    
    if ! systemctl is-active --quiet docker; then
        log "ERROR" "Docker is not running"
        return 1
    fi
    
    return 0
}

# Create Docker network if it doesn't exist
ensure_docker_network() {
    local network_name="$1"
    
    if ! docker network ls | grep -q "$network_name"; then
        docker network create "$network_name"
        log "SUCCESS" "Created Docker network: $network_name"
    else
        log "INFO" "Docker network $network_name already exists"
    fi
}

# Get system information
get_system_info() {
    local info_type="$1"
    
    case "$info_type" in
        "os")
            if [[ -f /etc/os-release ]]; then
                source /etc/os-release
                echo "$ID"
            else
                echo "unknown"
            fi
            ;;
        "arch")
            uname -m
            ;;
        "memory")
            free -m | awk 'NR==2{printf "%.0f", $2/1024}'
            ;;
        "cpu_cores")
            nproc
            ;;
        "disk_space")
            df -h / | awk 'NR==2{print $4}'
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Backup configuration file
backup_config() {
    local config_file="$1"
    local backup_dir="/var/server-panel/backups/configs"
    
    if [[ -f "$config_file" ]]; then
        mkdir -p "$backup_dir"
        local backup_name="$(basename "$config_file").$(date +%Y%m%d_%H%M%S).bak"
        cp "$config_file" "$backup_dir/$backup_name"
        log "SUCCESS" "Backed up $config_file to $backup_dir/$backup_name"
    fi
}

# Update package repositories
update_packages() {
    local os_type
    os_type=$(get_system_info "os")
    
    case "$os_type" in
        "ubuntu"|"debian")
            apt-get update
            ;;
        "centos"|"rhel")
            yum update -y
            ;;
        "fedora")
            dnf update -y
            ;;
        *)
            log "WARNING" "Unknown OS type: $os_type. Package update skipped."
            ;;
    esac
}

# Install package
install_package() {
    local package_name="$1"
    local os_type
    os_type=$(get_system_info "os")
    
    case "$os_type" in
        "ubuntu"|"debian")
            apt-get install -y "$package_name"
            ;;
        "centos"|"rhel")
            yum install -y "$package_name"
            ;;
        "fedora")
            dnf install -y "$package_name"
            ;;
        *)
            log "ERROR" "Unknown OS type: $os_type. Cannot install $package_name"
            return 1
            ;;
    esac
}

# Create directory with proper permissions
create_directory() {
    local dir_path="$1"
    local owner="${2:-root}"
    local group="${3:-root}"
    local permissions="${4:-755}"
    
    mkdir -p "$dir_path"
    chown "$owner:$group" "$dir_path"
    chmod "$permissions" "$dir_path"
    
    log "SUCCESS" "Created directory $dir_path with permissions $permissions"
}

# Validate domain name
validate_domain() {
    local domain="$1"
    
    if [[ "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        return 0
    else
        return 1
    fi
}

# Validate email address
validate_email() {
    local email="$1"
    
    if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Get available memory in GB
get_available_memory() {
    free -g | awk 'NR==2{print $7}'
}

# Get disk usage percentage
get_disk_usage() {
    df / | awk 'NR==2{print $5}' | sed 's/%//'
}

# Check if we have enough resources
check_system_requirements() {
    local min_memory_gb="${1:-2}"
    local min_disk_space_gb="${2:-10}"
    
    local available_memory
    available_memory=$(get_available_memory)
    
    local disk_usage
    disk_usage=$(get_disk_usage)
    local available_disk_percent=$((100 - disk_usage))
    
    if [[ $available_memory -lt $min_memory_gb ]]; then
        log "WARNING" "System has less than ${min_memory_gb}GB available memory"
        return 1
    fi
    
    if [[ $available_disk_percent -lt 20 ]]; then
        log "WARNING" "System has less than 20% disk space available"
        return 1
    fi
    
    log "SUCCESS" "System requirements check passed"
    return 0
}

# Generate SSL certificate paths
get_ssl_paths() {
    local domain="$1"
    local cert_dir="/etc/letsencrypt/live/$domain"
    
    echo "cert_file=$cert_dir/fullchain.pem"
    echo "key_file=$cert_dir/privkey.pem"
}

# Test SSL certificate
test_ssl_cert() {
    local domain="$1"
    local port="${2:-443}"
    
    if timeout 10 openssl s_client -connect "$domain:$port" -servername "$domain" &>/dev/null; then
        log "SUCCESS" "SSL certificate for $domain is valid"
        return 0
    else
        log "ERROR" "SSL certificate test failed for $domain"
        return 1
    fi
}

# Export functions for use in other scripts
export -f log
export -f is_service_running
export -f wait_for_service
export -f is_port_available
export -f generate_password
export -f create_system_user
export -f download_file
export -f check_docker
export -f ensure_docker_network
export -f get_system_info
export -f backup_config
export -f update_packages
export -f install_package
export -f create_directory
export -f validate_domain
export -f validate_email
export -f check_system_requirements
export -f get_ssl_paths
export -f test_ssl_cert 