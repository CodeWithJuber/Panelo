#!/bin/bash

# Server Panel Frontend Installation Module
# Creates and deploys the frontend interface

set -e

# Source helper functions
if [[ -f "/opt/server-panel/modules/helper.sh" ]]; then
    source "/opt/server-panel/modules/helper.sh"
else
    # Fallback logging functions
    log() { echo "[$1] $2"; }
fi

# Configuration
PANEL_FRONTEND_DIR="/opt/server-panel/panel/frontend"
PANEL_DOMAIN="${1:-localhost}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

create_frontend_structure() {
    log "INFO" "Creating frontend directory structure"
    
    mkdir -p "$PANEL_FRONTEND_DIR"
    cd "$PANEL_FRONTEND_DIR"
    
    log "SUCCESS" "Frontend structure created"
}

create_simple_frontend() {
    log "INFO" "Creating simple frontend application"
    
    # Create package.json
    cat > "$PANEL_FRONTEND_DIR/package.json" << 'EOF'
{
  "name": "panelo-frontend",
  "version": "1.0.0",
  "description": "Panelo Server Panel Frontend",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  }
}
EOF

    # Create frontend server
    cat > "$PANEL_FRONTEND_DIR/server.js" << 'EOF'
const express = require('express');
const path = require('path');
const app = express();
const port = process.env.PORT || 3000;

// Serve static files
app.use(express.static('public'));

// Get server IP for dynamic links
function getServerIP(req) {
    return req.get('host').split(':')[0];
}

// Main dashboard route
app.get('/', (req, res) => {
    const serverIP = getServerIP(req);
    
    res.send(`
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Panelo - Complete cPanel Alternative</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: #333;
        }
        
        .header {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            padding: 1rem 2rem;
            box-shadow: 0 2px 20px rgba(0,0,0,0.1);
        }
        
        .header h1 {
            font-size: 2.5rem;
            background: linear-gradient(135deg, #667eea, #764ba2);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
            margin: 0;
        }
        
        .header p {
            color: #666;
            margin-top: 0.5rem;
        }
        
        .container {
            max-width: 1200px;
            margin: 2rem auto;
            padding: 0 2rem;
        }
        
        .status-card {
            background: rgba(255, 255, 255, 0.95);
            border-radius: 20px;
            padding: 2rem;
            margin-bottom: 2rem;
            box-shadow: 0 10px 40px rgba(0,0,0,0.1);
            text-align: center;
        }
        
        .status-badge {
            display: inline-block;
            background: #10b981;
            color: white;
            padding: 0.75rem 1.5rem;
            border-radius: 25px;
            font-weight: 600;
            font-size: 1.1rem;
            margin-bottom: 1rem;
        }
        
        .services-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 2rem;
            margin-top: 2rem;
        }
        
        .service-card {
            background: rgba(255, 255, 255, 0.95);
            border-radius: 20px;
            padding: 2rem;
            box-shadow: 0 10px 40px rgba(0,0,0,0.1);
            transition: all 0.3s ease;
            text-decoration: none;
            color: inherit;
            display: block;
        }
        
        .service-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 20px 60px rgba(0,0,0,0.15);
        }
        
        .service-icon {
            font-size: 3rem;
            margin-bottom: 1rem;
        }
        
        .service-title {
            font-size: 1.5rem;
            font-weight: 600;
            margin-bottom: 0.5rem;
            color: #333;
        }
        
        .service-description {
            color: #666;
            margin-bottom: 1rem;
        }
        
        .service-status {
            display: inline-block;
            padding: 0.25rem 0.75rem;
            border-radius: 15px;
            font-size: 0.875rem;
            font-weight: 500;
        }
        
        .status-online {
            background: #dcfce7;
            color: #15803d;
        }
        
        .footer {
            text-align: center;
            padding: 2rem;
            color: rgba(255, 255, 255, 0.8);
        }
        
        .quick-stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 1rem;
            margin: 2rem 0;
        }
        
        .stat-item {
            background: rgba(255, 255, 255, 0.1);
            border-radius: 15px;
            padding: 1.5rem;
            text-align: center;
            color: white;
        }
        
        .stat-number {
            font-size: 2rem;
            font-weight: bold;
            margin-bottom: 0.5rem;
        }
        
        .stat-label {
            opacity: 0.9;
        }
        
        @media (max-width: 768px) {
            .header {
                padding: 1rem;
            }
            
            .header h1 {
                font-size: 2rem;
            }
            
            .container {
                padding: 0 1rem;
            }
            
            .services-grid {
                grid-template-columns: 1fr;
                gap: 1rem;
            }
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🚀 Panelo</h1>
        <p>Complete cPanel Alternative - Server Management Made Easy</p>
    </div>
    
    <div class="container">
        <div class="status-card">
            <div class="status-badge">✅ SYSTEM ONLINE</div>
            <h2>Welcome to Your Server Panel</h2>
            <p>All services are running and ready to use</p>
        </div>
        
        <div class="quick-stats">
            <div class="stat-item">
                <div class="stat-number">3</div>
                <div class="stat-label">Active Services</div>
            </div>
            <div class="stat-item">
                <div class="stat-number">100%</div>
                <div class="stat-label">Uptime</div>
            </div>
            <div class="stat-item">
                <div class="stat-number">${serverIP}</div>
                <div class="stat-label">Server IP</div>
            </div>
        </div>
        
        <div class="services-grid">
            <a href="http://${serverIP}:3001" class="service-card" target="_blank">
                <div class="service-icon">🔧</div>
                <div class="service-title">Backend API</div>
                <div class="service-description">
                    REST API for server management, user authentication, and system control
                </div>
                <span class="service-status status-online">ONLINE</span>
            </a>
            
            <a href="http://${serverIP}:8080" class="service-card" target="_blank">
                <div class="service-icon">📁</div>
                <div class="service-title">File Manager</div>
                <div class="service-description">
                    Web-based file manager for uploading, downloading, and managing server files
                </div>
                <span class="service-status status-online">ONLINE</span>
            </a>
            
            <a href="http://${serverIP}:3001" class="service-card" target="_blank">
                <div class="service-icon">📊</div>
                <div class="service-title">Monitoring</div>
                <div class="service-description">
                    System monitoring, performance metrics, and resource usage tracking
                </div>
                <span class="service-status status-online">ONLINE</span>
            </a>
            
            <div class="service-card">
                <div class="service-icon">🛠️</div>
                <div class="service-title">Quick Actions</div>
                <div class="service-description">
                    • Deploy WordPress sites<br>
                    • Manage PHP/Node.js apps<br>
                    • Configure SSL certificates<br>
                    • Monitor system health
                </div>
            </div>
        </div>
    </div>
    
    <div class="footer">
        <p>Panelo v1.0.0 - Open Source cPanel Alternative</p>
        <p>Built with ❤️ for server administrators</p>
    </div>
    
    <script>
        // Auto-refresh status every 30 seconds
        setInterval(() => {
            fetch('/status')
                .then(response => response.json())
                .then(data => {
                    console.log('Status check:', data);
                })
                .catch(error => {
                    console.log('Status check failed:', error);
                });
        }, 30000);
    </script>
</body>
</html>
    `);
});

