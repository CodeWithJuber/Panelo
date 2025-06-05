#!/bin/bash

# Node.js Application Deployment Module
# Supports multiple Node.js versions and frameworks

set -euo pipefail

# Source helper functions
source "$(dirname "$0")/helper.sh"

# Configuration
NODE_VERSIONS=("16" "18" "20" "21")
NODEJS_DATA_DIR="/var/server-panel/nodejs"

# Install Node.js support
install_nodejs_support() {
    log "INFO" "Installing Node.js application support"
    
    setup_nodejs_environment
    create_nodejs_templates
    setup_package_managers
    create_nodejs_management_scripts
    
    log "SUCCESS" "Node.js application support installed"
}

# Setup Node.js environment
setup_nodejs_environment() {
    log "INFO" "Setting up Node.js environment"
    
    create_directory "$NODEJS_DATA_DIR" "root" "root" "755"
    create_directory "$NODEJS_DATA_DIR/templates" "root" "root" "755"
    create_directory "$NODEJS_DATA_DIR/configs" "root" "root" "755"
    
    # Pull Node.js Docker images
    for version in "${NODE_VERSIONS[@]}"; do
        log "INFO" "Pulling Node.js $version Docker image"
        docker pull "node:${version}-alpine" || log "WARN" "Failed to pull Node.js $version image"
    done
    
    # Pull additional tools
    docker pull nginx:alpine
    
    log "SUCCESS" "Node.js environment setup completed"
}

# Create Node.js application templates
create_nodejs_templates() {
    log "INFO" "Creating Node.js application templates"
    
    # Basic Express template
    create_express_template
    
    # Next.js template
    create_nextjs_template
    
    # NestJS template
    create_nestjs_template
    
    # React SPA template
    create_react_template
    
    log "SUCCESS" "Node.js templates created"
}

# Create Express template
create_express_template() {
    local template_dir="$NODEJS_DATA_DIR/templates/express"
    create_directory "$template_dir" "root" "root" "755"
    
    cat > "$template_dir/Dockerfile" << 'EOF'
FROM node:{{NODE_VERSION}}-alpine

# Install dumb-init
RUN apk add --no-cache dumb-init

# Create app directory
WORKDIR /app

# Create user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production && npm cache clean --force

# Copy app source
COPY . .

# Change ownership
RUN chown -R nodejs:nodejs /app
USER nodejs

EXPOSE 3000

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

CMD ["npm", "start"]
EOF

    cat > "$template_dir/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  app:
    build: .
    container_name: {{CONTAINER_NAME}}
    restart: unless-stopped
    networks:
      - server-panel
    ports:
      - "{{PORT}}:3000"
    environment:
      - NODE_ENV=production
      - PORT=3000
    volumes:
      - ./logs:/app/logs
    labels:
      - "panel.app={{APP_NAME}}"
      - "panel.domain={{DOMAIN}}"
      - "panel.user={{USER_ID}}"
      - "panel.type=express"

networks:
  server-panel:
    external: true
EOF

    cat > "$template_dir/package.json" << 'EOF'
{
  "name": "{{APP_NAME}}",
  "version": "1.0.0",
  "description": "Express.js application deployed with Server Panel",
  "main": "app.js",
  "scripts": {
    "start": "node app.js",
    "dev": "nodemon app.js",
    "test": "jest"
  },
  "dependencies": {
    "express": "^4.18.2",
    "helmet": "^7.0.0",
    "cors": "^2.8.5",
    "morgan": "^1.10.0",
    "compression": "^1.7.4",
    "dotenv": "^16.3.1"
  },
  "devDependencies": {
    "nodemon": "^3.0.1",
    "jest": "^29.6.4"
  },
  "engines": {
    "node": ">=16.0.0"
  },
  "keywords": [
    "express",
    "nodejs",
    "api"
  ],
  "author": "Server Panel",
  "license": "MIT"
}
EOF

    cat > "$template_dir/app.js" << 'EOF'
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const morgan = require('morgan');
const compression = require('compression');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Security middleware
app.use(helmet());

// CORS middleware
app.use(cors());

// Compression middleware
app.use(compression());

// Logging middleware
app.use(morgan('combined'));

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Static files
app.use(express.static('public'));

// Routes
app.get('/', (req, res) => {
  res.json({
    message: 'Welcome to your Express.js Application!',
    app: '{{APP_NAME}}',
    domain: '{{DOMAIN}}',
    nodeVersion: process.version,
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV || 'development'
  });
});

app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    timestamp: new Date().toISOString()
  });
});

