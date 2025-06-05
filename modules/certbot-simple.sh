#!/bin/bash

# Simple Certbot SSL Installation Module for testing
# This version has minimal dependencies and should work reliably

# Simple logging function
log() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
}

# Simple domain validation
validate_domain() {
    local domain="$1"
    [[ "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]
}

# Simple email validation
validate_email() {
    local email="$1"
    [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}

# Install SSL certificate
install_ssl() {
    local domain="$1"
    local email="$2"
    
    log "INFO" "Starting SSL installation for domain: $domain with email: $email"
    
    # For IP addresses, we skip Let's Encrypt
    if [[ "$domain" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || [[ "$domain" =~ ^[0-9a-fA-F:]+$ ]]; then
        log "INFO" "IP address detected: $domain - skipping Let's Encrypt (using self-signed)"
        return 0
    fi
    
    # Validate inputs
    if ! validate_domain "$domain"; then
        log "ERROR" "Invalid domain: $domain"
        return 1
    fi
    
    if ! validate_email "$email"; then
        log "ERROR" "Invalid email: $email"
        return 1
    fi
    
    # Check if certbot is installed
    if ! command -v certbot >/dev/null 2>&1; then
        log "INFO" "Installing certbot..."
        
        # Install certbot based on OS
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update
            apt-get install -y snapd
            snap install core
            snap refresh core
            snap install --classic certbot
            ln -sf /snap/bin/certbot /usr/bin/certbot
        elif command -v yum >/dev/null 2>&1; then
            yum install -y epel-release
            yum install -y certbot python3-certbot-nginx
        else
            log "ERROR" "Unsupported OS for certbot installation"
            return 1
        fi
    fi
    
    # Create webroot directory
    mkdir -p /var/www/html/.well-known/acme-challenge
    chown -R www-data:www-data /var/www/html/.well-known 2>/dev/null || chown -R nginx:nginx /var/www/html/.well-known 2>/dev/null || true
    
    # Try to obtain certificate
    log "INFO" "Obtaining SSL certificate for $domain"
    certbot certonly \
        --webroot \
        --webroot-path="/var/www/html" \
        --email "$email" \
        --agree-tos \
        --non-interactive \
        --domains "$domain" \
        --verbose
    
    if [[ $? -eq 0 ]]; then
        log "SUCCESS" "SSL certificate obtained for $domain"
        
        # Reload web server
        systemctl reload nginx 2>/dev/null || systemctl reload apache2 2>/dev/null || true
        
        return 0
    else
        log "ERROR" "Failed to obtain SSL certificate for $domain"
        return 1
    fi
}

# Main function
main() {
    local command="$1"
    local domain="$2"
    local email="$3"
    
    # Debug output
    log "INFO" "Simple certbot called with: command='$command', domain='$domain', email='$email'"
    
    case "$command" in
        "install")
            if [[ -z "$domain" ]] || [[ -z "$email" ]]; then
                log "ERROR" "Usage: $0 install <domain> <email>"
                exit 1
            fi
            install_ssl "$domain" "$email"
            ;;
        *)
            echo "Usage: $0 install <domain> <email>"
            echo "Simple SSL certificate installer"
            exit 1
            ;;
    esac
}

# Execute main function
main "$@" 