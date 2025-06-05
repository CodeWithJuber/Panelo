#!/bin/bash

# Certbot SSL Installation Module - SIMPLIFIED VERSION
# Sets up Let's Encrypt SSL certificates with automatic renewal

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

# SSL configuration
CERTBOT_EMAIL=""
DOMAIN=""
WEBROOT_PATH="/var/www/html"
CERTBOT_CONFIG_DIR="/etc/letsencrypt"
RENEWAL_SCRIPT="/opt/server-panel/scripts/ssl-renewal.sh"

install_certbot() {
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

install_certbot_package() {
    log "INFO" "Installing Certbot"
    
    local os_type
    os_type=$(get_system_info "os")
    
    case "$os_type" in
        "ubuntu"|"debian")
            # Install snapd if not present
            if ! command -v snap &>/dev/null; then
                apt-get update
                apt-get install -y snapd
                snap install core
                snap refresh core
            fi
            
            # Install certbot via snap (recommended method)
            snap install --classic certbot
            ln -sf /snap/bin/certbot /usr/bin/certbot
            ;;
        "centos"|"rhel")
            # Install EPEL repository
            yum install -y epel-release
            yum install -y certbot python3-certbot-nginx
            ;;
        "fedora")
            dnf install -y certbot python3-certbot-nginx
            ;;
        *)
            log "ERROR" "Unsupported OS for Certbot installation: $os_type"
            return 1
            ;;
    esac
    
    # Verify installation
    if command -v certbot &>/dev/null; then
        local version
        version=$(certbot --version)
        log "SUCCESS" "Certbot installed: $version"
    else
        log "ERROR" "Failed to install Certbot"
        return 1
    fi
}

setup_webroot() {
    log "INFO" "Setting up webroot directory"
    
    # Create webroot directory if it doesn't exist
    create_directory "$WEBROOT_PATH" "www-data" "www-data" "755"
    create_directory "$WEBROOT_PATH/.well-known" "www-data" "www-data" "755"
    create_directory "$WEBROOT_PATH/.well-known/acme-challenge" "www-data" "www-data" "755"
    
    # Create a test file to verify webroot access
    echo "SSL verification test file" > "$WEBROOT_PATH/.well-known/acme-challenge/test.txt"
    chmod 644 "$WEBROOT_PATH/.well-known/acme-challenge/test.txt"
    
    log "SUCCESS" "Webroot directory setup completed"
}