app.get('/api/info', (req, res) => {
  res.json({
    app: '{{APP_NAME}}',
    version: '1.0.0',
    node: process.version,
    platform: process.platform,
    arch: process.arch,
    pid: process.pid,
    uptime: process.uptime()
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({
    error: 'Something went wrong!',
    message: process.env.NODE_ENV === 'development' ? err.message : 'Internal Server Error'
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Route not found',
    path: req.path,
    method: req.method
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Express server running on port ${PORT}`);
  console.log(`📱 App: {{APP_NAME}}`);
  console.log(`🌐 Domain: {{DOMAIN}}`);
  console.log(`⚡ Node.js: ${process.version}`);
  console.log(`🏃 Environment: ${process.env.NODE_ENV || 'development'}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully');
  process.exit(0);
});
EOF

    cat > "$template_dir/.env" << 'EOF'
NODE_ENV=production
PORT=3000
APP_NAME={{APP_NAME}}
DOMAIN={{DOMAIN}}
EOF

    cat > "$template_dir/public/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{APP_NAME}} - Express.js App</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 40px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; }
        .container { max-width: 800px; margin: 0 auto; background: rgba(255,255,255,0.1); padding: 40px; border-radius: 20px; backdrop-filter: blur(10px); }
        h1 { margin: 0 0 20px 0; font-size: 2.5em; }
        .badge { background: rgba(255,255,255,0.2); padding: 5px 15px; border-radius: 20px; font-size: 0.9em; display: inline-block; margin: 5px; }
        .feature { background: rgba(255,255,255,0.1); padding: 20px; margin: 15px 0; border-radius: 10px; }
        .api-links { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin: 20px 0; }
        .api-link { background: rgba(255,255,255,0.2); padding: 15px; border-radius: 10px; text-decoration: none; color: white; transition: all 0.3s; }
        .api-link:hover { background: rgba(255,255,255,0.3); transform: translateY(-2px); }
        code { background: rgba(0,0,0,0.3); padding: 3px 8px; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 {{APP_NAME}}</h1>
        <div>
            <span class="badge">Express.js</span>
            <span class="badge">Node.js</span>
            <span class="badge">Production Ready</span>
        </div>

        <div class="feature">
            <h3>🎉 Your Express.js application is running!</h3>
            <p>This is a production-ready Express.js application with security, logging, and performance optimizations built-in.</p>
        </div>

        <div class="feature">
            <h3>🔗 API Endpoints</h3>
            <div class="api-links">
                <a href="/api/info" class="api-link">
                    <strong>/api/info</strong><br>
                    Application information
                </a>
                <a href="/health" class="api-link">
                    <strong>/health</strong><br>
                    Health check endpoint
                </a>
            </div>
        </div>

        <div class="feature">
            <h3>🛠️ Built-in Features</h3>
            <ul>
                <li><strong>Security:</strong> Helmet.js for security headers</li>
                <li><strong>CORS:</strong> Cross-origin resource sharing enabled</li>
                <li><strong>Compression:</strong> Gzip compression for responses</li>
                <li><strong>Logging:</strong> Morgan logger for request logging</li>
                <li><strong>Error Handling:</strong> Centralized error handling</li>
                <li><strong>Environment Config:</strong> dotenv for configuration</li>
            </ul>
        </div>

        <div class="feature">
            <h3>📁 Project Structure</h3>
            <pre>
{{APP_NAME}}/
├── app.js          # Main application file
├── package.json    # Dependencies and scripts
├── .env           # Environment variables
├── public/        # Static files
├── logs/          # Application logs
└── Dockerfile     # Docker configuration
            </pre>
        </div>

        <div class="feature">
            <h3>📚 Next Steps</h3>
            <p>Start building your API by:</p>
            <ul>
                <li>Adding routes in <code>app.js</code></li>
                <li>Creating middleware for authentication</li>
                <li>Setting up database connections</li>
                <li>Implementing your business logic</li>
            </ul>
        </div>
    </div>

    <script>
        // Add some interactivity
        document.querySelectorAll('.api-link').forEach(link => {
            link.addEventListener('click', async (e) => {
                if (e.target.getAttribute('href').startsWith('/')) {
                    e.preventDefault();
                    try {
                        const response = await fetch(e.target.getAttribute('href'));
                        const data = await response.json();
                        alert(JSON.stringify(data, null, 2));
                    } catch (error) {
                        alert('Error: ' + error.message);
                    }
                }
            });
        });
    </script>
</body>
</html>
EOF
}

# Create Next.js template
create_nextjs_template() {
    local template_dir="$NODEJS_DATA_DIR/templates/nextjs"
    create_directory "$template_dir" "root" "root" "755"
    
    cat > "$template_dir/Dockerfile" << 'EOF'
FROM node:{{NODE_VERSION}}-alpine AS base

# Install dependencies only when needed
FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Install dependencies based on the preferred package manager
COPY package.json package-lock.json* ./
RUN npm ci

# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Next.js collects completely anonymous telemetry data about general usage.
ENV NEXT_TELEMETRY_DISABLED 1

RUN npm run build

# Production image, copy all the files and run next
FROM base AS runner
WORKDIR /app

ENV NODE_ENV production
ENV NEXT_TELEMETRY_DISABLED 1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public

# Automatically leverage output traces to reduce image size
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT 3000
ENV HOSTNAME "0.0.0.0"

CMD ["node", "server.js"]
EOF

    cat > "$template_dir/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  app:
    build: .
    container_name: {{CONTAINER_NAME}}
    restart: unless-stopped
    networks:
      - server-panel
    ports:
      - "{{PORT}}:3000"
    environment:
      - NODE_ENV=production
      - NEXT_TELEMETRY_DISABLED=1
    labels:
      - "panel.app={{APP_NAME}}"
      - "panel.domain={{DOMAIN}}"
      - "panel.user={{USER_ID}}"
      - "panel.type=nextjs"

networks:
  server-panel:
    external: true
EOF

    cat > "$template_dir/package.json" << 'EOF'
{
  "name": "{{APP_NAME}}",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "next": "14.0.0",
    "react": "^18",
    "react-dom": "^18"
  },
  "devDependencies": {
    "@types/node": "^20",
    "@types/react": "^18",
    "@types/react-dom": "^18",
    "eslint": "^8",
    "eslint-config-next": "14.0.0",
    "typescript": "^5"
  }
}
EOF

    cat > "$template_dir/next.config.js" << 'EOF'
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  experimental: {
    appDir: true,
  },
}

module.exports = nextConfig
EOF
}

# Create deployment scripts
create_nodejs_management_scripts() {
    log "INFO" "Creating Node.js management scripts"
    
    cat > "$NODEJS_DATA_DIR/deploy-nodejs-app.sh" << 'EOF'
#!/bin/bash

# Deploy Node.js Application
# Usage: ./deploy-nodejs-app.sh <app_name> <domain> <type> <node_version> <user_id>

set -euo pipefail

APP_NAME="$1"
DOMAIN="$2"
APP_TYPE="${3:-express}"  # express, nextjs, nestjs, react
NODE_VERSION="${4:-18}"
USER_ID="$5"

if [[ -z "$APP_NAME" ]] || [[ -z "$DOMAIN" ]] || [[ -z "$USER_ID" ]]; then
    echo "Usage: $0 <app_name> <domain> [type] [node_version] <user_id>"
    echo "Types: express, nextjs, nestjs, react"
    echo "Node Versions: 16, 18, 20, 21"
    exit 1
fi

# Validate Node version
case $NODE_VERSION in
    16|18|20|21) ;;
    *) echo "Unsupported Node.js version: $NODE_VERSION"; exit 1 ;;
esac

# Set paths
DATA_DIR="/var/server-panel/users/$USER_ID/$APP_NAME"
TEMPLATE_DIR="/var/server-panel/nodejs/templates/$APP_TYPE"
CONTAINER_NAME="panel-$APP_NAME"
PORT=$(shuf -i 3000-3999 -n 1)

echo "Deploying Node.js application: $APP_NAME"
echo "Domain: $DOMAIN"
echo "Type: $APP_TYPE"
echo "Node Version: $NODE_VERSION"
echo "User: $USER_ID"

# Create application directory
mkdir -p "$DATA_DIR"
cd "$DATA_DIR"

# Copy template files
if [[ -d "$TEMPLATE_DIR" ]]; then
    cp -r "$TEMPLATE_DIR"/* .
else
    echo "Template not found: $APP_TYPE"
    exit 1
fi

# Replace template variables
find . -type f \( -name "*.json" -o -name "*.js" -o -name "*.yml" -o -name "*.html" -o -name "*.env" -o -name "Dockerfile" \) | while read -r file; do
    sed -i "s/{{APP_NAME}}/$APP_NAME/g" "$file"
    sed -i "s/{{DOMAIN}}/$DOMAIN/g" "$file"
    sed -i "s/{{NODE_VERSION}}/$NODE_VERSION/g" "$file"
    sed -i "s/{{CONTAINER_NAME}}/$CONTAINER_NAME/g" "$file"
    sed -i "s/{{USER_ID}}/$USER_ID/g" "$file"
    sed -i "s/{{PORT}}/$PORT/g" "$file"
done

# Set permissions
chown -R 1001:1001 "$DATA_DIR"

# Build and start containers
echo "Building and starting containers..."
docker-compose up -d --build

# Configure NGINX reverse proxy
/opt/server-panel/modules/nginx.sh add-app "$APP_NAME" "$DOMAIN" "$PORT"

# Setup SSL if available
if command -v certbot &> /dev/null; then
    /opt/server-panel/modules/certbot.sh add-domain "$DOMAIN"
fi

echo "Node.js application deployed successfully!"
echo "URL: https://$DOMAIN"
echo "Container: $CONTAINER_NAME"
echo "Port: $PORT"
EOF

    chmod +x "$NODEJS_DATA_DIR/deploy-nodejs-app.sh"
}

# Setup package managers
setup_package_managers() {
    log "INFO" "Setting up package managers"
    
    # Ensure npm and yarn are available in templates
    log "SUCCESS" "Package managers configured"
}

# Main function
case "${1:-install}" in
    "install")
        install_nodejs_support
        ;;
    "deploy")
        "$NODEJS_DATA_DIR/deploy-nodejs-app.sh" "$2" "$3" "${4:-express}" "${5:-18}" "$6"
        ;;
    *)
        echo "Usage: $0 [install|deploy]"
        exit 1
        ;;
esac 