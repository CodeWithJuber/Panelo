#!/bin/bash

# Backup System Module
# Provides automated backup and restore functionality

# Configuration
BACKUP_DIR="/var/server-panel/backups"
CONFIG_DIR="/var/server-panel/backup-config"
LOG_FILE="/var/log/server-panel/backup.log"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Create backup directories
create_backup_structure() {
    log "INFO" "Creating backup directory structure"
    
    mkdir -p "$BACKUP_DIR"/{databases,files,configs,archives}
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Set permissions
    chmod 700 "$BACKUP_DIR"
    chmod 755 "$CONFIG_DIR"
    
    log "SUCCESS" "Backup directory structure created"
}

# Install backup dependencies
install_backup_tools() {
    log "INFO" "Installing backup tools"
    
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y rsync gzip tar pigz pv mysqldump postgresql-client-common
    elif command -v yum >/dev/null 2>&1; then
        yum install -y rsync gzip tar pigz pv mysql postgresql
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y rsync gzip tar pigz pv mysql postgresql
    fi
    
    log "SUCCESS" "Backup tools installed"
}

# Configure database backup
setup_database_backup() {
    log "INFO" "Setting up database backup configuration"
    
    # MySQL backup configuration
    cat > "$CONFIG_DIR/mysql-backup.conf" << 'EOF'
# MySQL Backup Configuration
MYSQL_HOST="127.0.0.1"
MYSQL_PORT="3306"
MYSQL_USER="root"
MYSQL_PASSWORD_FILE="/var/server-panel/mysql-root-password"
MYSQL_DATABASES="all"
MYSQL_BACKUP_OPTIONS="--single-transaction --routines --triggers --events"
EOF

    # PostgreSQL backup configuration
    cat > "$CONFIG_DIR/postgres-backup.conf" << 'EOF'
# PostgreSQL Backup Configuration
POSTGRES_HOST="127.0.0.1"
POSTGRES_PORT="5432"
POSTGRES_USER="postgres"
POSTGRES_DATABASES="all"
POSTGRES_BACKUP_OPTIONS="--clean --if-exists --create"
EOF

    log "SUCCESS" "Database backup configuration created"
}

