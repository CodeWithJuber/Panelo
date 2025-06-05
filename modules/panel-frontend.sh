#!/bin/bash

# Panel Frontend Module - Permanent Solution
# Creates a simple, modern frontend dashboard

set -e

# Source helper functions
if [[ -f "/opt/server-panel/modules/helper.sh" ]]; then
    source "/opt/server-panel/modules/helper.sh"
else
    # Fallback logging functions
    log() {
        echo "[$1] $2"
    }
fi

# Configuration
FRONTEND_DIR="/opt/server-panel/frontend"

# Install frontend
install_frontend() {
    log "INFO" "Installing Panel Frontend"
    
    # Create frontend directory structure
    mkdir -p "$FRONTEND_DIR"/{public,src}
    cd "$FRONTEND_DIR"
    
    # Create all necessary files
    create_package_json
    create_main_server
    create_dashboard_files
    create_docker_config
    install_dependencies
    deploy_frontend
    
    log "SUCCESS" "Panel Frontend installation completed"
    log "INFO" "Frontend available at: http://0.0.0.0:3000"
}

create_package_json() {
    log "INFO" "Creating package.json"
    
    cat > "$FRONTEND_DIR/package.json" << 'EOF'
{
  "name": "panelo-frontend",
  "version": "1.0.0",
  "description": "Panelo Server Panel Frontend",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "node server.js"
  },
  "keywords": ["panelo", "cpanel", "server", "panel", "frontend"],
  "author": "Panelo Team",
  "license": "MIT",
  "dependencies": {
    "express": "^4.18.2",
    "express-handlebars": "^7.0.7"
  }
}
EOF

    log "SUCCESS" "Package.json created"
}

create_main_server() {
    log "INFO" "Creating main server file"
    
    cat > "$FRONTEND_DIR/server.js" << 'EOF'
const express = require('express');
const path = require('path');
const { engine } = require('express-handlebars');

const app = express();
const port = process.env.PORT || 3000;

// Set up Handlebars engine
app.engine('handlebars', engine({
    defaultLayout: 'main',
    layoutsDir: path.join(__dirname, 'views/layouts'),
    partialsDir: path.join(__dirname, 'views/partials')
}));
app.set('view engine', 'handlebars');
app.set('views', path.join(__dirname, 'views'));

// Static files
app.use(express.static(path.join(__dirname, 'public')));

// Routes
app.get('/', (req, res) => {
    res.render('dashboard', {
        title: 'Panelo Dashboard',
        serverInfo: {
            hostname: 'server.example.com',
            uptime: '2 days, 14 hours',
            load: '0.45',
            memory: '45%',
            disk: '23%'
        }
    });
});

app.get('/apps', (req, res) => {
    res.render('apps', {
        title: 'Applications - Panelo',
        apps: [
            { name: 'WordPress Blog', type: 'wordpress', status: 'running' },
            { name: 'Node.js API', type: 'nodejs', status: 'running' },
            { name: 'PHP Website', type: 'php', status: 'stopped' }
        ]
    });
});

app.get('/files', (req, res) => {
    res.redirect('http://localhost:8080');
});

app.get('/databases', (req, res) => {
    res.render('databases', {
        title: 'Databases - Panelo',
        databases: [
            { name: 'wordpress_db', type: 'MySQL', size: '45MB' },
            { name: 'app_data', type: 'MySQL', size: '128MB' }
        ]
    });
});

app.get('/domains', (req, res) => {
    res.render('domains', {
        title: 'Domains - Panelo',
        domains: [
            { name: 'example.com', status: 'active', ssl: true },
            { name: 'blog.example.com', status: 'active', ssl: true }
        ]
    });
});

app.get('/monitoring', (req, res) => {
    res.redirect('http://localhost:3000/grafana');
});

// Start server
app.listen(port, '0.0.0.0', () => {
    console.log(`🚀 Panelo Frontend running on http://0.0.0.0:${port}`);
    console.log(`📊 Dashboard: http://0.0.0.0:${port}`);
});
EOF

    log "SUCCESS" "Main server file created"
}

