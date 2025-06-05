#!/bin/bash

# File Manager Installation Module
# Sets up FileBrowser for web-based file management

source "$(dirname "$0")/helper.sh" 2>/dev/null || true

# File Manager configuration
FILEBROWSER_VERSION="2.24.1"
FILEBROWSER_PORT="8080"
FILEBROWSER_CONTAINER_NAME="server-panel-filemanager"
FILEBROWSER_CONFIG_DIR="/var/server-panel/filemanager"
FILEBROWSER_DATA_DIR="/var/server-panel/users"

install_filemanager() {
    log "INFO" "Starting File Manager installation"
    
    # Check if Docker is available
    if ! check_docker; then
        log "ERROR" "Docker is required for File Manager installation"
        return 1
    fi
    
    # Create directories
    setup_filemanager_directories
    
    # Create configuration
    create_filemanager_config
    
    # Deploy File Manager container
    deploy_filemanager_container
    
    # Wait for File Manager to be ready
    wait_for_filemanager
    
    # Setup users and permissions
    setup_filemanager_users
    
    # Verify installation
    verify_filemanager_installation
    
    log "SUCCESS" "File Manager installation completed"
}

setup_filemanager_directories() {
    log "INFO" "Setting up File Manager directories"
    
    # Create configuration and data directories
    create_directory "$FILEBROWSER_CONFIG_DIR" "root" "root" "755"
    create_directory "$FILEBROWSER_DATA_DIR" "root" "root" "755"
    create_directory "/var/server-panel/apps" "root" "root" "755"
    
    # Create user directories structure
    create_directory "$FILEBROWSER_DATA_DIR/shared" "www-data" "www-data" "755"
    create_directory "$FILEBROWSER_DATA_DIR/templates" "www-data" "www-data" "755"
    
    log "SUCCESS" "File Manager directories created"
}

create_filemanager_config() {
    log "INFO" "Creating File Manager configuration"
    
    # Create FileBrowser configuration
    cat > "$FILEBROWSER_CONFIG_DIR/config.json" << 'EOF'
{
    "port": 80,
    "baseURL": "",
    "address": "0.0.0.0",
    "log": "stdout",
    "database": "/config/filebrowser.db",
    "root": "/srv",
    "noAuth": false,
    "signup": false,
    "createUserDir": true,
    "userHomeBasePath": "/srv/users",
    "defaults": {
        "scope": "/srv/users",
        "locale": "en",
        "viewMode": "list",
        "singleClick": false,
        "sorting": {
            "by": "name",
            "asc": true
        },
        "perm": {
            "admin": false,
            "execute": true,
            "create": true,
            "rename": true,
            "modify": true,
            "delete": true,
            "share": true,
            "download": true
        },
        "commands": [
            "git",
            "nano",
            "vim",
            "cat",
            "ls",
            "du",
            "find",
            "grep",
            "head",
            "tail",
            "chmod",
            "chown"
        ],
        "hideDotfiles": false
    },
    "branding": {
        "name": "Server Panel File Manager",
        "disableExternal": false
    }
}
EOF
    
    # Create custom CSS for branding
    cat > "$FILEBROWSER_CONFIG_DIR/custom.css" << 'EOF'
/* Custom styling for Server Panel File Manager */
.header {
    background-color: #2c3e50;
}

.header h1 {
    color: #ecf0f1;
}

.sidebar {
    background-color: #34495e;
}

.button--flat {
    background-color: #3498db;
    color: white;
}

.button--flat:hover {
    background-color: #2980b9;
}

/* File manager specific styles */
.item {
    border-bottom: 1px solid #ecf0f1;
}

.item:hover {
    background-color: #f8f9fa;
}

/* Upload area */
.upload {
    border: 2px dashed #3498db;
    background-color: #f8f9fa;
}

.upload.dragover {
    border-color: #2980b9;
    background-color: #e3f2fd;
}
EOF
    
    # Create startup script
    cat > "$FILEBROWSER_CONFIG_DIR/setup.sh" << 'EOF'
#!/bin/bash

# Wait for database to be ready
sleep 2

# Configure FileBrowser if database doesn't exist
if [[ ! -f /config/filebrowser.db ]]; then
    echo "Setting up FileBrowser database..."
    
    # Create admin user
    filebrowser config init --database /config/filebrowser.db
    filebrowser config set --database /config/filebrowser.db --auth.method=json
    filebrowser users add admin admin --database /config/filebrowser.db --perm.admin=true
    
    echo "FileBrowser setup completed"
fi

# Start FileBrowser
exec filebrowser --config /config/config.json
EOF
    
    chmod +x "$FILEBROWSER_CONFIG_DIR/setup.sh"
    
    log "SUCCESS" "File Manager configuration created"
}

