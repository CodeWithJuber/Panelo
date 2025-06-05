#!/bin/bash

# MySQL Connection Fix Script
# Fixes common MySQL 8.0 authentication and connection issues

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ERROR: $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARNING: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')] INFO: $1${NC}"
}

# Configuration
MYSQL_ROOT_PASSWORD="root_password_123"
MYSQL_DATABASE="server_panel"
MYSQL_USER="panel_user"
MYSQL_PASSWORD="panel_password_123"

check_mysql_container() {
    log "Checking MySQL container status..."
    
    if ! docker ps | grep -q "server-panel-mysql"; then
        error "MySQL container is not running"
        log "Starting MySQL container..."
        
        # Try to start the container
        if [[ -f "modules/mysql.sh" ]]; then
            bash modules/mysql.sh start
            sleep 10
        else
            error "MySQL module not found"
            return 1
        fi
    fi
    
    log "MySQL container is running"
}

wait_for_mysql() {
    log "Waiting for MySQL to be ready..."
    
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if docker exec server-panel-mysql mysqladmin ping -h localhost --silent 2>/dev/null; then
            log "MySQL is ready!"
            return 0
        fi
        
        info "Attempt $attempt/$max_attempts - MySQL not ready yet..."
        sleep 2
        ((attempt++))
    done
    
    error "MySQL failed to become ready after $max_attempts attempts"
    return 1
}

fix_mysql_authentication() {
    log "Fixing MySQL authentication issues..."
    
    # Create SQL script to fix authentication
    cat > /tmp/fix_mysql_auth.sql << EOF
-- Fix root user authentication
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';
ALTER USER 'root'@'%' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';

-- Create database if not exists
CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\`;

-- Create panel user with proper permissions
DROP USER IF EXISTS '$MYSQL_USER'@'%';
CREATE USER '$MYSQL_USER'@'%' IDENTIFIED WITH mysql_native_password BY '$MYSQL_PASSWORD';
GRANT ALL PRIVILEGES ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'%';

-- Create panel tables
USE \`$MYSQL_DATABASE\`;

CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role ENUM('admin', 'user') DEFAULT 'user',
    status ENUM('active', 'inactive') DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS applications (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    name VARCHAR(255) NOT NULL,
    type ENUM('wordpress', 'nodejs', 'php', 'python', 'static') NOT NULL,
    domain VARCHAR(255),
    port INT,
    status ENUM('running', 'stopped', 'creating', 'error') DEFAULT 'creating',
    config JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS domains (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    domain VARCHAR(255) UNIQUE NOT NULL,
    ssl_enabled BOOLEAN DEFAULT FALSE,
    ssl_cert_path VARCHAR(255),
    ssl_key_path VARCHAR(255),
    status ENUM('active', 'inactive') DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Insert default admin user
INSERT IGNORE INTO users (email, password, role) VALUES 
('admin@panelo.com', 'admin123', 'admin'),
('user@panelo.com', 'user123', 'user');

-- Flush privileges
FLUSH PRIVILEGES;
EOF

    # Execute the SQL script
    if docker exec -i server-panel-mysql mysql -u root -p"$MYSQL_ROOT_PASSWORD" < /tmp/fix_mysql_auth.sql 2>/dev/null; then
        log "MySQL authentication fixed successfully"
    else
        warn "Authentication fix failed, trying with empty password..."
        if docker exec -i server-panel-mysql mysql -u root < /tmp/fix_mysql_auth.sql 2>/dev/null; then
            log "MySQL authentication fixed with empty password"
        else
            error "Failed to fix MySQL authentication"
            return 1
        fi
    fi
    
    # Clean up
    rm -f /tmp/fix_mysql_auth.sql
}

test_mysql_connection() {
    log "Testing MySQL connections..."
    
    # Test root connection
    if docker exec server-panel-mysql mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT 1;" &>/dev/null; then
        log "✅ Root connection successful"
    else
        error "❌ Root connection failed"
        return 1
    fi
    
    # Test panel user connection
    if docker exec server-panel-mysql mysql -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SELECT 1;" &>/dev/null; then
        log "✅ Panel user connection successful"
    else
        error "❌ Panel user connection failed"
        return 1
    fi
    
    # Test database access
    if docker exec server-panel-mysql mysql -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" -e "SHOW TABLES;" &>/dev/null; then
        log "✅ Database access successful"
    else
        error "❌ Database access failed"
        return 1
    fi
}

update_backend_config() {
    log "Updating backend database configuration..."
    
    # Update backend .env file if it exists
    if [[ -f "/opt/server-panel/backend/.env" ]]; then
        sed -i.bak "s/DB_PASSWORD=.*/DB_PASSWORD=$MYSQL_PASSWORD/" /opt/server-panel/backend/.env
        log "Backend configuration updated"
    fi
    
    # Restart backend if running
    if docker ps | grep -q "server-panel-backend"; then
        log "Restarting backend to apply new database config..."
        docker restart server-panel-backend
        sleep 5
    fi
}

show_connection_info() {
    log "MySQL Connection Information:"
    echo ""
    echo -e "${BLUE}📊 Database Details:${NC}"
    echo "   Host: localhost (or server-panel-mysql from containers)"
    echo "   Port: 3306"
    echo "   Root Password: $MYSQL_ROOT_PASSWORD"
    echo "   Database: $MYSQL_DATABASE"
    echo "   Panel User: $MYSQL_USER"
    echo "   Panel Password: $MYSQL_PASSWORD"
    echo ""
    echo -e "${BLUE}🔧 Connection Commands:${NC}"
    echo "   Root: docker exec -it server-panel-mysql mysql -u root -p"
    echo "   Panel User: docker exec -it server-panel-mysql mysql -u $MYSQL_USER -p $MYSQL_DATABASE"
    echo ""
    echo -e "${BLUE}🌐 External Access:${NC}"
    echo "   From host: mysql -h localhost -P 3306 -u $MYSQL_USER -p"
    echo "   From containers: mysql -h server-panel-mysql -u $MYSQL_USER -p"
}

main() {
    echo -e "${BLUE}🔧 MySQL Connection Fix Tool${NC}"
    echo "=================================================="
    
    check_mysql_container
    wait_for_mysql
    fix_mysql_authentication
    test_mysql_connection
    update_backend_config
    show_connection_info
    
    echo ""
    log "✅ MySQL connection fix completed successfully!"
    log "🚀 Your database is now ready to use"
}

# Handle command line arguments
case "${1:-fix}" in
    "fix")
        main
        ;;
    "test")
        test_mysql_connection
        ;;
    "info")
        show_connection_info
        ;;
    "restart")
        log "Restarting MySQL container..."
        docker restart server-panel-mysql
        sleep 10
        wait_for_mysql
        ;;
    *)
        echo "Usage: $0 [fix|test|info|restart]"
        echo "  fix     - Fix MySQL connection issues (default)"
        echo "  test    - Test MySQL connections"
        echo "  info    - Show connection information"
        echo "  restart - Restart MySQL container"
        exit 1
        ;;
esac 