# Create backup scripts
create_backup_scripts() {
    log "INFO" "Creating backup scripts"
    
    # Main backup script
    cat > "$BACKUP_DIR/backup-all.sh" << 'EOF'
#!/bin/bash

# Main backup script
source /opt/server-panel/modules/backup.sh

BACKUP_DATE=$(date +"%Y%m%d_%H%M%S")
BACKUP_PATH="/var/server-panel/backups/archives/backup_$BACKUP_DATE"

log "INFO" "Starting full system backup: $BACKUP_DATE"

# Create backup directory
mkdir -p "$BACKUP_PATH"

# Backup databases
backup_databases "$BACKUP_PATH/databases"

# Backup application files
backup_applications "$BACKUP_PATH/applications"

# Backup configurations
backup_configurations "$BACKUP_PATH/configurations"

# Create compressed archive
create_backup_archive "$BACKUP_PATH"

# Cleanup old backups
cleanup_old_backups

log "SUCCESS" "Full system backup completed: $BACKUP_DATE"
EOF

    # Database backup script
    cat > "$BACKUP_DIR/backup-databases.sh" << 'EOF'
#!/bin/bash

# Database backup script
source /opt/server-panel/modules/backup.sh

BACKUP_DATE=$(date +"%Y%m%d_%H%M%S")
BACKUP_PATH="/var/server-panel/backups/databases/db_backup_$BACKUP_DATE"

log "INFO" "Starting database backup: $BACKUP_DATE"

mkdir -p "$BACKUP_PATH"
backup_databases "$BACKUP_PATH"

log "SUCCESS" "Database backup completed: $BACKUP_DATE"
EOF

    # Files backup script
    cat > "$BACKUP_DIR/backup-files.sh" << 'EOF'
#!/bin/bash

# Files backup script
source /opt/server-panel/modules/backup.sh

BACKUP_DATE=$(date +"%Y%m%d_%H%M%S")
BACKUP_PATH="/var/server-panel/backups/files/files_backup_$BACKUP_DATE"

log "INFO" "Starting files backup: $BACKUP_DATE"

mkdir -p "$BACKUP_PATH"
backup_applications "$BACKUP_PATH"

log "SUCCESS" "Files backup completed: $BACKUP_DATE"
EOF

    # Make scripts executable
    chmod +x "$BACKUP_DIR"/*.sh
    
    log "SUCCESS" "Backup scripts created"
}

# Backup databases function
backup_databases() {
    local backup_path="$1"
    mkdir -p "$backup_path"
    
    log "INFO" "Backing up databases to $backup_path"
    
    # MySQL backup
    if docker ps --format "table {{.Names}}" | grep -q "server-panel-mysql"; then
        log "INFO" "Backing up MySQL databases"
        
        # Get MySQL root password
        local mysql_password=""
        if [[ -f "/var/server-panel/mysql-root-password" ]]; then
            mysql_password=$(cat /var/server-panel/mysql-root-password)
        fi
        
        # Backup all databases
        docker exec server-panel-mysql mysqldump \
            --user=root \
            --password="$mysql_password" \
            --all-databases \
            --single-transaction \
            --routines \
            --triggers \
            --events | gzip > "$backup_path/mysql_all_databases_$(date +%Y%m%d_%H%M%S).sql.gz"
        
        if [[ $? -eq 0 ]]; then
            log "SUCCESS" "MySQL backup completed"
        else
            log "ERROR" "MySQL backup failed"
        fi
    fi
    
    # PostgreSQL backup
    if docker ps --format "table {{.Names}}" | grep -q "server-panel-postgres"; then
        log "INFO" "Backing up PostgreSQL databases"
        
        docker exec server-panel-postgres pg_dumpall \
            --username=postgres | gzip > "$backup_path/postgres_all_databases_$(date +%Y%m%d_%H%M%S).sql.gz"
        
        if [[ $? -eq 0 ]]; then
            log "SUCCESS" "PostgreSQL backup completed"
        else
            log "ERROR" "PostgreSQL backup failed"
        fi
    fi
}

# Backup application files
backup_applications() {
    local backup_path="$1"
    mkdir -p "$backup_path"
    
    log "INFO" "Backing up application files to $backup_path"
    
    # Backup user applications
    if [[ -d "/var/server-panel/apps" ]]; then
        tar -czf "$backup_path/applications_$(date +%Y%m%d_%H%M%S).tar.gz" \
            -C /var/server-panel apps/ 2>/dev/null
        
        if [[ $? -eq 0 ]]; then
            log "SUCCESS" "Applications backup completed"
        else
            log "ERROR" "Applications backup failed"
        fi
    fi
    
    # Backup web files
    if [[ -d "/var/www" ]]; then
        tar -czf "$backup_path/webfiles_$(date +%Y%m%d_%H%M%S).tar.gz" \
            -C /var www/ 2>/dev/null
        
        if [[ $? -eq 0 ]]; then
            log "SUCCESS" "Web files backup completed"
        else
            log "ERROR" "Web files backup failed"
        fi
    fi
}

# Backup configurations
backup_configurations() {
    local backup_path="$1"
    mkdir -p "$backup_path"
    
    log "INFO" "Backing up configurations to $backup_path"
    
    # Backup server panel configuration
    tar -czf "$backup_path/panel_config_$(date +%Y%m%d_%H%M%S).tar.gz" \
        -C /opt server-panel/ 2>/dev/null
    
    # Backup web server configurations
    if [[ -d "/etc/nginx" ]]; then
        tar -czf "$backup_path/nginx_config_$(date +%Y%m%d_%H%M%S).tar.gz" \
            -C /etc nginx/ 2>/dev/null
    fi
    
    if [[ -d "/etc/apache2" ]]; then
        tar -czf "$backup_path/apache_config_$(date +%Y%m%d_%H%M%S).tar.gz" \
            -C /etc apache2/ 2>/dev/null
    fi
    
    # Backup SSL certificates
    if [[ -d "/etc/letsencrypt" ]]; then
        tar -czf "$backup_path/ssl_certs_$(date +%Y%m%d_%H%M%S).tar.gz" \
            -C /etc letsencrypt/ 2>/dev/null
    fi
    
    log "SUCCESS" "Configurations backup completed"
}

# Create compressed backup archive
create_backup_archive() {
    local backup_path="$1"
    local archive_name="$(basename "$backup_path").tar.gz"
    local archive_path="$(dirname "$backup_path")/$archive_name"
    
    log "INFO" "Creating compressed archive: $archive_name"
    
    tar -czf "$archive_path" -C "$(dirname "$backup_path")" "$(basename "$backup_path")"
    
    if [[ $? -eq 0 ]]; then
        # Remove uncompressed backup directory
        rm -rf "$backup_path"
        log "SUCCESS" "Archive created: $archive_path"
    else
        log "ERROR" "Failed to create archive"
    fi
}

# Cleanup old backups
cleanup_old_backups() {
    log "INFO" "Cleaning up backups older than $RETENTION_DAYS days"
    
    # Clean up archives
    find "$BACKUP_DIR/archives" -name "backup_*.tar.gz" -mtime +$RETENTION_DAYS -delete 2>/dev/null
    
    # Clean up database backups
    find "$BACKUP_DIR/databases" -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete 2>/dev/null
    
    # Clean up file backups
    find "$BACKUP_DIR/files" -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete 2>/dev/null
    
    log "SUCCESS" "Old backups cleaned up"
}

# Setup automated backup scheduling
setup_backup_scheduling() {
    log "INFO" "Setting up automated backup scheduling"
    
    # Create cron job for daily backups
    cat > /etc/cron.d/server-panel-backup << 'EOF'
# Server Panel Automated Backups
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Daily full backup at 2:00 AM
0 2 * * * root /var/server-panel/backups/backup-all.sh >/dev/null 2>&1

# Database backup every 6 hours
0 */6 * * * root /var/server-panel/backups/backup-databases.sh >/dev/null 2>&1
EOF

    # Restart cron service
    systemctl restart cron 2>/dev/null || systemctl restart crond 2>/dev/null || true
    
    log "SUCCESS" "Backup scheduling configured"
}