deploy_filemanager_container() {
    log "INFO" "Deploying File Manager container"
    
    # Stop and remove existing container if it exists
    docker stop "$FILEBROWSER_CONTAINER_NAME" 2>/dev/null || true
    docker rm "$FILEBROWSER_CONTAINER_NAME" 2>/dev/null || true
    
    # Create and start File Manager container
    docker run -d \
        --name "$FILEBROWSER_CONTAINER_NAME" \
        --network server-panel \
        -p "127.0.0.1:${FILEBROWSER_PORT}:80" \
        -v "$FILEBROWSER_CONFIG_DIR":/config \
        -v "$FILEBROWSER_DATA_DIR":/srv/users \
        -v /var/server-panel/apps:/srv/apps \
        -v "$FILEBROWSER_CONFIG_DIR/setup.sh":/setup.sh \
        -e PUID=0 \
        -e PGID=0 \
        --restart unless-stopped \
        filebrowser/filebrowser:v"$FILEBROWSER_VERSION" \
        /setup.sh
    
    if [[ $? -eq 0 ]]; then
        log "SUCCESS" "File Manager container deployed successfully"
    else
        log "ERROR" "Failed to deploy File Manager container"
        return 1
    fi
}

wait_for_filemanager() {
    log "INFO" "Waiting for File Manager to be ready"
    
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${FILEBROWSER_PORT}" | grep -q "200\|401"; then
            log "SUCCESS" "File Manager is ready"
            return 0
        fi
        
        log "INFO" "Waiting for File Manager to start (attempt $attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done
    
    log "ERROR" "File Manager failed to start after $max_attempts attempts"
    return 1
}

setup_filemanager_users() {
    log "INFO" "Setting up File Manager users"
    
    # Wait a bit more for the database to be fully initialized
    sleep 5
    
    # Create default user directories
    create_directory "$FILEBROWSER_DATA_DIR/demo" "www-data" "www-data" "755"
    
    # Create some sample files
    cat > "$FILEBROWSER_DATA_DIR/demo/welcome.txt" << 'EOF'
Welcome to Server Panel File Manager!

This file manager allows you to:
- Upload and download files
- Create and edit files online
- Manage file permissions
- Create directories
- Search for files
- Share files with others

Default credentials:
Username: admin
Password: admin

Please change the default password after first login.
EOF
    
    # Create templates directory with common file templates
    cat > "$FILEBROWSER_DATA_DIR/templates/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Welcome</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f4f4f4;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            text-align: center;
        }
        p {
            line-height: 1.6;
            color: #666;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Welcome to Your Website</h1>
        <p>This is a template HTML file. Edit this file to create your website.</p>
        <p>You can customize this page to showcase your content.</p>
    </div>
</body>
</html>
EOF
    
    cat > "$FILEBROWSER_DATA_DIR/templates/app.js" << 'EOF'
// Sample Node.js application
const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(express.json());
app.use(express.static('public'));

// Routes
app.get('/', (req, res) => {
    res.send('Hello from your Node.js application!');
});

app.get('/api/status', (req, res) => {
    res.json({ 
        status: 'running', 
        timestamp: new Date().toISOString() 
    });
});

// Start server
app.listen(port, () => {
    console.log(`Server running on port ${port}`);
});
EOF
    
    cat > "$FILEBROWSER_DATA_DIR/templates/requirements.txt" << 'EOF'
# Python requirements template
flask==2.3.3
requests==2.31.0
python-dotenv==1.0.0
gunicorn==21.2.0
EOF
    
    cat > "$FILEBROWSER_DATA_DIR/templates/app.py" << 'EOF'
# Sample Flask application
from flask import Flask, jsonify, render_template_string
import os
from datetime import datetime

app = Flask(__name__)

# Simple HTML template
HTML_TEMPLATE = '''
<!DOCTYPE html>
<html>
<head>
    <title>Python Web App</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .container { max-width: 600px; margin: 0 auto; }
        h1 { color: #333; }
        .status { background: #e8f5e8; padding: 10px; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Python Flask Application</h1>
        <div class="status">
            <p>Status: Running</p>
            <p>Time: {{ timestamp }}</p>
        </div>
    </div>
</body>
</html>
'''

@app.route('/')
def home():
    return render_template_string(HTML_TEMPLATE, timestamp=datetime.now())

@app.route('/api/status')
def status():
    return jsonify({
        'status': 'running',
        'timestamp': datetime.now().isoformat()
    })

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)
EOF
    
    # Set proper ownership
    chown -R www-data:www-data "$FILEBROWSER_DATA_DIR"
    
    log "SUCCESS" "File Manager users and templates setup completed"
}