obtain_ssl_certificate() {
    log "INFO" "Obtaining SSL certificate for $DOMAIN"
    
    # Check if certificate already exists
    if [[ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then
        log "INFO" "SSL certificate already exists for $DOMAIN"
        return 0
    fi
    
    # Obtain certificate using webroot method
    certbot certonly \
        --webroot \
        --webroot-path="$WEBROOT_PATH" \
        --email "$CERTBOT_EMAIL" \
        --agree-tos \
        --non-interactive \
        --domains "$DOMAIN" \
        --verbose
    
    if [[ $? -eq 0 ]]; then
        log "SUCCESS" "SSL certificate obtained for $DOMAIN"
        
        # Set proper permissions
        chmod 644 "/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
        chmod 600 "/etc/letsencrypt/live/$DOMAIN/privkey.pem"
    else
        log "ERROR" "Failed to obtain SSL certificate for $DOMAIN"
        return 1
    fi
}

setup_ssl_renewal() {
    log "INFO" "Setting up SSL certificate renewal"
    
    # Create renewal script
    cat > "$RENEWAL_SCRIPT" << 'EOF'
#!/bin/bash

# SSL Certificate Renewal Script
# Automatically renews Let's Encrypt certificates and reloads services

source /opt/server-panel/modules/helper.sh

LOGFILE="/var/log/server-panel/ssl-renewal.log"

log_renewal() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}

renew_certificates() {
    log_renewal "Starting SSL certificate renewal check"
    
    # Check and renew certificates
    if certbot renew --quiet --no-self-upgrade; then
        log_renewal "Certificate renewal check completed successfully"
        
        # Reload NGINX if certificates were renewed
        if systemctl is-active --quiet nginx; then
            systemctl reload nginx
            log_renewal "NGINX reloaded after certificate renewal"
        fi
        
        # Reload Apache if it's running
        if systemctl is-active --quiet apache2; then
            systemctl reload apache2
            log_renewal "Apache reloaded after certificate renewal"
        fi
        
        return 0
    else
        log_renewal "ERROR: Certificate renewal failed"
        return 1
    fi
}

# Test SSL certificates
test_ssl_certificates() {
    log_renewal "Testing SSL certificates"
    
    local failed_domains=()
    
    # Find all certificate domains
    for cert_dir in /etc/letsencrypt/live/*/; do
        if [[ -d "$cert_dir" ]]; then
            local domain
            domain=$(basename "$cert_dir")
            
            if [[ "$domain" != "README" ]]; then
                log_renewal "Testing SSL certificate for $domain"
                
                if ! test_ssl_cert "$domain"; then
                    failed_domains+=("$domain")
                fi
            fi
        fi
    done
    
    if [[ ${#failed_domains[@]} -gt 0 ]]; then
        log_renewal "WARNING: SSL test failed for domains: ${failed_domains[*]}"
        return 1
    else
        log_renewal "All SSL certificates are valid"
        return 0
    fi
}

# Send renewal notifications
send_renewal_notification() {
    local status="$1"
    local logfile="/var/log/server-panel/ssl-renewal.log"
    
    # Check if we have mail command
    if command -v mail &>/dev/null && [[ -n "$ADMIN_EMAIL" ]]; then
        if [[ "$status" == "success" ]]; then
            echo "SSL certificate renewal completed successfully on $(hostname)" | \
                mail -s "SSL Renewal Success - $(hostname)" "$ADMIN_EMAIL"
        else
            echo "SSL certificate renewal failed on $(hostname). Check logs: $logfile" | \
                mail -s "SSL Renewal Failed - $(hostname)" "$ADMIN_EMAIL"
        fi
    fi
}

# Main renewal function
main() {
    case "${1:-renew}" in
        "renew")
            if renew_certificates; then
                send_renewal_notification "success"
                exit 0
            else
                send_renewal_notification "failed"
                exit 1
            fi
            ;;
        "test")
            test_ssl_certificates
            ;;
        "force")
            log_renewal "Forcing certificate renewal"
            certbot renew --force-renewal
            systemctl reload nginx 2>/dev/null || true
            systemctl reload apache2 2>/dev/null || true
            ;;
        *)
            echo "Usage: $0 [renew|test|force]"
            exit 1
            ;;
    esac
}

main "$@"
EOF
    
    chmod +x "$RENEWAL_SCRIPT"
    
    # Create log directory
    create_directory "/var/log/server-panel" "root" "root" "755"
    
    # Setup cron job for automatic renewal
    cat > /etc/cron.d/ssl-renewal << 'EOF'
# SSL certificate renewal for server panel
# Runs twice daily at random minutes to spread load
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Renew certificates twice daily
15 2,14 * * * root /opt/server-panel/scripts/ssl-renewal.sh renew >/dev/null 2>&1

# Test certificates weekly
30 3 * * 0 root /opt/server-panel/scripts/ssl-renewal.sh test >/dev/null 2>&1
EOF
    
    # Create systemd timer as alternative to cron
    cat > /etc/systemd/system/ssl-renewal.service << 'EOF'
[Unit]
Description=SSL Certificate Renewal
After=network.target

[Service]
Type=oneshot
ExecStart=/opt/server-panel/scripts/ssl-renewal.sh renew
User=root
EOF
    
    cat > /etc/systemd/system/ssl-renewal.timer << 'EOF'
[Unit]
Description=SSL Certificate Renewal Timer
Requires=ssl-renewal.service

[Timer]
OnCalendar=*-*-* 02,14:15:00
RandomizedDelaySec=3600
Persistent=true

[Install]
WantedBy=timers.target
EOF
    
    # Enable systemd timer
    systemctl daemon-reload
    systemctl enable ssl-renewal.timer
    systemctl start ssl-renewal.timer
    
    log "SUCCESS" "SSL certificate renewal setup completed"
}

update_nginx_ssl_config() {
    log "INFO" "Updating NGINX SSL configuration"
    
    local cert_path="/etc/letsencrypt/live/$DOMAIN"
    
    if [[ ! -f "$cert_path/fullchain.pem" ]]; then
        log "ERROR" "SSL certificate not found at $cert_path"
        return 1
    fi
    
    # Update server panel NGINX configuration
    if [[ -f "/etc/nginx/sites-available/server-panel" ]]; then
        # Backup current configuration
        backup_config "/etc/nginx/sites-available/server-panel"
        
        # Update SSL certificate paths
        sed -i "s|ssl_certificate /etc/nginx/ssl/default.crt;|ssl_certificate $cert_path/fullchain.pem;|g" \
            /etc/nginx/sites-available/server-panel
        
        sed -i "s|ssl_certificate_key /etc/nginx/ssl/default.key;|ssl_certificate_key $cert_path/privkey.pem;|g" \
            /etc/nginx/sites-available/server-panel
        
        # Add SSL optimization
        if ! grep -q "ssl_session_cache" /etc/nginx/sites-available/server-panel; then
            # Add SSL optimization after ssl_prefer_server_ciphers line
            sed -i '/ssl_prefer_server_ciphers off;/a\
    ssl_session_cache shared:SSL:10m;\
    ssl_session_timeout 10m;\
    ssl_stapling on;\
    ssl_stapling_verify on;\
    ssl_trusted_certificate '"$cert_path"'/chain.pem;' \
                /etc/nginx/sites-available/server-panel
        fi
        
        # Test NGINX configuration
        if nginx -t; then
            systemctl reload nginx
            log "SUCCESS" "NGINX SSL configuration updated"
        else
            log "ERROR" "NGINX configuration test failed"
            return 1
        fi
    fi
}

verify_ssl_installation() {
    log "INFO" "Verifying SSL installation"
    
    # Check if certificate files exist
    local cert_path="/etc/letsencrypt/live/$DOMAIN"
    
    if [[ -f "$cert_path/fullchain.pem" ]] && [[ -f "$cert_path/privkey.pem" ]]; then
        log "SUCCESS" "SSL certificate files found"
    else
        log "ERROR" "SSL certificate files not found"
        return 1
    fi
    
    # Check certificate validity
    local cert_info
    cert_info=$(openssl x509 -in "$cert_path/fullchain.pem" -noout -subject -dates)
    log "INFO" "Certificate info: $cert_info"
    
    # Check certificate expiration
    local expiry_date
    expiry_date=$(openssl x509 -in "$cert_path/fullchain.pem" -noout -enddate | cut -d= -f2)
    local expiry_timestamp
    expiry_timestamp=$(date -d "$expiry_date" +%s)
    local current_timestamp
    current_timestamp=$(date +%s)
    local days_until_expiry
    days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))
    
    if [[ $days_until_expiry -gt 30 ]]; then
        log "SUCCESS" "SSL certificate is valid for $days_until_expiry days"
    elif [[ $days_until_expiry -gt 0 ]]; then
        log "WARNING" "SSL certificate expires in $days_until_expiry days"
    else
        log "ERROR" "SSL certificate has expired"
        return 1
    fi
    
    # Test SSL connection
    if test_ssl_cert "$DOMAIN"; then
        log "SUCCESS" "SSL connection test passed"
    else
        log "WARNING" "SSL connection test failed (this is normal if DNS is not configured yet)"
    fi
    
    log "SUCCESS" "SSL installation verification completed"
}

# Add SSL certificate for additional domain
add_ssl_domain() {
    local domain="$1"
    local email="${2:-$CERTBOT_EMAIL}"
    
    if [[ -z "$domain" ]]; then
        log "ERROR" "Domain is required"
        return 1
    fi
    
    if [[ -z "$email" ]]; then
        log "ERROR" "Email is required"
        return 1
    fi
    
    log "INFO" "Adding SSL certificate for $domain"
    
    # Validate domain
    if ! validate_domain "$domain"; then
        log "ERROR" "Invalid domain name: $domain"
        return 1
    fi
    
    # Obtain certificate
    certbot certonly \
        --webroot \
        --webroot-path="$WEBROOT_PATH" \
        --email "$email" \
        --agree-tos \
        --non-interactive \
        --domains "$domain" \
        --verbose
    
    if [[ $? -eq 0 ]]; then
        log "SUCCESS" "SSL certificate obtained for $domain"
        return 0
    else
        log "ERROR" "Failed to obtain SSL certificate for $domain"
        return 1
    fi
}

# Remove SSL certificate
remove_ssl_domain() {
    local domain="$1"
    
    if [[ -z "$domain" ]]; then
        log "ERROR" "Domain is required"
        return 1
    fi
    
    log "INFO" "Removing SSL certificate for $domain"
    
    # Delete certificate
    certbot delete --cert-name "$domain" --non-interactive
    
    if [[ $? -eq 0 ]]; then
        log "SUCCESS" "SSL certificate removed for $domain"
        return 0
    else
        log "ERROR" "Failed to remove SSL certificate for $domain"
        return 1
    fi
}

# List SSL certificates
list_ssl_certificates() {
    log "INFO" "Listing SSL certificates"
    
    certbot certificates
}

# Get SSL certificate status
get_ssl_status() {
    local domain="$1"
    
    if [[ -z "$domain" ]]; then
        # Show status for all certificates
        certbot certificates --quiet
        return $?
    fi
    
    # Check specific domain
    if [[ -f "/etc/letsencrypt/live/$domain/fullchain.pem" ]]; then
        local cert_info
        cert_info=$(openssl x509 -in "/etc/letsencrypt/live/$domain/fullchain.pem" -noout -enddate | cut -d= -f2)
        local expiry_timestamp
        expiry_timestamp=$(date -d "$cert_info" +%s)
        local current_timestamp
        current_timestamp=$(date +%s)
        local days_until_expiry
        days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))
        
        echo "Domain: $domain"
        echo "Status: Valid"
        echo "Expires: $cert_info"
        echo "Days until expiry: $days_until_expiry"
        
        if [[ $days_until_expiry -lt 30 ]]; then
            echo "Warning: Certificate expires soon"
        fi
    else
        echo "Domain: $domain"
        echo "Status: No certificate found"
        return 1
    fi
}

# Force renewal of specific domain
force_renewal() {
    local domain="$1"
    
    if [[ -z "$domain" ]]; then
        log "INFO" "Forcing renewal of all certificates"
        certbot renew --force-renewal
    else
        log "INFO" "Forcing renewal of certificate for $domain"
        certbot renew --cert-name "$domain" --force-renewal
    fi
    
    if [[ $? -eq 0 ]]; then
        # Reload web server
        systemctl reload nginx 2>/dev/null || true
        systemctl reload apache2 2>/dev/null || true
        log "SUCCESS" "Certificate renewal completed"
    else
        log "ERROR" "Certificate renewal failed"
        return 1
    fi
}

# Main execution
main() {
    local command="${1:-install}"
    local domain="$2"
    local email="$3"
    
    # Debug information
    log "INFO" "Certbot script called with command: '$command', domain: '$domain', email: '$email'"
    
    case "$command" in
        "install")
            if [[ -z "$domain" ]] || [[ -z "$email" ]]; then
                log "ERROR" "Install command requires domain and email parameters"
                echo "Usage: $0 install <domain> <email>"
                exit 1
            fi
            install_certbot "$domain" "$email"
            ;;
        "add-domain")
            if [[ -z "$domain" ]]; then
                log "ERROR" "Add-domain command requires domain parameter"
                echo "Usage: $0 add-domain <domain> [email]"
                exit 1
            fi
            add_ssl_domain "$domain" "$email"
            ;;
        "remove-domain")
            if [[ -z "$domain" ]]; then
                log "ERROR" "Remove-domain command requires domain parameter"
                echo "Usage: $0 remove-domain <domain>"
                exit 1
            fi
            remove_ssl_domain "$domain"
            ;;
        "list")
            list_ssl_certificates
            ;;
        "status")
            get_ssl_status "$domain"
            ;;
        "renew")
            if [[ -f "$RENEWAL_SCRIPT" ]]; then
                "$RENEWAL_SCRIPT" renew
            else
                force_renewal "$domain"
            fi
            ;;
        "force-renew")
            force_renewal "$domain"
            ;;
        *)
            echo "Usage: $0 [install|add-domain|remove-domain|list|status|renew|force-renew]"
            echo "Commands:"
            echo "  install <domain> <email>    - Install SSL certificate for domain"
            echo "  add-domain <domain> [email] - Add SSL certificate for additional domain"
            echo "  remove-domain <domain>      - Remove SSL certificate for domain"
            echo "  list                        - List all SSL certificates"
            echo "  status [domain]             - Show SSL certificate status"
            echo "  renew [domain]              - Renew SSL certificates"
            echo "  force-renew [domain]        - Force renewal of SSL certificates"
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 