create_dashboard_files() {
    log "INFO" "Creating dashboard files"
    
    # Create views directory structure
    mkdir -p "$FRONTEND_DIR/views"/{layouts,partials}
    
    # Main layout
    cat > "$FRONTEND_DIR/views/layouts/main.handlebars" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{title}}</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
    <style>
        body {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
        }
        .sidebar {
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            border-radius: 15px;
            border: 1px solid rgba(255, 255, 255, 0.2);
        }
        .main-content {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            border-radius: 15px;
            border: 1px solid rgba(255, 255, 255, 0.2);
        }
        .card {
            background: rgba(255, 255, 255, 0.9);
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.2);
            border-radius: 15px;
        }
        .nav-link {
            color: white !important;
            border-radius: 10px;
            margin: 5px 0;
        }
        .nav-link:hover {
            background: rgba(255, 255, 255, 0.2);
        }
        .nav-link.active {
            background: rgba(255, 255, 255, 0.3);
        }
        .stats-card {
            background: linear-gradient(45deg, #ff6b6b, #ee5a24);
            color: white;
            border-radius: 15px;
            border: none;
        }
        .stats-card.success {
            background: linear-gradient(45deg, #00d2d3, #54a0ff);
        }
        .stats-card.warning {
            background: linear-gradient(45deg, #feca57, #ff9ff3);
        }
        .stats-card.info {
            background: linear-gradient(45deg, #48dbfb, #0abde3);
        }
    </style>
</head>
<body>
    <div class="container-fluid p-4">
        <div class="row">
            <!-- Sidebar -->
            <div class="col-md-3 mb-4">
                <div class="sidebar p-4 h-100">
                    <h3 class="text-white mb-4">
                        <i class="fas fa-server me-2"></i>
                        Panelo
                    </h3>
                    <nav class="nav flex-column">
                        <a class="nav-link" href="/"><i class="fas fa-tachometer-alt me-2"></i>Dashboard</a>
                        <a class="nav-link" href="/apps"><i class="fas fa-rocket me-2"></i>Applications</a>
                        <a class="nav-link" href="/files"><i class="fas fa-folder me-2"></i>File Manager</a>
                        <a class="nav-link" href="/databases"><i class="fas fa-database me-2"></i>Databases</a>
                        <a class="nav-link" href="/domains"><i class="fas fa-globe me-2"></i>Domains</a>
                        <a class="nav-link" href="/monitoring"><i class="fas fa-chart-line me-2"></i>Monitoring</a>
                    </nav>
                </div>
            </div>
            
            <!-- Main Content -->
            <div class="col-md-9">
                <div class="main-content p-4">
                    {{{body}}}
                </div>
            </div>
        </div>
    </div>
    
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        // Mark active nav item
        const currentPath = window.location.pathname;
        document.querySelectorAll('.nav-link').forEach(link => {
            if (link.getAttribute('href') === currentPath) {
                link.classList.add('active');
            }
        });
    </script>
</body>
</html>
EOF

    # Dashboard view
    cat > "$FRONTEND_DIR/views/dashboard.handlebars" << 'EOF'
<div class="row mb-4">
    <div class="col-12">
        <h1 class="mb-4">
            <i class="fas fa-tachometer-alt me-2"></i>
            Server Dashboard
        </h1>
    </div>
</div>

<div class="row mb-4">
    <div class="col-md-3 mb-3">
        <div class="card stats-card">
            <div class="card-body text-center">
                <h5><i class="fas fa-microchip me-2"></i>CPU Usage</h5>
                <h2>{{serverInfo.load}}%</h2>
            </div>
        </div>
    </div>
    <div class="col-md-3 mb-3">
        <div class="card stats-card success">
            <div class="card-body text-center">
                <h5><i class="fas fa-memory me-2"></i>Memory</h5>
                <h2>{{serverInfo.memory}}</h2>
            </div>
        </div>
    </div>
    <div class="col-md-3 mb-3">
        <div class="card stats-card warning">
            <div class="card-body text-center">
                <h5><i class="fas fa-hdd me-2"></i>Disk Usage</h5>
                <h2>{{serverInfo.disk}}</h2>
            </div>
        </div>
    </div>
    <div class="col-md-3 mb-3">
        <div class="card stats-card info">
            <div class="card-body text-center">
                <h5><i class="fas fa-clock me-2"></i>Uptime</h5>
                <h6>{{serverInfo.uptime}}</h6>
            </div>
        </div>
    </div>
</div>

<div class="row">
    <div class="col-md-6 mb-4">
        <div class="card">
            <div class="card-header">
                <h5><i class="fas fa-rocket me-2"></i>Quick Actions</h5>
            </div>
            <div class="card-body">
                <div class="d-grid gap-2">
                    <a href="/apps" class="btn btn-primary">
                        <i class="fas fa-plus me-2"></i>Deploy Application
                    </a>
                    <a href="/files" class="btn btn-success">
                        <i class="fas fa-upload me-2"></i>Upload Files
                    </a>
                    <a href="/databases" class="btn btn-info">
                        <i class="fas fa-database me-2"></i>Create Database
                    </a>
                    <a href="/domains" class="btn btn-warning">
                        <i class="fas fa-globe me-2"></i>Add Domain
                    </a>
                </div>
            </div>
        </div>
    </div>
    
    <div class="col-md-6 mb-4">
        <div class="card">
            <div class="card-header">
                <h5><i class="fas fa-info-circle me-2"></i>Server Information</h5>
            </div>
            <div class="card-body">
                <p><strong>Hostname:</strong> {{serverInfo.hostname}}</p>
                <p><strong>Panel Version:</strong> 1.0.0</p>
                <p><strong>Backend API:</strong> <span class="badge bg-success">Running</span></p>
                <p><strong>File Manager:</strong> <span class="badge bg-success">Running</span></p>
                <p><strong>Monitoring:</strong> <span class="badge bg-success">Active</span></p>
            </div>
        </div>
    </div>
</div>

<div class="row">
    <div class="col-12">
        <div class="card">
            <div class="card-header">
                <h5><i class="fas fa-chart-line me-2"></i>Recent Activity</h5>
            </div>
            <div class="card-body">
                <div class="list-group">
                    <div class="list-group-item">
                        <i class="fas fa-check-circle text-success me-2"></i>
                        WordPress application deployed successfully
                        <small class="text-muted float-end">2 hours ago</small>
                    </div>
                    <div class="list-group-item">
                        <i class="fas fa-database text-info me-2"></i>
                        Database 'wordpress_db' created
                        <small class="text-muted float-end">3 hours ago</small>
                    </div>
                    <div class="list-group-item">
                        <i class="fas fa-shield-alt text-warning me-2"></i>
                        SSL certificate renewed for example.com
                        <small class="text-muted float-end">1 day ago</small>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>
EOF

    # Applications view
    cat > "$FRONTEND_DIR/views/apps.handlebars" << 'EOF'
<div class="row mb-4">
    <div class="col-12">
        <h1 class="mb-4">
            <i class="fas fa-rocket me-2"></i>
            Applications
        </h1>
    </div>
</div>

<div class="row mb-4">
    <div class="col-12">
        <button class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#deployModal">
            <i class="fas fa-plus me-2"></i>Deploy New Application
        </button>
    </div>
</div>

<div class="row">
    <div class="col-12">
        <div class="card">
            <div class="card-header">
                <h5><i class="fas fa-list me-2"></i>Your Applications</h5>
            </div>
            <div class="card-body">
                <div class="table-responsive">
                    <table class="table table-striped">
                        <thead>
                            <tr>
                                <th>Name</th>
                                <th>Type</th>
                                <th>Status</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            {{#each apps}}
                            <tr>
                                <td>{{name}}</td>
                                <td>
                                    <span class="badge bg-secondary">{{type}}</span>
                                </td>
                                <td>
                                    {{#if (eq status 'running')}}
                                        <span class="badge bg-success">Running</span>
                                    {{else}}
                                        <span class="badge bg-danger">Stopped</span>
                                    {{/if}}
                                </td>
                                <td>
                                    <button class="btn btn-sm btn-outline-primary">
                                        <i class="fas fa-play"></i>
                                    </button>
                                    <button class="btn btn-sm btn-outline-warning">
                                        <i class="fas fa-pause"></i>
                                    </button>
                                    <button class="btn btn-sm btn-outline-danger">
                                        <i class="fas fa-trash"></i>
                                    </button>
                                </td>
                            </tr>
                            {{/each}}
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
</div>

<!-- Deploy Modal -->
<div class="modal fade" id="deployModal" tabindex="-1">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title">Deploy New Application</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body">
                <form>
                    <div class="mb-3">
                        <label class="form-label">Application Type</label>
                        <select class="form-select">
                            <option>WordPress</option>
                            <option>Node.js</option>
                            <option>PHP</option>
                            <option>Python</option>
                        </select>
                    </div>
                    <div class="mb-3">
                        <label class="form-label">Application Name</label>
                        <input type="text" class="form-control" placeholder="My App">
                    </div>
                    <div class="mb-3">
                        <label class="form-label">Domain</label>
                        <input type="text" class="form-control" placeholder="myapp.example.com">
                    </div>
                </form>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                <button type="button" class="btn btn-primary">Deploy</button>
            </div>
        </div>
    </div>
</div>
EOF

    # Other views (simplified)
    cat > "$FRONTEND_DIR/views/databases.handlebars" << 'EOF'
<h1><i class="fas fa-database me-2"></i>Databases</h1>
<p>Database management interface</p>
EOF

    cat > "$FRONTEND_DIR/views/domains.handlebars" << 'EOF'
<h1><i class="fas fa-globe me-2"></i>Domains</h1>
<p>Domain management interface</p>
EOF

    log "SUCCESS" "Dashboard files created"
}

create_docker_config() {
    log "INFO" "Creating Docker configuration"
    
    # Create Dockerfile
    cat > "$FRONTEND_DIR/Dockerfile" << 'EOF'
FROM node:18-alpine

# Install basic dependencies
RUN apk add --no-cache wget curl

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install --production && npm cache clean --force

# Copy application files
COPY . .

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:3000 || exit 1

# Start application
CMD ["npm", "start"]
EOF

    # Create docker-compose.yml
    cat > "$FRONTEND_DIR/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  frontend:
    build: 
      context: .
      dockerfile: Dockerfile
    container_name: server-panel-frontend
    restart: unless-stopped
    ports:
      - "0.0.0.0:3000:3000"
    environment:
      - NODE_ENV=production
      - PORT=3000
    networks:
      - server-panel
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:3000"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 30s
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

networks:
  server-panel:
    external: true
EOF

    log "SUCCESS" "Docker configuration created"
}

install_dependencies() {
    log "INFO" "Installing frontend dependencies"
    
    cd "$FRONTEND_DIR"
    
    # Install npm dependencies
    npm install --production
    
    if [[ $? -eq 0 ]]; then
        log "SUCCESS" "Frontend dependencies installed successfully"
    else
        log "ERROR" "Failed to install frontend dependencies"
        return 1
    fi
}

deploy_frontend() {
    log "INFO" "Deploying frontend"
    
    cd "$FRONTEND_DIR"
    
    # Ensure Docker network exists
    docker network create server-panel 2>/dev/null || true
    
    # Build and start containers
    docker compose build --no-cache
    docker compose up -d
    
    # Wait for services to be ready
    log "INFO" "Waiting for frontend to be ready..."
    sleep 10
    
    # Check if frontend is responding
    local max_attempts=20
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -s http://localhost:3000 > /dev/null 2>&1; then
            log "SUCCESS" "Frontend is running and accessible"
            break
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            log "WARNING" "Frontend may not be fully ready yet, check with: docker logs server-panel-frontend"
        fi
        
        sleep 2
        ((attempt++))
    done
}

# Handle command line arguments
case "${1:-install}" in
    "install")
        install_frontend
        ;;
    "restart")
        cd "$FRONTEND_DIR"
        docker compose restart
        ;;
    "stop")
        cd "$FRONTEND_DIR"
        docker compose down
        ;;
    "start")
        cd "$FRONTEND_DIR"
        docker compose up -d
        ;;
    "logs")
        docker logs server-panel-frontend -f
        ;;
    "status")
        docker ps | grep server-panel-frontend
        ;;
    *)
        echo "Usage: $0 [install|restart|stop|start|logs|status]"
        echo "  install  - Install frontend (default)"
        echo "  restart  - Restart frontend containers"
        echo "  stop     - Stop frontend containers"
        echo "  start    - Start frontend containers"
        echo "  logs     - Show frontend logs"
        echo "  status   - Show frontend container status"
        exit 1
        ;;
esac 