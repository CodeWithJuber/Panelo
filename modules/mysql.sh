#!/bin/bash

# MySQL Installation Module
# Sets up MySQL database with Docker for server panel

source "$(dirname "$0")/helper.sh" 2>/dev/null || true

# MySQL configuration
MYSQL_ROOT_PASSWORD=""
MYSQL_PANEL_DB="server_panel"
MYSQL_PANEL_USER="panel_user"
MYSQL_PANEL_PASSWORD=""
MYSQL_VERSION="8.0"
MYSQL_PORT="3306"
MYSQL_CONTAINER_NAME="server-panel-mysql"

install_mysql() {
    log "INFO" "Starting MySQL installation with Docker"
    
    # Check if Docker is available
    if ! check_docker; then
        log "ERROR" "Docker is required for MySQL installation"
        return 1
    fi
    
    # Generate passwords
    generate_mysql_passwords
    
    # Create MySQL directories
    setup_mysql_directories
    
    # Create MySQL configuration
    create_mysql_config
    
    # Try MySQL first, fallback to MariaDB if it fails
    if ! deploy_mysql_container || ! wait_for_mysql; then
        log "WARNING" "MySQL 8.0 failed to start, trying MariaDB as fallback"
        
        # Clean up failed MySQL container
        docker stop "$MYSQL_CONTAINER_NAME" 2>/dev/null || true
        docker rm "$MYSQL_CONTAINER_NAME" 2>/dev/null || true
        rm -rf /var/server-panel/mysql/data/*
        
        # Try MariaDB instead
        MYSQL_VERSION="mariadb:10.11"
        if ! deploy_mysql_container || ! wait_for_mysql; then
            log "ERROR" "Both MySQL and MariaDB failed to start"
            return 1
        fi
        
        log "SUCCESS" "MariaDB started successfully as MySQL alternative"
    fi
    
    # Create databases and users
    setup_panel_database
    
    # Create backup script
    create_backup_script
    
    # Verify installation
    verify_mysql_installation
    
    # Save credentials
    save_mysql_credentials
}

generate_mysql_passwords() {
    log "INFO" "Generating MySQL passwords"
    
    # Use fixed passwords for reliability
    MYSQL_ROOT_PASSWORD="root_password_123"
    MYSQL_PANEL_PASSWORD="panel_password_123"
    
    log "SUCCESS" "MySQL passwords set"
}

setup_mysql_directories() {
    log "INFO" "Setting up MySQL directories"
    
    # Create data directories
    create_directory "/var/server-panel/mysql" "root" "root" "700"
    create_directory "/var/server-panel/mysql/data" "999" "999" "755"
    create_directory "/var/server-panel/mysql/config" "root" "root" "755"
    create_directory "/var/server-panel/mysql/backups" "root" "root" "700"
    create_directory "/var/server-panel/mysql/logs" "999" "999" "755"
    
    log "SUCCESS" "MySQL directories created"
}

create_mysql_config() {
    log "INFO" "Creating MySQL configuration"
    
    # Check available memory and adjust settings accordingly
    local available_mem
    available_mem=$(free -m | awk 'NR==2{printf "%.0f", $7*0.7}')
    
    local innodb_buffer_size="128M"
    local max_connections="100"
    local thread_cache_size="64"
    
    if [[ $available_mem -gt 1024 ]]; then
        innodb_buffer_size="256M"
        max_connections="200"
        thread_cache_size="128"
    elif [[ $available_mem -gt 2048 ]]; then
        innodb_buffer_size="512M"
        max_connections="300"
        thread_cache_size="256"
    fi
    
    log "INFO" "Configuring MySQL for ${available_mem}MB available memory"
    log "INFO" "Setting InnoDB buffer pool to $innodb_buffer_size"
    
    # Create optimized MySQL configuration for MySQL 8.0+
    cat > /var/server-panel/mysql/config/my.cnf << EOF
[mysqld]
# Basic Settings
user = mysql
default-storage-engine = InnoDB
socket = /var/run/mysqld/mysqld.sock
pid-file = /var/run/mysqld/mysqld.pid

# Connection Settings
bind-address = 0.0.0.0
port = 3306
max_connections = $max_connections
connect_timeout = 60
wait_timeout = 120
max_allowed_packet = 64M
thread_cache_size = $thread_cache_size
sort_buffer_size = 2M
bulk_insert_buffer_size = 8M
tmp_table_size = 16M
max_heap_table_size = 16M

# Logging
log_error = /var/log/mysql/error.log
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 2

# InnoDB Settings (MySQL 8.0 optimized)
innodb_buffer_pool_size = $innodb_buffer_size
innodb_log_buffer_size = 1M
innodb_file_per_table = 1
innodb_open_files = 300
innodb_io_capacity = 200
innodb_flush_method = O_DIRECT
innodb_log_file_size = 48M
innodb_flush_log_at_trx_commit = 2

# Security
local-infile = 0
skip-symbolic-links
skip-name-resolve

# Character Set
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

# MySQL 8.0 specific optimizations
mysqlx = OFF
skip-log-bin
default-authentication-plugin = mysql_native_password

[mysql]
default-character-set = utf8mb4

[client]
default-character-set = utf8mb4
EOF
    
    log "SUCCESS" "MySQL configuration created with optimized settings"
}

deploy_mysql_container() {
    log "INFO" "Deploying MySQL container"
    
    # Stop and remove existing container if it exists
    docker stop "$MYSQL_CONTAINER_NAME" 2>/dev/null || true
    docker rm "$MYSQL_CONTAINER_NAME" 2>/dev/null || true
    
    # Clean any orphaned volumes
    docker volume prune -f 2>/dev/null || true
    
    # Check if data directory is corrupted and clean if necessary
    if [[ -d "/var/server-panel/mysql/data" ]]; then
        local file_count
        file_count=$(find /var/server-panel/mysql/data -type f | wc -l)
        
        # If data directory has files but no mysql directory, it's corrupted
        if [[ $file_count -gt 0 ]] && [[ ! -d "/var/server-panel/mysql/data/mysql" ]]; then
            log "WARNING" "Detected corrupted MySQL data directory, cleaning..."
            rm -rf /var/server-panel/mysql/data/*
            log "SUCCESS" "Cleaned corrupted data directory"
        fi
    fi
    
    # Ensure proper permissions
    chown -R 999:999 /var/server-panel/mysql/data /var/server-panel/mysql/logs 2>/dev/null || true
    chmod -R 755 /var/server-panel/mysql/data /var/server-panel/mysql/logs 2>/dev/null || true
    
    # Determine if we're using MySQL or MariaDB
    local db_image="mysql:$MYSQL_VERSION"
    local extra_args=""
    
    if [[ "$MYSQL_VERSION" == mariadb:* ]]; then
        db_image="$MYSQL_VERSION"
        extra_args="--character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci"
    else
        extra_args="--character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci --skip-mysqlx --disable-log-bin"
    fi
    
    log "INFO" "Starting database container: $db_image"
    
    # Create and start MySQL/MariaDB container
    docker run -d \
        --name "$MYSQL_CONTAINER_NAME" \
        --network server-panel \
        -p "127.0.0.1:${MYSQL_PORT}:3306" \
        -e MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" \
        -e MYSQL_DATABASE="$MYSQL_PANEL_DB" \
        -e MYSQL_USER="$MYSQL_PANEL_USER" \
        -e MYSQL_PASSWORD="$MYSQL_PANEL_PASSWORD" \
        -v /var/server-panel/mysql/data:/var/lib/mysql \
        -v /var/server-panel/mysql/config/my.cnf:/etc/mysql/conf.d/custom.cnf:ro \
        -v /var/server-panel/mysql/logs:/var/log/mysql \
        --restart unless-stopped \
        --security-opt apparmor:unconfined \
        $db_image \
        $extra_args
    
    if [[ $? -eq 0 ]]; then
        log "SUCCESS" "MySQL container deployed successfully"
    else
        log "ERROR" "Failed to deploy MySQL container"
        return 1
    fi
}

wait_for_mysql() {
    log "INFO" "Waiting for MySQL to be ready"
    
    local max_attempts=60
    local attempt=1
    local container_status
    
    while [[ $attempt -le $max_attempts ]]; do
        # Check if container is still running
        container_status=$(docker inspect --format='{{.State.Status}}' "$MYSQL_CONTAINER_NAME" 2>/dev/null || echo "not_found")
        
        if [[ "$container_status" == "exited" ]]; then
            log "ERROR" "MySQL container exited unexpectedly"
            log "INFO" "Container logs:"
            docker logs --tail 20 "$MYSQL_CONTAINER_NAME"
            return 1
        elif [[ "$container_status" == "restarting" ]]; then
            if [[ $((attempt % 10)) -eq 0 ]]; then
                log "WARNING" "MySQL container is restarting (attempt $attempt/$max_attempts)"
                log "INFO" "Recent logs:"
                docker logs --tail 5 "$MYSQL_CONTAINER_NAME" 2>/dev/null || true
            fi
        elif [[ "$container_status" == "running" ]]; then
            # Container is running, check if MySQL is responding
            if docker exec "$MYSQL_CONTAINER_NAME" mysqladmin ping -h localhost --silent 2>/dev/null; then
                log "SUCCESS" "MySQL is ready and responding"
                return 0
            fi
        fi
        
        if [[ $((attempt % 15)) -eq 0 ]]; then
            log "INFO" "Still waiting for MySQL... (attempt $attempt/$max_attempts, status: $container_status)"
        fi
        
        sleep 2
        ((attempt++))
    done
    
    log "ERROR" "MySQL failed to start after $max_attempts attempts"
    log "INFO" "Final container status: $container_status"
    log "INFO" "Use 'docker logs $MYSQL_CONTAINER_NAME' to check error details"
    return 1
}

setup_panel_database() {
    log "INFO" "Setting up panel database and users"
    
    # Wait for MySQL to be fully ready
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if docker exec "$MYSQL_CONTAINER_NAME" mysqladmin ping -h localhost --silent 2>/dev/null; then
            log "SUCCESS" "MySQL is ready for database setup"
            break
        fi
        log "INFO" "Waiting for MySQL to be ready (attempt $attempt/$max_attempts)..."
        sleep 2
        ((attempt++))
    done
    
    if [[ $attempt -gt $max_attempts ]]; then
        log "ERROR" "MySQL failed to become ready for database setup"
        return 1
    fi
    
    # Create SQL script for better error handling
    cat > /tmp/setup_panel_db.sql << EOF
-- Fix root user authentication first
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';
ALTER USER 'root'@'%' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';

-- Create main panel database
CREATE DATABASE IF NOT EXISTS server_panel;
CREATE DATABASE IF NOT EXISTS server_panel_apps;
CREATE DATABASE IF NOT EXISTS server_panel_metrics;

-- Create panel admin user with full privileges
DROP USER IF EXISTS 'panel_admin'@'%';
CREATE USER 'panel_admin'@'%' IDENTIFIED WITH mysql_native_password BY '$MYSQL_PANEL_PASSWORD';
GRANT ALL PRIVILEGES ON server_panel.* TO 'panel_admin'@'%';
GRANT ALL PRIVILEGES ON server_panel_apps.* TO 'panel_admin'@'%';
GRANT ALL PRIVILEGES ON server_panel_metrics.* TO 'panel_admin'@'%';

-- Create panel user (for backend)
DROP USER IF EXISTS 'panel_user'@'%';
CREATE USER 'panel_user'@'%' IDENTIFIED WITH mysql_native_password BY '$MYSQL_PANEL_PASSWORD';
GRANT ALL PRIVILEGES ON server_panel.* TO 'panel_user'@'%';

-- Create backup user
DROP USER IF EXISTS 'backup_user'@'localhost';
CREATE USER 'backup_user'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_PANEL_PASSWORD';
GRANT SELECT, LOCK TABLES, SHOW VIEW, EVENT, TRIGGER ON *.* TO 'backup_user'@'localhost';

-- Create monitoring user
DROP USER IF EXISTS 'monitor_user'@'%';
CREATE USER 'monitor_user'@'%' IDENTIFIED WITH mysql_native_password BY '$MYSQL_PANEL_PASSWORD';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'monitor_user'@'%';

-- Create panel tables
USE server_panel;

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
    
    # Execute the SQL script with proper error handling
    if docker exec -i "$MYSQL_CONTAINER_NAME" mysql -u root -p"$MYSQL_ROOT_PASSWORD" < /tmp/setup_panel_db.sql 2>/dev/null; then
        log "SUCCESS" "Panel database setup completed"
    else
        log "WARNING" "Initial setup failed, trying with empty password..."
        if docker exec -i "$MYSQL_CONTAINER_NAME" mysql -u root < /tmp/setup_panel_db.sql 2>/dev/null; then
            log "SUCCESS" "Panel database setup completed with empty password"
        else
            log "ERROR" "Failed to setup panel database"
            rm -f /tmp/setup_panel_db.sql
            return 1
        fi
    fi
    
    # Clean up SQL script
    rm -f /tmp/setup_panel_db.sql
    
    # Test the connection
    if docker exec "$MYSQL_CONTAINER_NAME" mysql -u panel_admin -p"$MYSQL_PANEL_PASSWORD" -e "USE server_panel; SHOW TABLES;" &>/dev/null; then
        log "SUCCESS" "Database connection test passed"
    else
        log "ERROR" "Database connection test failed"
        return 1
    fi
}

create_backup_script() {
    log "INFO" "Creating MySQL backup script"
    
    cat > /var/server-panel/mysql/backup.sh << 'EOF'
#!/bin/bash

# MySQL Backup Script for Server Panel
# Usage: ./backup.sh [database_name] [backup_type]

source /opt/server-panel/modules/helper.sh

BACKUP_DIR="/var/server-panel/mysql/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CONTAINER_NAME="server-panel-mysql"

# Load MySQL credentials
if [[ -f /var/server-panel/mysql/credentials.conf ]]; then
    source /var/server-panel/mysql/credentials.conf
else
    log "ERROR" "MySQL credentials not found"
    exit 1
fi

backup_database() {
    local db_name="$1"
    local backup_type="${2:-full}"
    local backup_file="${BACKUP_DIR}/${db_name}_${backup_type}_${TIMESTAMP}.sql"
    
    log "INFO" "Creating backup for database: $db_name"
    
    case "$backup_type" in
        "schema")
            docker exec "$CONTAINER_NAME" mysqldump \
                -u backup_user -p"$MYSQL_PANEL_PASSWORD" \
                --no-data --routines --triggers \
                "$db_name" > "$backup_file"
            ;;
        "data")
            docker exec "$CONTAINER_NAME" mysqldump \
                -u backup_user -p"$MYSQL_PANEL_PASSWORD" \
                --no-create-info --skip-triggers \
                "$db_name" > "$backup_file"
            ;;
        "full"|*)
            docker exec "$CONTAINER_NAME" mysqldump \
                -u backup_user -p"$MYSQL_PANEL_PASSWORD" \
                --single-transaction --routines --triggers \
                "$db_name" > "$backup_file"
            ;;
    esac
    
    if [[ $? -eq 0 ]]; then
        # Compress backup
        gzip "$backup_file"
        log "SUCCESS" "Backup created: ${backup_file}.gz"
        
        # Set proper permissions
        chmod 600 "${backup_file}.gz"
        
        return 0
    else
        log "ERROR" "Failed to create backup for $db_name"
        rm -f "$backup_file"
        return 1
    fi
}

backup_all_databases() {
    log "INFO" "Creating backup for all databases"
    
    # Get list of databases
    local databases
    databases=$(docker exec "$CONTAINER_NAME" mysql \
        -u backup_user -p"$MYSQL_PANEL_PASSWORD" \
        -e "SHOW DATABASES;" | grep -Ev '^(Database|information_schema|performance_schema|mysql|sys)$')
    
    local success_count=0
    local total_count=0
    
    for db in $databases; do
        ((total_count++))
        if backup_database "$db" "full"; then
            ((success_count++))
        fi
    done
    
    log "INFO" "Backup completed: $success_count/$total_count databases"
}

cleanup_old_backups() {
    local retention_days="${1:-7}"
    
    log "INFO" "Cleaning up backups older than $retention_days days"
    
    find "$BACKUP_DIR" -name "*.sql.gz" -mtime +$retention_days -delete
    
    log "SUCCESS" "Old backups cleaned up"
}

restore_database() {
    local backup_file="$1"
    local target_db="$2"
    
    if [[ ! -f "$backup_file" ]]; then
        log "ERROR" "Backup file not found: $backup_file"
        return 1
    fi
    
    log "INFO" "Restoring database $target_db from $backup_file"
    
    # Decompress if needed
    if [[ "$backup_file" == *.gz ]]; then
        gunzip -c "$backup_file" | docker exec -i "$CONTAINER_NAME" mysql \
            -u root -p"$MYSQL_ROOT_PASSWORD" "$target_db"
    else
        docker exec -i "$CONTAINER_NAME" mysql \
            -u root -p"$MYSQL_ROOT_PASSWORD" "$target_db" < "$backup_file"
    fi
    
    if [[ $? -eq 0 ]]; then
        log "SUCCESS" "Database restored successfully"
    else
        log "ERROR" "Failed to restore database"
        return 1
    fi
}

main() {
    case "${1:-all}" in
        "all")
            backup_all_databases
            cleanup_old_backups
            ;;
        "cleanup")
            cleanup_old_backups "$2"
            ;;
        "restore")
            restore_database "$2" "$3"
            ;;
        *)
            backup_database "$1" "$2"
            ;;
    esac
}

main "$@"
EOF
    
    chmod +x /var/server-panel/mysql/backup.sh
    
    # Create daily backup cron job
    cat > /etc/cron.d/mysql-backup << 'EOF'
# MySQL backup for server panel
0 2 * * * root /var/server-panel/mysql/backup.sh all >/dev/null 2>&1
EOF
    
    log "SUCCESS" "MySQL backup script created"
}

verify_mysql_installation() {
    log "INFO" "Verifying MySQL installation"
    
    # Check if container is running
    if docker ps | grep -q "$MYSQL_CONTAINER_NAME"; then
        log "SUCCESS" "MySQL container is running"
    else
        log "ERROR" "MySQL container is not running"
        return 1
    fi
    
    # Check MySQL version
    local mysql_version
    mysql_version=$(docker exec "$MYSQL_CONTAINER_NAME" mysql --version)
    log "INFO" "MySQL version: $mysql_version"
    
    # Test connection
    if docker exec "$MYSQL_CONTAINER_NAME" mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT 1;" &>/dev/null; then
        log "SUCCESS" "MySQL root connection test passed"
    else
        log "ERROR" "MySQL root connection test failed"
        return 1
    fi
    
    # Test panel user connection
    if docker exec "$MYSQL_CONTAINER_NAME" mysql -u "$MYSQL_PANEL_USER" -p"$MYSQL_PANEL_PASSWORD" -D "$MYSQL_PANEL_DB" -e "SELECT 1;" &>/dev/null; then
        log "SUCCESS" "MySQL panel user connection test passed"
    else
        log "ERROR" "MySQL panel user connection test failed"
        return 1
    fi
    
    log "SUCCESS" "MySQL installation verification completed"
}

save_mysql_credentials() {
    log "INFO" "Saving MySQL credentials"
    
    cat > /var/server-panel/mysql/credentials.conf << EOF
# MySQL Credentials for Server Panel
MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD"
MYSQL_PANEL_DB="$MYSQL_PANEL_DB"
MYSQL_PANEL_USER="$MYSQL_PANEL_USER"
MYSQL_PANEL_PASSWORD="$MYSQL_PANEL_PASSWORD"
MYSQL_HOST="127.0.0.1"
MYSQL_PORT="$MYSQL_PORT"
MYSQL_CONTAINER_NAME="$MYSQL_CONTAINER_NAME"
EOF
    
    chmod 600 /var/server-panel/mysql/credentials.conf
    
    # Create connection string for applications
    cat > /var/server-panel/mysql/connection.env << EOF
DATABASE_URL="mysql://$MYSQL_PANEL_USER:$MYSQL_PANEL_PASSWORD@127.0.0.1:$MYSQL_PORT/$MYSQL_PANEL_DB"
MYSQL_HOST=127.0.0.1
MYSQL_PORT=$MYSQL_PORT
MYSQL_DATABASE=$MYSQL_PANEL_DB
MYSQL_USERNAME=$MYSQL_PANEL_USER
MYSQL_PASSWORD=$MYSQL_PANEL_PASSWORD
EOF
    
    chmod 600 /var/server-panel/mysql/connection.env
    
    log "SUCCESS" "MySQL credentials saved"
}

# Create database for application
create_app_database() {
    local app_name="$1"
    local db_user="$2"
    local db_password="$3"
    
    if [[ -z "$app_name" ]] || [[ -z "$db_user" ]] || [[ -z "$db_password" ]]; then
        log "ERROR" "App name, database user, and password are required"
        return 1
    fi
    
    local db_name="app_${app_name}"
    
    log "INFO" "Creating database for application: $app_name"
    
    # Load MySQL credentials
    source /var/server-panel/mysql/credentials.conf
    
    # Create database and user
    docker exec "$MYSQL_CONTAINER_NAME" mysql -u root -p"$MYSQL_ROOT_PASSWORD" << EOF
CREATE DATABASE IF NOT EXISTS $db_name;
CREATE USER IF NOT EXISTS '$db_user'@'%' IDENTIFIED BY '$db_password';
GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user'@'%';
FLUSH PRIVILEGES;
EOF
    
    if [[ $? -eq 0 ]]; then
        log "SUCCESS" "Database created for application: $app_name"
        echo "Database: $db_name, User: $db_user, Password: $db_password"
    else
        log "ERROR" "Failed to create database for application: $app_name"
        return 1
    fi
}

# Remove database for application
remove_app_database() {
    local app_name="$1"
    local db_user="$2"
    
    if [[ -z "$app_name" ]] || [[ -z "$db_user" ]]; then
        log "ERROR" "App name and database user are required"
        return 1
    fi
    
    local db_name="app_${app_name}"
    
    log "INFO" "Removing database for application: $app_name"
    
    # Load MySQL credentials
    source /var/server-panel/mysql/credentials.conf
    
    # Backup before deletion
    /var/server-panel/mysql/backup.sh "$db_name" "full"
    
    # Remove database and user
    docker exec "$MYSQL_CONTAINER_NAME" mysql -u root -p"$MYSQL_ROOT_PASSWORD" << EOF
DROP DATABASE IF EXISTS $db_name;
DROP USER IF EXISTS '$db_user'@'%';
FLUSH PRIVILEGES;
EOF
    
    if [[ $? -eq 0 ]]; then
        log "SUCCESS" "Database removed for application: $app_name"
    else
        log "ERROR" "Failed to remove database for application: $app_name"
        return 1
    fi
}

# Get MySQL status
get_mysql_status() {
    if ! docker ps | grep -q "$MYSQL_CONTAINER_NAME"; then
        echo "stopped"
        return 1
    fi
    
    if docker exec "$MYSQL_CONTAINER_NAME" mysqladmin ping -h localhost --silent; then
        echo "running"
        return 0
    else
        echo "error"
        return 1
    fi
}

# Main execution
main() {
    case "${1:-install}" in
        "install")
            install_mysql
            ;;
        "create-db")
            create_app_database "$2" "$3" "$4"
            ;;
        "remove-db")
            remove_app_database "$2" "$3"
            ;;
        "backup")
            /var/server-panel/mysql/backup.sh "$2" "$3"
            ;;
        "status")
            get_mysql_status
            ;;
        *)
            echo "Usage: $0 [install|create-db|remove-db|backup|status]"
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 