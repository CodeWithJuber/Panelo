#!/bin/bash

# PHP Application Deployment Module
# Supports multiple PHP versions and frameworks

set -euo pipefail

# Source helper functions
source "$(dirname "$0")/helper.sh"

# Configuration
PHP_VERSIONS=("7.4" "8.0" "8.1" "8.2" "8.3")
PHP_DATA_DIR="/var/server-panel/php"

# Install PHP support
install_php_support() {
    log "INFO" "Installing PHP application support"
    
    setup_php_environment
    create_php_templates
    setup_composer_support
    create_php_management_scripts
    
    log "SUCCESS" "PHP application support installed"
}

# Setup PHP environment
setup_php_environment() {
    log "INFO" "Setting up PHP environment"
    
    create_directory "$PHP_DATA_DIR" "root" "root" "755"
    create_directory "$PHP_DATA_DIR/templates" "root" "root" "755"
    create_directory "$PHP_DATA_DIR/configs" "root" "root" "755"
    
    # Pull PHP Docker images
    for version in "${PHP_VERSIONS[@]}"; do
        log "INFO" "Pulling PHP $version Docker image"
        docker pull "php:${version}-fpm-alpine" || log "WARN" "Failed to pull PHP $version image"
        docker pull "php:${version}-apache" || log "WARN" "Failed to pull PHP $version Apache image"
    done
    
    # Pull additional tools
    docker pull composer:latest
    docker pull nginx:alpine
    
    log "SUCCESS" "PHP environment setup completed"
}

# Create PHP application templates
create_php_templates() {
    log "INFO" "Creating PHP application templates"
    
    # Basic PHP template
    create_basic_php_template
    
    # Laravel template
    create_laravel_template
    
    # CodeIgniter template
    create_codeigniter_template
    
    # Symfony template
    create_symfony_template
    
    log "SUCCESS" "PHP templates created"
}

