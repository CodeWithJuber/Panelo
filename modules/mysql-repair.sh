#!/bin/bash

# MySQL Repair and Troubleshooting Script
# Fixes common MySQL container issues in server panel

source "$(dirname "$0")/helper.sh" 2>/dev/null || true

MYSQL_CONTAINER_NAME="server-panel-mysql"

# Check and fix MySQL container issues
repair_mysql() {
    log "INFO" "Starting MySQL repair process"
    
    # Check if container exists
    if ! docker ps -a | grep -q "$MYSQL_CONTAINER_NAME"; then
        log "ERROR" "MySQL container not found"
        return 1
    fi
    
    # Get container status
    local container_status
    container_status=$(docker inspect --format='{{.State.Status}}' "$MYSQL_CONTAINER_NAME" 2>/dev/null)
    
    log "INFO" "Current container status: $container_status"
    
    # Check container logs for errors
    log "INFO" "Checking MySQL container logs for errors..."
    docker logs --tail 50 "$MYSQL_CONTAINER_NAME" 2>&1 | tee /tmp/mysql-repair.log
    
    # Common fixes
    fix_mysql_permissions
    fix_mysql_config
    fix_mysql_data_dir
    restart_mysql_container
}

# Fix MySQL file permissions
fix_mysql_permissions() {
    log "INFO" "Fixing MySQL file permissions"
    
    # Stop container if running
    docker stop "$MYSQL_CONTAINER_NAME" 2>/dev/null || true
    
    # Fix data directory permissions
    if [[ -d "/var/server-panel/mysql/data" ]]; then
        chown -R 999:999 /var/server-panel/mysql/data
        chmod -R 755 /var/server-panel/mysql/data
        log "SUCCESS" "Fixed MySQL data directory permissions"
    fi
    
    # Fix logs directory permissions
    if [[ -d "/var/server-panel/mysql/logs" ]]; then
        chown -R 999:999 /var/server-panel/mysql/logs
        chmod -R 755 /var/server-panel/mysql/logs
        log "SUCCESS" "Fixed MySQL logs directory permissions"
    fi
}

# Fix MySQL configuration issues
fix_mysql_config() {
    log "INFO" "Checking MySQL configuration"
    
    local config_file="/var/server-panel/mysql/config/my.cnf"
    
    if [[ -f "$config_file" ]]; then
        # Check for common configuration issues
        if grep -q "query_cache_type" "$config_file"; then
            log "INFO" "Removing deprecated query_cache settings from MySQL 8.0+"
            
            # Create backup
            cp "$config_file" "${config_file}.backup.$(date +%Y%m%d_%H%M%S)"
            
            # Remove deprecated settings for MySQL 8.0+
            sed -i '/query_cache_limit/d' "$config_file"
            sed -i '/query_cache_size/d' "$config_file"
            sed -i '/query_cache_type/d' "$config_file"
            sed -i '/default_table_type/d' "$config_file"
            
            log "SUCCESS" "Removed deprecated MySQL settings"
        fi
        
        # Check memory settings
        local available_mem
        available_mem=$(free -m | awk 'NR==2{printf "%.0f", $7*0.7}')
        
        if [[ $available_mem -lt 256 ]]; then
            log "WARNING" "Low memory detected, adjusting MySQL settings"
            
            # Reduce memory usage
            sed -i 's/innodb_buffer_pool_size = 256M/innodb_buffer_pool_size = 128M/' "$config_file"
            sed -i 's/max_connections = 200/max_connections = 100/' "$config_file"
            
            log "SUCCESS" "Adjusted MySQL memory settings for low memory system"
        fi
    fi
}

# Fix MySQL data directory issues
fix_mysql_data_dir() {
    log "INFO" "Checking MySQL data directory"
    
    local data_dir="/var/server-panel/mysql/data"
    
    # Check if data directory is corrupted or empty
    if [[ -d "$data_dir" ]]; then
        local file_count
        file_count=$(find "$data_dir" -type f | wc -l)
        
        if [[ $file_count -eq 0 ]]; then
            log "WARNING" "MySQL data directory is empty, will reinitialize"
            
            # Remove empty data directory
            rm -rf "$data_dir"
            mkdir -p "$data_dir"
            chown 999:999 "$data_dir"
            chmod 755 "$data_dir"
            
            log "SUCCESS" "Reset MySQL data directory"
        fi
    fi
}