verify_filemanager_installation() {
    log "INFO" "Verifying File Manager installation"
    
    # Check if container is running
    if docker ps | grep -q "$FILEBROWSER_CONTAINER_NAME"; then
        log "SUCCESS" "File Manager container is running"
    else
        log "ERROR" "File Manager container is not running"
        return 1
    fi
    
    # Check if service is responding
    local response_code
    response_code=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${FILEBROWSER_PORT}")
    
    if [[ "$response_code" == "200" ]] || [[ "$response_code" == "401" ]]; then
        log "SUCCESS" "File Manager is responding on port $FILEBROWSER_PORT"
    else
        log "ERROR" "File Manager is not responding (HTTP $response_code)"
        return 1
    fi
    
    # Check if database file exists
    if [[ -f "$FILEBROWSER_CONFIG_DIR/filebrowser.db" ]]; then
        log "SUCCESS" "File Manager database is initialized"
    else
        log "WARNING" "File Manager database not found"
    fi
    
    log "SUCCESS" "File Manager installation verification completed"
}

# Create new user
create_filemanager_user() {
    local username="$1"
    local password="$2"
    local scope="${3:-/srv/users/$username}"
    local is_admin="${4:-false}"
    
    if [[ -z "$username" ]] || [[ -z "$password" ]]; then
        log "ERROR" "Username and password are required"
        return 1
    fi
    
    log "INFO" "Creating File Manager user: $username"
    
    # Create user directory
    create_directory "$FILEBROWSER_DATA_DIR/$username" "www-data" "www-data" "755"
    
    # Add user to FileBrowser
    local admin_flag=""
    if [[ "$is_admin" == "true" ]]; then
        admin_flag="--perm.admin=true"
    fi
    
    docker exec "$FILEBROWSER_CONTAINER_NAME" \
        filebrowser users add "$username" "$password" \
        --database /config/filebrowser.db \
        --scope "$scope" \
        $admin_flag
    
    if [[ $? -eq 0 ]]; then
        log "SUCCESS" "File Manager user created: $username"
    else
        log "ERROR" "Failed to create File Manager user: $username"
        return 1
    fi
}

# Remove user
remove_filemanager_user() {
    local username="$1"
    local remove_files="${2:-false}"
    
    if [[ -z "$username" ]]; then
        log "ERROR" "Username is required"
        return 1
    fi
    
    log "INFO" "Removing File Manager user: $username"
    
    # Remove user from FileBrowser
    docker exec "$FILEBROWSER_CONTAINER_NAME" \
        filebrowser users rm "$username" \
        --database /config/filebrowser.db
    
    # Optionally remove user files
    if [[ "$remove_files" == "true" ]]; then
        rm -rf "$FILEBROWSER_DATA_DIR/$username"
        log "INFO" "User files removed for: $username"
    fi
    
    if [[ $? -eq 0 ]]; then
        log "SUCCESS" "File Manager user removed: $username"
    else
        log "ERROR" "Failed to remove File Manager user: $username"
        return 1
    fi
}

# List users
list_filemanager_users() {
    log "INFO" "Listing File Manager users"
    
    docker exec "$FILEBROWSER_CONTAINER_NAME" \
        filebrowser users ls \
        --database /config/filebrowser.db
}

# Get File Manager status
get_filemanager_status() {
    if ! docker ps | grep -q "$FILEBROWSER_CONTAINER_NAME"; then
        echo "stopped"
        return 1
    fi
    
    local response_code
    response_code=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${FILEBROWSER_PORT}")
    
    if [[ "$response_code" == "200" ]] || [[ "$response_code" == "401" ]]; then
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
            install_filemanager
            ;;
        "create-user")
            create_filemanager_user "$2" "$3" "$4" "$5"
            ;;
        "remove-user")
            remove_filemanager_user "$2" "$3"
            ;;
        "list-users")
            list_filemanager_users
            ;;
        "status")
            get_filemanager_status
            ;;
        *)
            echo "Usage: $0 [install|create-user|remove-user|list-users|status]"
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 