# Create restore script
create_restore_script() {
    log "INFO" "Creating restore script"
    
    cat > "$BACKUP_DIR/restore.sh" << 'EOF'
#!/bin/bash

# Restore script
BACKUP_DIR="/var/server-panel/backups"

usage() {
    echo "Usage: $0 [options] <backup_file>"
    echo "Options:"
    echo "  -d, --databases    Restore databases only"
    echo "  -f, --files        Restore files only"
    echo "  -c, --configs      Restore configurations only"
    echo "  -a, --all          Restore everything (default)"
    echo "  -l, --list         List available backups"
    echo "  -h, --help         Show this help"
}

list_backups() {
    echo "Available backups:"
    ls -la "$BACKUP_DIR/archives/"*.tar.gz 2>/dev/null | awk '{print $9, $5, $6, $7, $8}'
}

restore_backup() {
    local backup_file="$1"
    local restore_type="${2:-all}"
    
    if [[ ! -f "$backup_file" ]]; then
        echo "Error: Backup file not found: $backup_file"
        exit 1
    fi
    
    echo "Restoring from: $backup_file"
    echo "Restore type: $restore_type"
    
    # Extract backup
    local temp_dir="/tmp/restore_$(date +%s)"
    mkdir -p "$temp_dir"
    tar -xzf "$backup_file" -C "$temp_dir"
    
    echo "Backup extracted to: $temp_dir"
    echo "Manual restore required - backup contents available in $temp_dir"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -l|--list)
            list_backups
            exit 0
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -d|--databases)
            RESTORE_TYPE="databases"
            shift
            ;;
        -f|--files)
            RESTORE_TYPE="files"
            shift
            ;;
        -c|--configs)
            RESTORE_TYPE="configs"
            shift
            ;;
        -a|--all)
            RESTORE_TYPE="all"
            shift
            ;;
        *)
            BACKUP_FILE="$1"
            shift
            ;;
    esac
done

if [[ -z "$BACKUP_FILE" ]]; then
    usage
    exit 1
fi

restore_backup "$BACKUP_FILE" "${RESTORE_TYPE:-all}"
EOF

    chmod +x "$BACKUP_DIR/restore.sh"
    
    log "SUCCESS" "Restore script created"
}

# Main installation function
main() {
    log "INFO" "Installing automated backup system"
    
    create_backup_structure
    install_backup_tools
    setup_database_backup
    create_backup_scripts
    setup_backup_scheduling
    create_restore_script
    
    log "SUCCESS" "Automated backup system installation completed"
    
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Backup System Installation Complete! ${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${BLUE}Backup Configuration:${NC}"
    echo -e "• Backup Directory: $BACKUP_DIR"
    echo -e "• Retention Period: $RETENTION_DAYS days"
    echo -e "• Daily Full Backup: 2:00 AM"
    echo -e "• Database Backup: Every 6 hours"
    echo ""
    echo -e "${BLUE}Management Commands:${NC}"
    echo -e "• Manual Full Backup: $BACKUP_DIR/backup-all.sh"
    echo -e "• Database Backup: $BACKUP_DIR/backup-databases.sh"
    echo -e "• Files Backup: $BACKUP_DIR/backup-files.sh"
    echo -e "• List Backups: $BACKUP_DIR/restore.sh --list"
    echo -e "• Restore Backup: $BACKUP_DIR/restore.sh <backup_file>"
    echo -e "• View Logs: tail -f $LOG_FILE"
    echo ""
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 