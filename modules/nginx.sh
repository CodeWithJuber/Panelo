#!/bin/bash

# NGINX Installation Module
# Installs and configures NGINX as reverse proxy for server panel

source "$(dirname "$0")/helper.sh" 2>/dev/null || true

install_nginx() {
    log "INFO" "Starting NGINX installation"
    
    # Check if NGINX is already installed
    if command -v nginx &>/dev/null; then
        log "INFO" "NGINX is already installed"
        nginx -v
        return 0
    fi
    
    local os_type
    os_type=$(get_system_info "os")
    
    case "$os_type" in
        "ubuntu"|"debian")
            install_nginx_ubuntu_debian
            ;;
        "centos"|"rhel")
            install_nginx_centos_rhel
            ;;
        "fedora")
            install_nginx_fedora
            ;;
        *)
            log "ERROR" "Unsupported OS for NGINX installation: $os_type"
            return 1
            ;;
    esac
    
    # Configure NGINX
    configure_nginx
    
    # Create server panel configuration
    setup_panel_proxy
    
    # Start NGINX
    start_nginx
    
    # Verify installation
    verify_nginx_installation
}

install_nginx_ubuntu_debian() {
    log "INFO" "Installing NGINX on Ubuntu/Debian"
    
    # Update package index
    apt-get update
    
    # Install NGINX
    apt-get install -y nginx nginx-extras
    
    log "SUCCESS" "NGINX installed on Ubuntu/Debian"
}

install_nginx_centos_rhel() {
    log "INFO" "Installing NGINX on CentOS/RHEL"
    
    # Install EPEL repository
    yum install -y epel-release
    
    # Install NGINX
    yum install -y nginx
    
    log "SUCCESS" "NGINX installed on CentOS/RHEL"
}

install_nginx_fedora() {
    log "INFO" "Installing NGINX on Fedora"
    
    # Install NGINX
    dnf install -y nginx
    
    log "SUCCESS" "NGINX installed on Fedora"
}

configure_nginx() {
    log "INFO" "Configuring NGINX"
    
    # Backup original configuration
    backup_config "/etc/nginx/nginx.conf"
    
    # Create main NGINX configuration
    cat > /etc/nginx/nginx.conf << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    # Basic Settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 100M;
    
    # MIME Types
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # Logging
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    log_format detailed '$remote_addr - $remote_user [$time_local] "$request" '
                       '$status $body_bytes_sent "$http_referer" '
                       '"$http_user_agent" "$http_x_forwarded_for" '
                       '$request_time $upstream_response_time';
    
    access_log /var/log/nginx/access.log main;
    
    # Gzip Settings
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;
    
    # Rate Limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=panel:10m rate=30r/s;
    
    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    # Hide NGINX version
    server_tokens off;
    
    # Include server configurations
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF
    
    # Create directories
    mkdir -p /etc/nginx/conf.d
    mkdir -p /etc/nginx/sites-available
    mkdir -p /etc/nginx/sites-enabled
    mkdir -p /var/www/html/server-panel
    
    # Remove default site if it exists
    rm -f /etc/nginx/sites-enabled/default
    rm -f /etc/nginx/conf.d/default.conf
    
    # Create default catch-all server
    cat > /etc/nginx/sites-available/default << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    
    # Security
    location /.well-known/acme-challenge/ {
        root /var/www/html;
        allow all;
    }
    
    # Redirect to HTTPS
    location / {
        return 301 https://$server_name$request_uri;
    }
}

server {
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;
    server_name _;
    
    # SSL configuration (will be replaced by Let's Encrypt)
    ssl_certificate /etc/nginx/ssl/default.crt;
    ssl_certificate_key /etc/nginx/ssl/default.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    
    root /var/www/html;
    index index.html;
    
    location / {
        try_files $uri $uri/ =404;
    }
}
EOF
    
    # Create SSL directory and self-signed certificate
    mkdir -p /etc/nginx/ssl
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/default.key \
        -out /etc/nginx/ssl/default.crt \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"
    
    # Enable default site
    ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/
    
    log "SUCCESS" "NGINX configured successfully"
}

