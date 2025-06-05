#!/bin/bash

# Server Panel Installer
# Complete cPanel-like server management system
# Supports Docker-based isolation, multiple webservers, databases, and applications
#
# Usage:
#   Auto-install everything:      sudo ./install.sh
#   Auto-install with domain:     sudo ./install.sh mydomain.com admin@mydomain.com
#   Interactive install:          sudo AUTO_INSTALL=false ./install.sh
#
# Auto-install installs: NGINX, MySQL, WordPress, PHP, Node.js, Python, FileManager, SSL, Monitoring, Backup

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
DOMAIN="${1:-panel.localhost}"
EMAIL="${2:-admin@localhost}"
AUTO_INSTALL="${AUTO_INSTALL:-true}"

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This script must be run as root${NC}"
        exit 1
    fi
}

# Check OS compatibility
check_os() {
    if [[ ! -f /etc/os-release ]]; then
        echo -e "${RED}Unsupported operating system${NC}"
        exit 1
    fi
    
    source /etc/os-release
    if [[ "$ID" != "ubuntu" ]] && [[ "$ID" != "centos" ]] && [[ "$ID" != "debian" ]]; then
        echo -e "${YELLOW}Warning: This installer is tested on Ubuntu, CentOS, and Debian${NC}"
    fi
}

# Install dialog for interactive menus (only if not auto-installing)
install_dialog() {
    if [[ "$AUTO_INSTALL" != "true" ]]; then
        echo -e "${BLUE}Installing dialog for interactive menus...${NC}"
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update && apt-get install -y dialog
        elif command -v yum >/dev/null 2>&1; then
            yum install -y dialog
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y dialog
        fi
    fi
}

# Main configuration menu
show_main_menu() {
    if [[ "$AUTO_INSTALL" == "true" ]]; then
        # Auto-install all components
        echo "nginx mysql wordpress php nodejs python filemanager ssl monitoring backup"
        return
    fi
    
    local choices
    choices=$(dialog --checklist "Choose components to install:" 22 70 12 \
        "nginx" "NGINX Web Server" on \
        "apache" "Apache Web Server" off \
        "mysql" "MySQL Database" on \
        "postgres" "PostgreSQL Database" off \
        "wordpress" "WordPress Support" on \
        "php" "PHP Support (Laravel, CodeIgniter)" on \
        "nodejs" "Node.js Support (Express, Next.js)" on \
        "python" "Python Support (Flask, Django)" on \
        "filemanager" "File Manager (FileBrowser)" on \
        "ssl" "SSL/Let's Encrypt" on \
        "monitoring" "Monitoring (Prometheus, Grafana)" on \
        "backup" "Automated Backup System" on 3>&1 1>&2 2>&3)
    
    if [[ $? -eq 0 ]]; then
        echo "$choices" | tr -d '"'
    else
        echo -e "${RED}Installation cancelled${NC}"
        exit 1
    fi
}

# Web server selection
select_webserver() {
    if [[ "$AUTO_INSTALL" == "true" ]]; then
        WEB_SERVER="nginx"
        return
    fi
    
    local server
    server=$(dialog --radiolist "Select primary web server:" 12 50 2 \
        "nginx" "NGINX (Recommended)" on \
        "apache" "Apache HTTP Server" off 3>&1 1>&2 2>&3)
    
    if [[ $? -eq 0 ]]; then
        WEB_SERVER=$(echo "$server" | tr -d '"')
    else
        WEB_SERVER="nginx"
    fi
}

# Database selection
select_database() {
    if [[ "$AUTO_INSTALL" == "true" ]]; then
        DATABASE="mysql"
        return
    fi
    
    local db
    db=$(dialog --radiolist "Select primary database:" 12 50 2 \
        "mysql" "MySQL (Recommended)" on \
        "postgres" "PostgreSQL" off 3>&1 1>&2 2>&3)
    
    if [[ $? -eq 0 ]]; then
        DATABASE=$(echo "$db" | tr -d '"')
    else
        DATABASE="mysql"
    fi
}

# Domain and email input
get_domain_info() {
    if [[ "$AUTO_INSTALL" == "true" ]]; then
        # Use command line arguments or defaults
        if [[ -z "$DOMAIN" ]]; then
            DOMAIN="panel.localhost"
        fi
        if [[ -z "$EMAIL" ]]; then
            EMAIL="admin@localhost"
        fi
        echo -e "${BLUE}Using Domain: $DOMAIN, Email: $EMAIL${NC}"
        return
    fi
    
    DOMAIN=$(dialog --inputbox "Enter your domain name (e.g., panel.example.com):" 8 60 3>&1 1>&2 2>&3)
    EMAIL=$(dialog --inputbox "Enter your email for SSL certificates:" 8 60 3>&1 1>&2 2>&3)
    
    if [[ -z "$DOMAIN" ]] || [[ -z "$EMAIL" ]]; then
        echo -e "${RED}Domain and email are required${NC}"
        exit 1
    fi
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
        if [[ "$DOMAIN" == *"localhost"* ]] || [[ "$DOMAIN" == "127.0.0.1" ]]; then
            echo -e "${YELLOW}Skipping Let's Encrypt SSL for localhost/local domain${NC}"
            echo -e "${BLUE}SSL will use self-signed certificates${NC}"
        else
            echo -e "${GREEN}Setting up SSL/Let's Encrypt...${NC}"
            bash "$INSTALL_DIR/modules/certbot.sh" "$DOMAIN" "$EMAIL"
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
    bash "$INSTALL_DIR/modules/panel-frontend.sh" "$DOMAIN"
    bash "$INSTALL_DIR/modules/panel-backend.sh" "$DATABASE"
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
Type=forking
ExecStart=$INSTALL_DIR/scripts/start-panel.sh
ExecStop=$INSTALL_DIR/scripts/stop-panel.sh
Restart=always
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
cd /opt/server-panel/panel
docker-compose up -d
EOF
    
    cat > "$INSTALL_DIR/scripts/stop-panel.sh" << 'EOF'
#!/bin/bash
cd /opt/server-panel/panel
docker-compose down
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
    echo -e "${YELLOW}Note: Please save your admin credentials and configure DNS for $DOMAIN${NC}"
    echo ""
}

# Main installation function
main() {
    clear
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}    Server Panel Installer v1.0        ${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    
    # Check for auto-install mode
    if [[ "$AUTO_INSTALL" == "true" ]]; then
        echo -e "${BLUE}Running in AUTO-INSTALL mode${NC}"
        echo -e "${BLUE}Installing ALL components with NGINX + MySQL${NC}"
        echo ""
    fi
    
    # Preliminary checks
    check_root
    check_os
    install_dialog
    
    # Get user preferences
    local selected_components
    selected_components=$(show_main_menu)
    select_webserver
    select_database
    get_domain_info
    
    # Start installation
    echo -e "${BLUE}Starting installation with selected components...${NC}"
    if [[ "$AUTO_INSTALL" != "true" ]]; then
        sleep 2
    fi
    
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