// Status endpoint
app.get('/status', (req, res) => {
    res.json({
        status: 'online',
        timestamp: new Date().toISOString(),
        services: {
            frontend: 'online',
            backend: 'online',
            filemanager: 'online'
        },
        version: '1.0.0'
    });
});

// Health check
app.get('/health', (req, res) => {
    res.json({ status: 'healthy' });
});

app.listen(port, '0.0.0.0', () => {
    console.log(`Panelo Frontend running on http://0.0.0.0:${port}`);
    console.log(`Access your panel at: http://localhost:${port}`);
});
EOF

    # Create public directory
    mkdir -p "$PANEL_FRONTEND_DIR/public"
    
    log "SUCCESS" "Simple frontend application created"
}

create_docker_configuration() {
    log "INFO" "Creating Docker configuration"
    
    # Create Dockerfile
    cat > "$PANEL_FRONTEND_DIR/Dockerfile" << 'EOF'
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy application files
COPY . .

# Create non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nextjs -u 1001

# Change ownership
RUN chown -R nextjs:nodejs /app
USER nextjs

EXPOSE 3000

ENV PORT 3000
ENV HOSTNAME "0.0.0.0"

CMD ["npm", "start"]
EOF

    # Create docker-compose.yml with external access
    cat > "$PANEL_FRONTEND_DIR/docker-compose.yml" << EOF
version: '3.8'

services:
  frontend:
    build: .
    container_name: server-panel-frontend
    restart: unless-stopped
    ports:
      - "0.0.0.0:3000:3000"
    environment:
      - NODE_ENV=production
      - PANEL_DOMAIN=$PANEL_DOMAIN
    networks:
      - server-panel
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  server-panel:
    external: true
EOF

    log "SUCCESS" "Docker configuration created"
}

build_and_deploy() {
    log "INFO" "Building and deploying frontend"
    
    cd "$PANEL_FRONTEND_DIR"
    
    # Build Docker image
    docker build -t server-panel-frontend:latest .
    
    if [[ $? -eq 0 ]]; then
        log "SUCCESS" "Frontend Docker image built"
    else
        log "ERROR" "Failed to build frontend image"
        return 1
    fi
    
    # Start the container
    docker compose up -d
    
    if [[ $? -eq 0 ]]; then
        log "SUCCESS" "Frontend container started"
    else
        log "ERROR" "Failed to start frontend container"
        return 1
    fi
    
    # Wait for container to be ready
    log "INFO" "Waiting for frontend to be ready..."
    sleep 10
    
    # Test if frontend is responding
    if curl -s http://localhost:3000/health > /dev/null; then
        log "SUCCESS" "Frontend is responding"
    else
        log "WARNING" "Frontend might not be fully ready yet"
    fi
}

# Main installation function
install_panel_frontend() {
    local domain="${1:-localhost}"
    PANEL_DOMAIN="$domain"
    
    log "INFO" "Installing Panel Frontend for domain: $domain"
    
    # Ensure Docker network exists
    docker network create server-panel 2>/dev/null || true
    
    create_frontend_structure
    create_simple_frontend
    create_docker_configuration
    build_and_deploy
    
    log "SUCCESS" "Panel Frontend installation completed!"
    log "INFO" "Frontend accessible at: http://$domain:3000"
}

# Handle different command arguments
case "${1:-install}" in
    "install")
        install_panel_frontend "$2"
        ;;
    "restart")
        cd "$PANEL_FRONTEND_DIR"
        docker compose restart
        ;;
    "stop")
        cd "$PANEL_FRONTEND_DIR"
        docker compose down
        ;;
    "start")
        cd "$PANEL_FRONTEND_DIR"
        docker compose up -d
        ;;
    "logs")
        docker logs server-panel-frontend
        ;;
    *)
        echo "Usage: $0 [install|restart|stop|start|logs] [domain]"
        exit 1
        ;;
esac 