setup_panel_proxy() {
    log "INFO" "Setting up server panel proxy configuration"
    
    # Create panel proxy configuration template
    cat > /etc/nginx/sites-available/server-panel.template << 'EOF'
# Server Panel Configuration Template
upstream panel_backend {
    server 127.0.0.1:3001;
    keepalive 32;
}

upstream panel_frontend {
    server 127.0.0.1:3000;
    keepalive 32;
}

upstream file_manager {
    server 127.0.0.1:8080;
    keepalive 16;
}

# Panel Frontend
server {
    listen 80;
    listen [::]:80;
    server_name DOMAIN_PLACEHOLDER;
    
    # Security
    location /.well-known/acme-challenge/ {
        root /var/www/html;
        allow all;
    }
    
    # Redirect to HTTPS
    location / {
        return 301 https://$server_name$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name DOMAIN_PLACEHOLDER;
    
    # SSL configuration (will be updated by certbot)
    ssl_certificate /etc/nginx/ssl/default.crt;
    ssl_certificate_key /etc/nginx/ssl/default.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Panel Frontend
    location / {
        limit_req zone=panel burst=20 nodelay;
        
        proxy_pass http://panel_frontend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # API Routes
    location /api/ {
        limit_req zone=api burst=10 nodelay;
        
        proxy_pass http://panel_backend;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # API specific timeouts
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
    
    # File Manager
    location /files/ {
        auth_basic "File Manager";
        auth_basic_user_file /etc/nginx/.htpasswd;
        
        proxy_pass http://file_manager/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # File upload settings
        client_max_body_size 1G;
        proxy_request_buffering off;
    }
    
    # WebSocket support for file manager
    location /files/ws {
        proxy_pass http://file_manager/ws;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF
    
    log "SUCCESS" "Server panel proxy configuration created"
}

create_panel_site() {
    local domain="$1"
    
    if [[ -z "$domain" ]]; then
        log "ERROR" "Domain is required for panel site creation"
        return 1
    fi
    
    log "INFO" "Creating NGINX site for domain: $domain"
    
    # Create site configuration from template
    sed "s/DOMAIN_PLACEHOLDER/$domain/g" \
        /etc/nginx/sites-available/server-panel.template > \
        /etc/nginx/sites-available/server-panel
    
    # Enable the site
    ln -sf /etc/nginx/sites-available/server-panel /etc/nginx/sites-enabled/
    
    # Test NGINX configuration
    if nginx -t; then
        systemctl reload nginx
        log "SUCCESS" "Server panel site created and enabled for $domain"
    else
        log "ERROR" "NGINX configuration test failed"
        return 1
    fi
}

start_nginx() {
    log "INFO" "Starting NGINX service"
    
    # Enable and start NGINX
    systemctl enable nginx
    systemctl start nginx
    
    # Wait for NGINX to be ready
    wait_for_service "nginx"
    
    log "SUCCESS" "NGINX service started"
}

verify_nginx_installation() {
    log "INFO" "Verifying NGINX installation"
    
    # Check NGINX version
    if nginx -v; then
        log "SUCCESS" "NGINX version check passed"
    else
        log "ERROR" "NGINX version check failed"
        return 1
    fi
    
    # Test NGINX configuration
    if nginx -t; then
        log "SUCCESS" "NGINX configuration test passed"
    else
        log "ERROR" "NGINX configuration test failed"
        return 1
    fi
    
    # Check if NGINX is listening on ports 80 and 443
    if ss -tuln | grep -q ":80 "; then
        log "SUCCESS" "NGINX is listening on port 80"
    else
        log "ERROR" "NGINX is not listening on port 80"
        return 1
    fi
    
    if ss -tuln | grep -q ":443 "; then
        log "SUCCESS" "NGINX is listening on port 443"
    else
        log "ERROR" "NGINX is not listening on port 443"
        return 1
    fi
    
    log "SUCCESS" "NGINX installation verification completed"
}

# Create user for basic auth
create_basic_auth_user() {
    local username="$1"
    local password="$2"
    
    if [[ -z "$username" ]] || [[ -z "$password" ]]; then
        log "ERROR" "Username and password are required"
        return 1
    fi
    
    # Install htpasswd if not available
    if ! command -v htpasswd &>/dev/null; then
        install_package "apache2-utils" || install_package "httpd-tools"
    fi
    
    # Create htpasswd file
    htpasswd -cb /etc/nginx/.htpasswd "$username" "$password"
    chmod 644 /etc/nginx/.htpasswd
    
    log "SUCCESS" "Basic auth user created: $username"
}

# Add application proxy configuration
add_app_proxy() {
    local app_name="$1"
    local domain="$2"
    local upstream_port="$3"
    local app_type="${4:-generic}"
    
    if [[ -z "$app_name" ]] || [[ -z "$domain" ]] || [[ -z "$upstream_port" ]]; then
        log "ERROR" "App name, domain, and upstream port are required"
        return 1
    fi
    
    log "INFO" "Adding proxy configuration for $app_name on $domain"
    
    # Create app-specific configuration
    cat > "/etc/nginx/sites-available/${app_name}" << EOF
# Configuration for ${app_name}
upstream ${app_name}_backend {
    server 127.0.0.1:${upstream_port};
    keepalive 32;
}

server {
    listen 80;
    listen [::]:80;
    server_name ${domain};
    
    # Security
    location /.well-known/acme-challenge/ {
        root /var/www/html;
        allow all;
    }
    
    # Redirect to HTTPS
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${domain};
    
    # SSL configuration (will be updated by certbot)
    ssl_certificate /etc/nginx/ssl/default.crt;
    ssl_certificate_key /etc/nginx/ssl/default.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Application proxy
    location / {
        proxy_pass http://${app_name}_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF
    
    # Enable the site
    ln -sf "/etc/nginx/sites-available/${app_name}" "/etc/nginx/sites-enabled/"
    
    # Test and reload NGINX
    if nginx -t; then
        systemctl reload nginx
        log "SUCCESS" "Proxy configuration added for $app_name"
    else
        log "ERROR" "NGINX configuration test failed for $app_name"
        return 1
    fi
}

# Remove application proxy
remove_app_proxy() {
    local app_name="$1"
    
    if [[ -z "$app_name" ]]; then
        log "ERROR" "App name is required"
        return 1
    fi
    
    log "INFO" "Removing proxy configuration for $app_name"
    
    # Remove site files
    rm -f "/etc/nginx/sites-enabled/${app_name}"
    rm -f "/etc/nginx/sites-available/${app_name}"
    
    # Test and reload NGINX
    if nginx -t; then
        systemctl reload nginx
        log "SUCCESS" "Proxy configuration removed for $app_name"
    else
        log "ERROR" "NGINX configuration test failed after removing $app_name"
        return 1
    fi
}

# Main execution
main() {
    case "${1:-install}" in
        "install")
            install_nginx
            ;;
        "create-site")
            create_panel_site "$2"
            ;;
        "add-auth")
            create_basic_auth_user "$2" "$3"
            ;;
        "add-proxy")
            add_app_proxy "$2" "$3" "$4" "$5"
            ;;
        "remove-proxy")
            remove_app_proxy "$2"
            ;;
        *)
            echo "Usage: $0 [install|create-site|add-auth|add-proxy|remove-proxy]"
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 