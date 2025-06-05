#!/bin/bash

# Server Panel Installer
# Complete cPanel-like server management system
# Supports Docker-based isolation, multiple webservers, databases, and applications
#
# Usage:
#   sudo ./install.sh
#
# Installs: NGINX, MySQL, WordPress, PHP, Node.js, Python, FileManager, SSL, Monitoring, Backup
# Zero configuration required - fully automated like cPanel

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
INSTALL_DIR="/opt/server-panel"
DATA_DIR="/var/server-panel"
WEB_SERVER="nginx"
DATABASE="mysql"
APPS=()
INSTALL_FILEMANAGER="yes"
DOMAIN=""
EMAIL="admin@panelo.local"
AUTO_INSTALL="true"

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This script must be run as root${NC}"
        exit 1
    fi
}

# Auto-detect server information
detect_server_info() {
    echo -e "${BLUE}Auto-detecting server configuration...${NC}"
    
    # Get server's public IPv4 (preferred)
    local ipv4_ip
    ipv4_ip=$(curl -4 -s ifconfig.me 2>/dev/null || curl -4 -s ipinfo.io/ip 2>/dev/null || curl -4 -s icanhazip.com 2>/dev/null)
    
    # Get server's public IPv6 (fallback)
    local ipv6_ip
    ipv6_ip=$(curl -6 -s ifconfig.me 2>/dev/null || curl -6 -s ipinfo.io/ip 2>/dev/null || curl -6 -s icanhazip.com 2>/dev/null)
    
    # Get local IP as ultimate fallback
    local local_ip
    local_ip=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $7; exit}' || hostname -I | awk '{print $1}' || echo "127.0.0.1")
    
    # Prefer IPv4, then local IP, then IPv6
    local public_ip
    if [[ -n "$ipv4_ip" && "$ipv4_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        public_ip="$ipv4_ip"
        echo -e "${GREEN}✓ IPv4 Address: $ipv4_ip${NC}"
    elif [[ -n "$local_ip" && "$local_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        public_ip="$local_ip"
        echo -e "${GREEN}✓ Local IPv4 Address: $local_ip${NC}"
    elif [[ -n "$ipv6_ip" ]]; then
        public_ip="$ipv6_ip"
        echo -e "${GREEN}✓ IPv6 Address: $ipv6_ip${NC}"
    else
        public_ip="127.0.0.1"
        echo -e "${YELLOW}⚠ Using localhost as fallback${NC}"
    fi
    
    # Show all available addresses
    if [[ -n "$ipv4_ip" && -n "$ipv6_ip" ]]; then
        echo -e "${BLUE}📍 Available Access Points:${NC}"
        echo -e "   • IPv4: https://$ipv4_ip:3000"
        echo -e "   • IPv6: https://[$ipv6_ip]:3000"
    fi
    
    # Get hostname
    local hostname
    hostname=$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo "panelo")
    
    # Set domain to IP address for direct access
    DOMAIN="$public_ip"
    
    # Set default email for SSL (not needed for IP addresses but required for parameter)
    EMAIL="admin@${hostname}"
    
    echo -e "${GREEN}✓ Hostname: $hostname${NC}"
    echo -e "${GREEN}✓ Default email: $EMAIL${NC}"
    echo -e "${GREEN}✓ Primary Panel URL: https://$DOMAIN:3000${NC}"
}

# Check OS compatibility
check_os() {
    if [[ ! -f /etc/os-release ]]; then
        echo -e "${RED}Unsupported operating system${NC}"
        exit 1
    fi
    
    source /etc/os-release
    echo -e "${GREEN}✓ Detected OS: $PRETTY_NAME${NC}"
}

# No longer needed - fully automated
install_dialog() {
    # Completely automated - no dialog needed
    return 0
}

# Auto-install all components - no menu
show_main_menu() {
    echo "nginx mysql wordpress php nodejs python filemanager ssl monitoring backup"
}

# Web server selection - auto NGINX
select_webserver() {
    WEB_SERVER="nginx"
}

# Database selection - auto MySQL
select_database() {
    DATABASE="mysql"
}

# Domain and email - auto-detected
get_domain_info() {
    # Domain already set by detect_server_info()
    echo -e "${GREEN}✓ Using server IP: $DOMAIN${NC}"
    echo -e "${GREEN}✓ Using email: $EMAIL${NC}"
}

# Create directory structure
create_directories() {
    echo -e "${BLUE}Creating directory structure...${NC}"
    
    mkdir -p "$INSTALL_DIR"/{modules,templates,panel,scripts}
    mkdir -p "$DATA_DIR"/{users,apps,backups,ssl}
    mkdir -p /var/log/server-panel
    
    # Set permissions
    chmod 755 "$INSTALL_DIR"
    chmod 700 "$DATA_DIR"
}

# Copy project files
copy_project_files() {
    echo -e "${BLUE}Copying project files...${NC}"
    
    # Copy current directory contents to install directory
    cp -r . "$INSTALL_DIR/" 2>/dev/null || true
    
    # Make scripts executable
    chmod +x "$INSTALL_DIR"/modules/*.sh 2>/dev/null || true
    chmod +x "$INSTALL_DIR"/scripts/*.sh 2>/dev/null || true
}

# Load helper functions
load_helpers() {
    if [[ -f "$INSTALL_DIR/modules/helper.sh" ]]; then
        source "$INSTALL_DIR/modules/helper.sh"
    fi
}

# Install base dependencies
install_base_dependencies() {
    echo -e "${BLUE}Installing base dependencies...${NC}"
    
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y curl wget git unzip htop nano vim fail2ban ufw
    elif command -v yum >/dev/null 2>&1; then
        yum update -y
        yum install -y curl wget git unzip htop nano vim fail2ban firewalld
    elif command -v dnf >/dev/null 2>&1; then
        dnf update -y
        dnf install -y curl wget git unzip htop nano vim fail2ban firewalld
    fi
}

# Install selected components
install_components() {
    local selected_components="$1"
    
    # Always install Docker first
    echo -e "${GREEN}Installing Docker...${NC}"
    bash "$INSTALL_DIR/modules/docker.sh"
    
    # Install selected web server
    if [[ "$selected_components" == *"nginx"* ]]; then
        echo -e "${GREEN}Installing NGINX...${NC}"
        bash "$INSTALL_DIR/modules/nginx.sh"
        WEB_SERVER="nginx"
    elif [[ "$selected_components" == *"apache"* ]]; then
        echo -e "${GREEN}Installing Apache...${NC}"
        bash "$INSTALL_DIR/modules/apache.sh"
        WEB_SERVER="apache"
    fi
    
    # Install selected database
    if [[ "$selected_components" == *"mysql"* ]]; then
        echo -e "${GREEN}Installing MySQL...${NC}"
        bash "$INSTALL_DIR/modules/mysql.sh"
        DATABASE="mysql"
    elif [[ "$selected_components" == *"postgres"* ]]; then
        echo -e "${GREEN}Installing PostgreSQL...${NC}"
        bash "$INSTALL_DIR/modules/postgres.sh"
        DATABASE="postgres"
    fi
    
    # Install application support
    if [[ "$selected_components" == *"wordpress"* ]]; then
        echo -e "${GREEN}Setting up WordPress support...${NC}"
        bash "$INSTALL_DIR/modules/wordpress.sh"
    fi
    
    if [[ "$selected_components" == *"php"* ]]; then
        echo -e "${GREEN}Setting up PHP support...${NC}"
        bash "$INSTALL_DIR/modules/php.sh"
    fi
    
    if [[ "$selected_components" == *"nodejs"* ]]; then
        echo -e "${GREEN}Setting up Node.js support...${NC}"
        bash "$INSTALL_DIR/modules/nodejs.sh"
    fi
    
    if [[ "$selected_components" == *"python"* ]]; then
        echo -e "${GREEN}Setting up Python support...${NC}"
        bash "$INSTALL_DIR/modules/python.sh"
    fi
    
    # Install file manager
    if [[ "$selected_components" == *"filemanager"* ]]; then
        echo -e "${GREEN}Installing File Manager...${NC}"
        bash "$INSTALL_DIR/modules/filemanager.sh"
    fi
    
    # Install SSL support
    if [[ "$selected_components" == *"ssl"* ]]; then
        echo -e "${BLUE}SSL Configuration - Domain: '$DOMAIN', Email: '$EMAIL'${NC}"
        if [[ "$DOMAIN" == "127.0.0.1" ]] || [[ "$DOMAIN" == *"localhost"* ]] || [[ "$DOMAIN" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || [[ "$DOMAIN" =~ ^[0-9a-fA-F:]+$ ]]; then
            echo -e "${BLUE}Using self-signed SSL certificates for IP address: $DOMAIN${NC}"
            # NGINX already creates self-signed certs
        else
            echo -e "${GREEN}Setting up SSL/Let's Encrypt for domain: $DOMAIN${NC}"
            echo -e "${BLUE}Running: bash \"$INSTALL_DIR/modules/certbot.sh\" install \"$DOMAIN\" \"$EMAIL\"${NC}"
            bash "$INSTALL_DIR/modules/certbot.sh" install "$DOMAIN" "$EMAIL"
        fi
    fi
    
    # Install monitoring if selected
    if [[ "$selected_components" == *"monitoring"* ]]; then
        echo -e "${GREEN}Installing monitoring stack...${NC}"
        bash "$INSTALL_DIR/modules/monitoring.sh"
    fi
    
    # Install backup system if selected
    if [[ "$selected_components" == *"backup"* ]]; then
        echo -e "${GREEN}Setting up automated backup system...${NC}"
        bash "$INSTALL_DIR/modules/backup.sh"
    fi
}

# Install panel frontend and backend
install_panel() {
    echo -e "${GREEN}Installing Server Panel Frontend and Backend...${NC}"
    
    # Ensure Docker network exists
    docker network create server-panel 2>/dev/null || true
    
    # Install backend first
    bash "$INSTALL_DIR/modules/panel-backend.sh" "$DATABASE"
    
    # Install frontend
    bash "$INSTALL_DIR/modules/panel-frontend.sh" install "$DOMAIN"
    
    # Wait for services to be ready
    sleep 10
    
    # Verify services are running
    echo -e "${BLUE}Verifying panel services...${NC}"
    docker ps | grep -E "(panel|server)" || echo "No panel containers found"
}

# Configure firewall
configure_firewall() {
    echo -e "${BLUE}Configuring firewall...${NC}"
    
    if command -v ufw >/dev/null 2>&1; then
        ufw --force enable
        ufw allow 22/tcp   # SSH
        ufw allow 80/tcp   # HTTP
        ufw allow 443/tcp  # HTTPS
        ufw allow 3000/tcp # Panel Frontend
        ufw allow 3001/tcp # Backend API / Grafana
        ufw allow 8080/tcp # File Manager
        ufw allow 9090/tcp # Prometheus (admin only)
        ufw allow 9093/tcp # Alertmanager (admin only)
    elif command -v firewall-cmd >/dev/null 2>&1; then
        systemctl enable firewalld
        systemctl start firewalld
        firewall-cmd --permanent --add-port=22/tcp
        firewall-cmd --permanent --add-port=80/tcp
        firewall-cmd --permanent --add-port=443/tcp
        firewall-cmd --permanent --add-port=3000/tcp
        firewall-cmd --permanent --add-port=3001/tcp
        firewall-cmd --permanent --add-port=8080/tcp
        firewall-cmd --permanent --add-port=9090/tcp
        firewall-cmd --permanent --add-port=9093/tcp
        firewall-cmd --reload
    fi
}

# Setup systemd services
setup_services() {
    echo -e "${BLUE}Setting up systemd services...${NC}"
    
    # Create panel service
    cat > /etc/systemd/system/server-panel.service << EOF
[Unit]
Description=Server Panel
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=$INSTALL_DIR/scripts/start-panel.sh
ExecStop=$INSTALL_DIR/scripts/stop-panel.sh
TimeoutStartSec=300
User=root

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable server-panel
}

# Final setup and cleanup
final_setup() {
    echo -e "${BLUE}Performing final setup...${NC}"
    
    # Create admin user
    local admin_password=$(openssl rand -base64 32)
    echo "admin:$admin_password" > "$DATA_DIR/admin-credentials.txt"
    chmod 600 "$DATA_DIR/admin-credentials.txt"
    
    # Create startup script
    cat > "$INSTALL_DIR/scripts/start-panel.sh" << 'EOF'
#!/bin/bash

echo "Starting Server Panel services..."

# Start backend services
echo "Starting backend services..."
cd /opt/server-panel/backend
if [ -f "docker-compose.yml" ]; then
    docker compose up -d
    echo "Backend services started"
else
    echo "Warning: Backend docker-compose.yml not found"
fi

# Start frontend services  
echo "Starting frontend services..."
cd /opt/server-panel/panel/frontend
if [ -f "docker-compose.yml" ]; then
    docker compose up -d
    echo "Frontend services started"
else
    echo "Warning: Frontend docker-compose.yml not found"
fi

echo "Server panel services startup completed!"

# Wait for services to be ready
sleep 5

# Check service status
echo "Checking service status..."
docker ps | grep -E "(panel|server)" || echo "No panel containers found"

# Show access information
SERVER_IP=$(curl -4 -s ifconfig.me 2>/dev/null || ip route get 8.8.8.8 2>/dev/null | awk '{print $7; exit}' || echo "127.0.0.1")
echo "========================================="
echo "🚀 Panel Services Status:"
echo "• Frontend: http://$SERVER_IP:3000"
echo "• Backend: http://$SERVER_IP:3001"
echo "• File Manager: http://$SERVER_IP:8080"
echo "========================================="
EOF
    
    cat > "$INSTALL_DIR/scripts/stop-panel.sh" << 'EOF'
#!/bin/bash

echo "Stopping Server Panel services..."

# Stop frontend services  
echo "Stopping frontend services..."
cd /opt/server-panel/panel/frontend
if [ -f "docker-compose.yml" ]; then
    docker compose down
    echo "Frontend services stopped"
fi

# Stop backend services
echo "Stopping backend services..."
cd /opt/server-panel/backend
if [ -f "docker-compose.yml" ]; then
    docker compose down
    echo "Backend services stopped"
fi

echo "Server panel services stopped!"
EOF
    
    chmod +x "$INSTALL_DIR/scripts"/*.sh
    
    # Start services
    systemctl start server-panel
}

# Display installation summary
show_summary() {
    clear
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Server Panel Installation Complete!  ${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${BLUE}Installation Details:${NC}"
    echo -e "• Install Directory: $INSTALL_DIR"
    echo -e "• Data Directory: $DATA_DIR"
    echo -e "• Web Server: $WEB_SERVER"
    echo -e "• Database: $DATABASE"
    echo -e "• Domain: $DOMAIN"
    echo ""
    echo -e "${BLUE}Access Information:${NC}"
    echo -e "• Panel URL: https://$DOMAIN:3000"
    echo -e "• Backend API: https://$DOMAIN:3001"
    echo -e "• File Manager: https://$DOMAIN:8080"
    echo -e "• Grafana: https://$DOMAIN:3001 (admin/admin123)"
    echo -e "• Prometheus: https://$DOMAIN:9090"
    echo -e "• Admin Credentials: /var/server-panel/admin-credentials.txt"
    echo ""
    echo -e "${BLUE}Management Commands:${NC}"
    echo -e "• Start Panel: systemctl start server-panel"
    echo -e "• Stop Panel: systemctl stop server-panel"
    echo -e "• View Logs: journalctl -u server-panel -f"
    echo -e "• Deploy PHP App: /opt/server-panel/modules/php.sh deploy <name> <domain> <type> <version> <user>"
    echo -e "• Deploy Node.js App: /opt/server-panel/modules/nodejs.sh deploy <name> <domain> <type> <version> <user>"
    echo -e "• Deploy WordPress: /opt/server-panel/modules/wordpress.sh deploy <name> <domain> <email>"
    echo -e "• Monitoring Control: /var/server-panel/monitoring/control.sh [start|stop|restart]"
    echo ""
    echo -e "${YELLOW}⚠️  Important: Save your admin credentials!${NC}"
    echo -e "${YELLOW}💡 Access your panel directly via IP address: https://$DOMAIN:3000${NC}"
    echo ""
}

# Main installation function
main() {
    clear
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}    🚀 PANELO cPanel Alternative Installer     ${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo ""
    echo -e "${BLUE}🔄 Fully Automated Installation${NC}"
    echo -e "${BLUE}📦 Installing: NGINX, MySQL, WordPress, PHP, Node.js, Python, FileManager, SSL, Monitoring${NC}"
    echo ""
    
    # Preliminary checks
    check_root
    check_os
    detect_server_info
    install_dialog
    
    # Get configuration (all automatic)
    local selected_components
    selected_components=$(show_main_menu)
    select_webserver
    select_database
    get_domain_info
    
    # Start installation
    echo ""
    echo -e "${BLUE}🚀 Starting Panelo installation...${NC}"
    
    create_directories
    copy_project_files
    load_helpers
    install_base_dependencies
    install_components "$selected_components"
    install_panel
    configure_firewall
    setup_services
    final_setup
    show_summary
    
    echo -e "${GREEN}Installation completed successfully!${NC}"
}

# Run main function
main "$@" 