# Restart MySQL container with fresh configuration
restart_mysql_container() {
    log "INFO" "Restarting MySQL container"
    
    # Stop and remove existing container
    docker stop "$MYSQL_CONTAINER_NAME" 2>/dev/null || true
    docker rm "$MYSQL_CONTAINER_NAME" 2>/dev/null || true
    
    # Load MySQL credentials if available
    local mysql_root_password=""
    local mysql_panel_password=""
    
    if [[ -f "/var/server-panel/mysql/credentials.conf" ]]; then
        source /var/server-panel/mysql/credentials.conf
        log "INFO" "Loaded existing MySQL credentials"
    else
        # Generate new passwords
        mysql_root_password=$(generate_password 32)
        mysql_panel_password=$(generate_password 24)
        log "INFO" "Generated new MySQL credentials"
    fi
    
    # Start MySQL container with improved settings
    docker run -d \
        --name "$MYSQL_CONTAINER_NAME" \
        --network server-panel \
        -p "127.0.0.1:3306:3306" \
        -e MYSQL_ROOT_PASSWORD="$mysql_root_password" \
        -e MYSQL_DATABASE="server_panel" \
        -e MYSQL_USER="panel_user" \
        -e MYSQL_PASSWORD="$mysql_panel_password" \
        -v /var/server-panel/mysql/data:/var/lib/mysql \
        -v /var/server-panel/mysql/config/my.cnf:/etc/mysql/conf.d/custom.cnf:ro \
        -v /var/server-panel/mysql/logs:/var/log/mysql \
        --restart unless-stopped \
        --security-opt apparmor:unconfined \
        mysql:8.0 \
        --character-set-server=utf8mb4 \
        --collation-server=utf8mb4_unicode_ci \
        --skip-mysqlx \
        --disable-log-bin
    
    if [[ $? -eq 0 ]]; then
        log "SUCCESS" "MySQL container started successfully"
        
        # Save credentials
        cat > /var/server-panel/mysql/credentials.conf << EOF
MYSQL_ROOT_PASSWORD="$mysql_root_password"
MYSQL_PANEL_PASSWORD="$mysql_panel_password"
MYSQL_PANEL_DB="server_panel"
MYSQL_PANEL_USER="panel_user"
EOF
        chmod 600 /var/server-panel/mysql/credentials.conf
        
        # Wait for MySQL to be ready
        wait_for_mysql_ready
        
        return 0
    else
        log "ERROR" "Failed to start MySQL container"
        return 1
    fi
}

# Wait for MySQL to be ready
wait_for_mysql_ready() {
    log "INFO" "Waiting for MySQL to be ready"
    
    local max_attempts=60
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if docker exec "$MYSQL_CONTAINER_NAME" mysqladmin ping -h localhost --silent 2>/dev/null; then
            log "SUCCESS" "MySQL is ready and responding"
            return 0
        fi
        
        if [[ $((attempt % 10)) -eq 0 ]]; then
            log "INFO" "Still waiting for MySQL... (attempt $attempt/$max_attempts)"
        fi
        
        sleep 2
        ((attempt++))
    done
    
    log "ERROR" "MySQL failed to become ready after $max_attempts attempts"
    log "INFO" "Check logs with: docker logs $MYSQL_CONTAINER_NAME"
    return 1
}

# Quick diagnosis of MySQL issues
diagnose_mysql() {
    log "INFO" "Diagnosing MySQL issues"
    
    echo "=== MySQL Container Status ==="
    docker ps -a | grep "$MYSQL_CONTAINER_NAME" || echo "Container not found"
    
    echo -e "\n=== MySQL Container Logs (last 20 lines) ==="
    docker logs --tail 20 "$MYSQL_CONTAINER_NAME" 2>&1 || echo "Cannot get logs"
    
    echo -e "\n=== System Resources ==="
    free -h
    df -h /var/server-panel/mysql/ 2>/dev/null || echo "MySQL directory not found"
    
    echo -e "\n=== MySQL Data Directory ==="
    ls -la /var/server-panel/mysql/data/ 2>/dev/null || echo "Data directory not found"
    
    echo -e "\n=== MySQL Configuration ==="
    if [[ -f "/var/server-panel/mysql/config/my.cnf" ]]; then
        echo "Configuration file exists"
        grep -E "^(innodb_buffer_pool_size|max_connections)" /var/server-panel/mysql/config/my.cnf 2>/dev/null
    else
        echo "Configuration file not found"
    fi
    
    echo -e "\n=== Network Status ==="
    ss -tuln | grep ":3306" || echo "MySQL port not listening"
}

# Reset MySQL completely (use with caution)
reset_mysql() {
    log "WARNING" "This will completely reset MySQL and delete all data!"
    read -p "Are you sure you want to continue? (y/N): " -r
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "INFO" "Resetting MySQL installation"
        
        # Stop and remove container
        docker stop "$MYSQL_CONTAINER_NAME" 2>/dev/null || true
        docker rm "$MYSQL_CONTAINER_NAME" 2>/dev/null || true
        
        # Remove all MySQL data
        rm -rf /var/server-panel/mysql/data/*
        rm -f /var/server-panel/mysql/credentials.conf
        
        # Reinstall MySQL
        /opt/server-panel/modules/mysql.sh install
        
        log "SUCCESS" "MySQL has been completely reset"
    else
        log "INFO" "Reset cancelled"
    fi
}

# Main execution
main() {
    case "${1:-repair}" in
        "repair"|"fix")
            repair_mysql
            ;;
        "diagnose"|"check")
            diagnose_mysql
            ;;
        "reset")
            reset_mysql
            ;;
        "wait")
            wait_for_mysql_ready
            ;;
        *)
            echo "Usage: $0 [repair|diagnose|reset|wait]"
            echo ""
            echo "Commands:"
            echo "  repair    - Fix common MySQL issues (default)"
            echo "  diagnose  - Show MySQL status and logs"
            echo "  reset     - Completely reset MySQL (destructive)"
            echo "  wait      - Wait for MySQL to become ready"
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 