# Create basic PHP template
create_basic_php_template() {
    local template_dir="$PHP_DATA_DIR/templates/basic"
    create_directory "$template_dir" "root" "root" "755"
    create_directory "$template_dir/public" "root" "root" "755"
    
    cat > "$template_dir/Dockerfile" << 'EOF'
FROM php:{{PHP_VERSION}}-fpm-alpine

# Install system dependencies
RUN apk add --no-cache \
    freetype-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    libzip-dev \
    icu-dev \
    oniguruma-dev

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    gd \
    mysqli \
    pdo \
    pdo_mysql \
    zip \
    intl \
    mbstring \
    opcache

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www/html

# Copy application
COPY . .

# Set permissions
RUN chown -R www-data:www-data /var/www/html

# Install dependencies if composer.json exists
RUN if [ -f composer.json ]; then composer install --no-dev --optimize-autoloader; fi

EXPOSE 9000

CMD ["php-fpm"]
EOF

    cat > "$template_dir/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  php:
    build: .
    container_name: {{CONTAINER_NAME}}
    restart: unless-stopped
    networks:
      - server-panel
    volumes:
      - ./:/var/www/html
    environment:
      - PHP_VERSION={{PHP_VERSION}}
    labels:
      - "panel.app={{APP_NAME}}"
      - "panel.domain={{DOMAIN}}"
      - "panel.user={{USER_ID}}"
      - "panel.type=php"

  nginx:
    image: nginx:alpine
    container_name: {{CONTAINER_NAME}}-nginx
    restart: unless-stopped
    networks:
      - server-panel
    ports:
      - "{{PORT}}:80"
    volumes:
      - ./:/var/www/html
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - php
    labels:
      - "panel.app={{APP_NAME}}"
      - "panel.domain={{DOMAIN}}"

networks:
  server-panel:
    external: true
EOF

    cat > "$template_dir/nginx.conf" << 'EOF'
server {
    listen 80;
    server_name {{DOMAIN}};
    root /var/www/html/public;
    index index.php index.html index.htm;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass php:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
        fastcgi_buffering off;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

    cat > "$template_dir/public/index.php" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PHP Application</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 2px solid #007cba; padding-bottom: 10px; }
        .info { background: #e8f4f8; padding: 20px; border-radius: 5px; margin: 20px 0; }
        .feature { background: #f0f8ff; padding: 15px; margin: 10px 0; border-left: 4px solid #007cba; }
        pre { background: #f4f4f4; padding: 15px; border-radius: 5px; overflow-x: auto; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🐘 Welcome to your PHP Application!</h1>
        
        <div class="info">
            <h3>Server Information</h3>
            <p><strong>PHP Version:</strong> <?php echo PHP_VERSION; ?></p>
            <p><strong>Server Software:</strong> <?php echo $_SERVER['SERVER_SOFTWARE'] ?? 'Unknown'; ?></p>
            <p><strong>Server Time:</strong> <?php echo date('Y-m-d H:i:s T'); ?></p>
            <p><strong>Document Root:</strong> <?php echo $_SERVER['DOCUMENT_ROOT']; ?></p>
        </div>

        <div class="feature">
            <h3>🚀 Getting Started</h3>
            <p>Your PHP application is ready! Here's what you can do:</p>
            <ul>
                <li>Upload your PHP files to the <code>public/</code> directory</li>
                <li>Use Composer for dependency management</li>
                <li>Configure your database connection</li>
                <li>Set up your routing and MVC structure</li>
            </ul>
        </div>

        <div class="feature">
            <h3>📦 Available PHP Extensions</h3>
            <pre><?php
                $extensions = get_loaded_extensions();
                sort($extensions);
                echo implode(', ', $extensions);
            ?></pre>
        </div>

        <div class="feature">
            <h3>🔧 Configuration</h3>
            <p>Edit your application settings:</p>
            <ul>
                <li><strong>PHP Configuration:</strong> Modify Dockerfile for custom PHP settings</li>
                <li><strong>Nginx Configuration:</strong> Edit nginx.conf for web server settings</li>
                <li><strong>Environment Variables:</strong> Use docker-compose.yml environment section</li>
            </ul>
        </div>

        <?php if (file_exists('../composer.json')): ?>
        <div class="feature">
            <h3>📚 Composer Dependencies</h3>
            <p>Composer.json detected! Your dependencies will be automatically installed.</p>
            <?php
                $composer = json_decode(file_get_contents('../composer.json'), true);
                if (isset($composer['require'])):
            ?>
            <pre><?php echo json_encode($composer['require'], JSON_PRETTY_PRINT); ?></pre>
            <?php endif; ?>
        </div>
        <?php endif; ?>

        <div class="feature">
            <h3>📖 Next Steps</h3>
            <p>Ready to build something amazing? Consider these popular PHP frameworks:</p>
            <ul>
                <li><strong>Laravel:</strong> The PHP framework for web artisans</li>
                <li><strong>Symfony:</strong> High performance PHP framework</li>
                <li><strong>CodeIgniter:</strong> Simple and elegant PHP framework</li>
                <li><strong>Slim:</strong> Micro framework for APIs and microservices</li>
            </ul>
        </div>
    </div>
</body>
</html>
EOF

    cat > "$template_dir/composer.json" << 'EOF'
{
    "name": "serverpanel/php-app",
    "description": "Server Panel PHP Application",
    "type": "project",
    "require": {
        "php": ">=7.4"
    },
    "require-dev": {
        "phpunit/phpunit": "^9.0"
    },
    "autoload": {
        "psr-4": {
            "App\\": "src/"
        }
    },
    "scripts": {
        "test": "phpunit",
        "start": "php -S 0.0.0.0:8000 -t public"
    }
}
EOF
}

# Create Laravel template
create_laravel_template() {
    local template_dir="$PHP_DATA_DIR/templates/laravel"
    create_directory "$template_dir" "root" "root" "755"
    
    cat > "$template_dir/Dockerfile" << 'EOF'
FROM php:{{PHP_VERSION}}-fpm-alpine

# Install system dependencies
RUN apk add --no-cache \
    freetype-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    libzip-dev \
    icu-dev \
    oniguruma-dev \
    nodejs \
    npm

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    gd \
    mysqli \
    pdo \
    pdo_mysql \
    zip \
    intl \
    mbstring \
    opcache \
    bcmath

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www/html

# Copy application
COPY . .

# Set permissions
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 775 /var/www/html/storage \
    && chmod -R 775 /var/www/html/bootstrap/cache

# Install dependencies
RUN composer install --no-dev --optimize-autoloader

# Install and build frontend assets
RUN if [ -f package.json ]; then npm install && npm run build; fi

EXPOSE 9000

CMD ["php-fpm"]
EOF

    cat > "$template_dir/nginx.conf" << 'EOF'
server {
    listen 80;
    server_name {{DOMAIN}};
    root /var/www/html/public;
    index index.php;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;

    # Laravel specific configurations
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;

    location ~ \.php$ {
        fastcgi_pass php:9000;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
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
    volumes:
      - ./:/var/www/html
    environment:
      - APP_ENV=production
      - APP_DEBUG=false
      - APP_KEY={{APP_KEY}}
      - DB_CONNECTION=mysql
      - DB_HOST=mysql
      - DB_PORT=3306
      - DB_DATABASE={{DB_NAME}}
      - DB_USERNAME={{DB_USER}}
      - DB_PASSWORD={{DB_PASSWORD}}
    depends_on:
      - redis
    labels:
      - "panel.app={{APP_NAME}}"
      - "panel.domain={{DOMAIN}}"
      - "panel.user={{USER_ID}}"
      - "panel.type=laravel"

  nginx:
    image: nginx:alpine
    container_name: {{CONTAINER_NAME}}-nginx
    restart: unless-stopped
    networks:
      - server-panel
    ports:
      - "{{PORT}}:80"
    volumes:
      - ./:/var/www/html
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - app
    labels:
      - "panel.app={{APP_NAME}}"
      - "panel.domain={{DOMAIN}}"

  redis:
    image: redis:alpine
    container_name: {{CONTAINER_NAME}}-redis
    restart: unless-stopped
    networks:
      - server-panel
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data

  scheduler:
    build: .
    container_name: {{CONTAINER_NAME}}-scheduler
    restart: unless-stopped
    networks:
      - server-panel
    volumes:
      - ./:/var/www/html
    environment:
      - APP_ENV=production
      - DB_CONNECTION=mysql
      - DB_HOST=mysql
      - DB_PORT=3306
      - DB_DATABASE={{DB_NAME}}
      - DB_USERNAME={{DB_USER}}
      - DB_PASSWORD={{DB_PASSWORD}}
    command: php artisan schedule:work
    depends_on:
      - app

  queue:
    build: .
    container_name: {{CONTAINER_NAME}}-queue
    restart: unless-stopped
    networks:
      - server-panel
    volumes:
      - ./:/var/www/html
    environment:
      - APP_ENV=production
      - DB_CONNECTION=mysql
      - DB_HOST=mysql
      - DB_PORT=3306
      - DB_DATABASE={{DB_NAME}}
      - DB_USERNAME={{DB_USER}}
      - DB_PASSWORD={{DB_PASSWORD}}
    command: php artisan queue:work --sleep=3 --tries=3
    depends_on:
      - app

volumes:
  redis_data:

networks:
  server-panel:
    external: true
EOF
}

# Create CodeIgniter template
create_codeigniter_template() {
    local template_dir="$PHP_DATA_DIR/templates/codeigniter"
    create_directory "$template_dir" "root" "root" "755"
    create_directory "$template_dir/public" "root" "root" "755"
    
    cat > "$template_dir/Dockerfile" << 'EOF'
FROM php:{{PHP_VERSION}}-fpm-alpine

# Install system dependencies
RUN apk add --no-cache \
    freetype-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    libzip-dev \
    icu-dev \
    oniguruma-dev

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    gd \
    mysqli \
    pdo \
    pdo_mysql \
    zip \
    intl \
    mbstring \
    opcache

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www/html

# Copy application
COPY . .

# Set permissions
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 775 /var/www/html/writable

# Install dependencies
RUN composer install --no-dev --optimize-autoloader

EXPOSE 9000

CMD ["php-fpm"]
EOF

    cat > "$template_dir/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  php:
    build: .
    container_name: {{CONTAINER_NAME}}
    restart: unless-stopped
    networks:
      - server-panel
    volumes:
      - ./:/var/www/html
    environment:
      - CI_ENVIRONMENT=production
      - database.default.hostname=mysql
      - database.default.database={{DB_NAME}}
      - database.default.username={{DB_USER}}
      - database.default.password={{DB_PASSWORD}}
    labels:
      - "panel.app={{APP_NAME}}"
      - "panel.domain={{DOMAIN}}"
      - "panel.user={{USER_ID}}"
      - "panel.type=codeigniter"

  nginx:
    image: nginx:alpine
    container_name: {{CONTAINER_NAME}}-nginx
    restart: unless-stopped
    networks:
      - server-panel
    ports:
      - "{{PORT}}:80"
    volumes:
      - ./:/var/www/html
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - php
    labels:
      - "panel.app={{APP_NAME}}"
      - "panel.domain={{DOMAIN}}"

networks:
  server-panel:
    external: true
EOF

    cat > "$template_dir/nginx.conf" << 'EOF'
server {
    listen 80;
    server_name {{DOMAIN}};
    root /var/www/html/public;
    index index.php;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;

    # CodeIgniter specific configurations
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass php:9000;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

    cat > "$template_dir/public/index.php" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CodeIgniter Application</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 2px solid #dd4814; padding-bottom: 10px; }
        .info { background: #f8e8e8; padding: 20px; border-radius: 5px; margin: 20px 0; }
        .feature { background: #fff8f0; padding: 15px; margin: 10px 0; border-left: 4px solid #dd4814; }
        pre { background: #f4f4f4; padding: 15px; border-radius: 5px; overflow-x: auto; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔥 Welcome to CodeIgniter!</h1>
        
        <div class="info">
            <h3>Server Information</h3>
            <p><strong>PHP Version:</strong> <?php echo PHP_VERSION; ?></p>
            <p><strong>Server Software:</strong> <?php echo $_SERVER['SERVER_SOFTWARE'] ?? 'Unknown'; ?></p>
            <p><strong>Server Time:</strong> <?php echo date('Y-m-d H:i:s T'); ?></p>
            <p><strong>Document Root:</strong> <?php echo $_SERVER['DOCUMENT_ROOT']; ?></p>
        </div>

        <div class="feature">
            <h3>🚀 Getting Started with CodeIgniter</h3>
            <p>Your CodeIgniter application is ready! Here's what you can do:</p>
            <ul>
                <li>Create controllers in the <code>Controllers/</code> directory</li>
                <li>Add views in the <code>Views/</code> directory</li>
                <li>Create models in the <code>Models/</code> directory</li>
                <li>Configure your routes in <code>Config/Routes.php</code></li>
            </ul>
        </div>

        <div class="feature">
            <h3>📚 CodeIgniter Features</h3>
            <ul>
                <li><strong>MVC Architecture:</strong> Clean separation of concerns</li>
                <li><strong>Database Integration:</strong> Built-in database abstraction</li>
                <li><strong>Form Validation:</strong> Robust validation system</li>
                <li><strong>Session Management:</strong> Secure session handling</li>
                <li><strong>Security:</strong> CSRF protection and XSS filtering</li>
            </ul>
        </div>
    </div>
</body>
</html>
EOF
}

# Create Symfony template
create_symfony_template() {
    local template_dir="$PHP_DATA_DIR/templates/symfony"
    create_directory "$template_dir" "root" "root" "755"
    create_directory "$template_dir/public" "root" "root" "755"
    
    cat > "$template_dir/Dockerfile" << 'EOF'
FROM php:{{PHP_VERSION}}-fpm-alpine

# Install system dependencies
RUN apk add --no-cache \
    freetype-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    libzip-dev \
    icu-dev \
    oniguruma-dev \
    nodejs \
    npm

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    gd \
    mysqli \
    pdo \
    pdo_mysql \
    zip \
    intl \
    mbstring \
    opcache \
    bcmath

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www/html

# Copy application
COPY . .

# Set permissions
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 775 /var/www/html/var

# Install dependencies
RUN composer install --no-dev --optimize-autoloader

# Install and build frontend assets
RUN if [ -f package.json ]; then npm install && npm run build; fi

EXPOSE 9000

CMD ["php-fpm"]
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
    volumes:
      - ./:/var/www/html
    environment:
      - APP_ENV=prod
      - APP_SECRET={{APP_SECRET}}
      - DATABASE_URL=mysql://{{DB_USER}}:{{DB_PASSWORD}}@mysql:3306/{{DB_NAME}}
    labels:
      - "panel.app={{APP_NAME}}"
      - "panel.domain={{DOMAIN}}"
      - "panel.user={{USER_ID}}"
      - "panel.type=symfony"

  nginx:
    image: nginx:alpine
    container_name: {{CONTAINER_NAME}}-nginx
    restart: unless-stopped
    networks:
      - server-panel
    ports:
      - "{{PORT}}:80"
    volumes:
      - ./:/var/www/html
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - app
    labels:
      - "panel.app={{APP_NAME}}"
      - "panel.domain={{DOMAIN}}"

networks:
  server-panel:
    external: true
EOF

    cat > "$template_dir/nginx.conf" << 'EOF'
server {
    listen 80;
    server_name {{DOMAIN}};
    root /var/www/html/public;
    index index.php;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;

    # Symfony specific configurations
    location / {
        try_files $uri $uri/ /index.php$is_args$args;
    }

    location ~ \.php$ {
        fastcgi_pass app:9000;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

    cat > "$template_dir/public/index.php" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Symfony Application</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 2px solid #326295; padding-bottom: 10px; }
        .info { background: #e8f4f8; padding: 20px; border-radius: 5px; margin: 20px 0; }
        .feature { background: #f0f8ff; padding: 15px; margin: 10px 0; border-left: 4px solid #326295; }
        pre { background: #f4f4f4; padding: 15px; border-radius: 5px; overflow-x: auto; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎵 Welcome to Symfony!</h1>
        
        <div class="info">
            <h3>Server Information</h3>
            <p><strong>PHP Version:</strong> <?php echo PHP_VERSION; ?></p>
            <p><strong>Server Software:</strong> <?php echo $_SERVER['SERVER_SOFTWARE'] ?? 'Unknown'; ?></p>
            <p><strong>Server Time:</strong> <?php echo date('Y-m-d H:i:s T'); ?></p>
            <p><strong>Document Root:</strong> <?php echo $_SERVER['DOCUMENT_ROOT']; ?></p>
        </div>

        <div class="feature">
            <h3>🚀 Getting Started with Symfony</h3>
            <p>Your Symfony application is ready! Here's what you can do:</p>
            <ul>
                <li>Create controllers using <code>bin/console make:controller</code></li>
                <li>Generate entities with <code>bin/console make:entity</code></li>
                <li>Set up routing in <code>config/routes.yaml</code></li>
                <li>Create templates in the <code>templates/</code> directory</li>
            </ul>
        </div>

        <div class="feature">
            <h3>🛠 Symfony Components</h3>
            <ul>
                <li><strong>HttpFoundation:</strong> HTTP request/response abstraction</li>
                <li><strong>Routing:</strong> Flexible URL routing system</li>
                <li><strong>Twig:</strong> Modern template engine</li>
                <li><strong>Doctrine:</strong> Database ORM integration</li>
                <li><strong>Security:</strong> Authentication and authorization</li>
                <li><strong>Form:</strong> Form creation and validation</li>
            </ul>
        </div>

        <div class="feature">
            <h3>🔧 Development Tools</h3>
            <p>Symfony provides excellent development tools:</p>
            <ul>
                <li><strong>Maker Bundle:</strong> Code generation commands</li>
                <li><strong>Profiler:</strong> Debug toolbar and profiler</li>
                <li><strong>Flex:</strong> Composer plugin for recipes</li>
                <li><strong>Console:</strong> Command-line interface</li>
            </ul>
        </div>
    </div>
</body>
</html>
EOF
}

# Create deployment scripts
create_php_management_scripts() {
    log "INFO" "Creating PHP management scripts"
    
    cat > "$PHP_DATA_DIR/deploy-php-app.sh" << 'EOF'
#!/bin/bash

# Deploy PHP Application
# Usage: ./deploy-php-app.sh <app_name> <domain> <type> <php_version> <user_id>

set -euo pipefail

APP_NAME="$1"
DOMAIN="$2"
APP_TYPE="${3:-basic}"  # basic, laravel, symfony, codeigniter
PHP_VERSION="${4:-8.2}"
USER_ID="$5"

if [[ -z "$APP_NAME" ]] || [[ -z "$DOMAIN" ]] || [[ -z "$USER_ID" ]]; then
    echo "Usage: $0 <app_name> <domain> [type] [php_version] <user_id>"
    echo "Types: basic, laravel, symfony, codeigniter"
    echo "PHP Versions: 7.4, 8.0, 8.1, 8.2, 8.3"
    exit 1
fi

# Validate PHP version
case $PHP_VERSION in
    7.4|8.0|8.1|8.2|8.3) ;;
    *) echo "Unsupported PHP version: $PHP_VERSION"; exit 1 ;;
esac

# Set paths
DATA_DIR="/var/server-panel/users/$USER_ID/$APP_NAME"
TEMPLATE_DIR="/var/server-panel/php/templates/$APP_TYPE"
CONTAINER_NAME="panel-$APP_NAME"
PORT=$(shuf -i 8000-8999 -n 1)

echo "Deploying PHP application: $APP_NAME"
echo "Domain: $DOMAIN"
echo "Type: $APP_TYPE"
echo "PHP Version: $PHP_VERSION"
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
find . -type f -name "*.yml" -o -name "*.conf" -o -name "Dockerfile" | while read -r file; do
    sed -i "s/{{APP_NAME}}/$APP_NAME/g" "$file"
    sed -i "s/{{DOMAIN}}/$DOMAIN/g" "$file"
    sed -i "s/{{PHP_VERSION}}/$PHP_VERSION/g" "$file"
    sed -i "s/{{CONTAINER_NAME}}/$CONTAINER_NAME/g" "$file"
    sed -i "s/{{USER_ID}}/$USER_ID/g" "$file"
    sed -i "s/{{PORT}}/$PORT/g" "$file"
done

# Create database if needed
if [[ "$APP_TYPE" == "laravel" ]] || [[ "$APP_TYPE" == "symfony" ]]; then
    DB_NAME="db_$APP_NAME"
    DB_USER="user_$APP_NAME"
    DB_PASSWORD=$(openssl rand -base64 16)
    
    # Create database
    /opt/server-panel/modules/mysql.sh create-db "$APP_NAME" "$DB_USER" "$DB_PASSWORD"
    
    # Update database configuration
    find . -type f -name "*.yml" -o -name "*.env" | while read -r file; do
        sed -i "s/{{DB_NAME}}/$DB_NAME/g" "$file"
        sed -i "s/{{DB_USER}}/$DB_USER/g" "$file"
        sed -i "s/{{DB_PASSWORD}}/$DB_PASSWORD/g" "$file"
    done
    
    # Generate Laravel app key
    if [[ "$APP_TYPE" == "laravel" ]]; then
        APP_KEY=$(openssl rand -base64 32)
        sed -i "s/{{APP_KEY}}/$APP_KEY/g" docker-compose.yml
    fi
fi

# Set permissions
chown -R www-data:www-data "$DATA_DIR"

# Build and start containers
echo "Building and starting containers..."
docker-compose up -d --build

# Configure NGINX reverse proxy
/opt/server-panel/modules/nginx.sh add-app "$APP_NAME" "$DOMAIN" "$PORT"

# Setup SSL if available
if command -v certbot &> /dev/null; then
    /opt/server-panel/modules/certbot.sh add-domain "$DOMAIN"
fi

echo "PHP application deployed successfully!"
echo "URL: https://$DOMAIN"
echo "Container: $CONTAINER_NAME"
if [[ -n "${DB_NAME:-}" ]]; then
    echo "Database: $DB_NAME"
    echo "DB User: $DB_USER"
fi
EOF

    chmod +x "$PHP_DATA_DIR/deploy-php-app.sh"
}

# Setup Composer support
setup_composer_support() {
    log "INFO" "Setting up Composer support"
    
    # Ensure Composer is available
    if ! command -v composer &> /dev/null; then
        curl -sS https://getcomposer.org/installer | php
        mv composer.phar /usr/local/bin/composer
        chmod +x /usr/local/bin/composer
    fi
}

# Main function
case "${1:-install}" in
    "install")
        install_php_support
        ;;
    "deploy")
        "$PHP_DATA_DIR/deploy-php-app.sh" "$2" "$3" "${4:-basic}" "${5:-8.2}" "$6"
        ;;
    *)
        echo "Usage: $0 [install|deploy]"
        exit 1
        ;;
esac 