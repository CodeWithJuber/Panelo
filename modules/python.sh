#!/bin/bash

# Python Module for Server Panel
# Provides Python application support (Flask, Django, FastAPI)

# Source helper functions
source "$(dirname "$0")/helper.sh"

# Python configuration
PYTHON_DATA_DIR="/var/server-panel/python"
PYTHON_VERSIONS=("3.8" "3.9" "3.10" "3.11" "3.12")

# Install Python support
install_python_support() {
    log "INFO" "Setting up Python application support"
    
    # Create Python data directory
    create_directory "$PYTHON_DATA_DIR" "root" "root" "755"
    create_directory "$PYTHON_DATA_DIR/templates" "root" "root" "755"
    
    # Install Python versions via Docker
    install_python_versions
    
    # Create application templates
    create_python_templates
    
    log "SUCCESS" "Python application support installed"
}

# Install Python versions
install_python_versions() {
    log "INFO" "Installing Python versions"
    
    for version in "${PYTHON_VERSIONS[@]}"; do
        log "INFO" "Pulling Python $version image"
        docker pull "python:$version-slim" >/dev/null 2>&1 &
    done
    
    # Wait for all images to download
    wait
    
    log "SUCCESS" "Python versions installed"
}

# Create Python templates
create_python_templates() {
    log "INFO" "Creating Python application templates"
    
    # Flask template
    create_flask_template
    
    # Django template  
    create_django_template
    
    # FastAPI template
    create_fastapi_template
    
    log "SUCCESS" "Python templates created"
}

# Create Flask template
create_flask_template() {
    local template_dir="$PYTHON_DATA_DIR/templates/flask"
    create_directory "$template_dir" "root" "root" "755"
    
    cat > "$template_dir/Dockerfile" << 'EOF'
FROM python:{{PYTHON_VERSION}}-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV FLASK_APP=app.py
ENV FLASK_ENV=production

RUN apt-get update && apt-get install -y gcc && rm -rf /var/lib/apt/lists/*

WORKDIR /app
RUN adduser --disabled-password --gecos '' --uid 1001 flask

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
RUN chown -R flask:flask /app
USER flask

EXPOSE 5000
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "app:app"]
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
      - "{{PORT}}:5000"
    environment:
      - FLASK_ENV=production
    labels:
      - "panel.app={{APP_NAME}}"
      - "panel.domain={{DOMAIN}}"
      - "panel.user={{USER_ID}}"
      - "panel.type=flask"

networks:
  server-panel:
    external: true
EOF

    cat > "$template_dir/requirements.txt" << 'EOF'
Flask==2.3.3
gunicorn==21.2.0
Flask-CORS==4.0.0
python-dotenv==1.0.0
Werkzeug==2.3.7
EOF

    cat > "$template_dir/app.py" << 'EOF'
from flask import Flask, jsonify, render_template_string
from flask_cors import CORS
from datetime import datetime
import sys

app = Flask(__name__)
CORS(app)

# HTML template for the welcome page
HTML_TEMPLATE = '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{APP_NAME}} - Flask Application</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 40px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; min-height: 100vh; }
        .container { max-width: 800px; margin: 0 auto; }
        h1 { font-size: 3em; margin-bottom: 20px; }
        .card { background: rgba(255,255,255,0.1); padding: 30px; border-radius: 15px; margin: 20px 0; backdrop-filter: blur(10px); }
        .api-link { display: inline-block; margin: 10px; padding: 10px 20px; background: #007bff; color: white; text-decoration: none; border-radius: 5px; }
        .api-link:hover { background: #0056b3; }
        pre { background: rgba(0,0,0,0.3); padding: 15px; border-radius: 5px; overflow-x: auto; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🐍 {{APP_NAME}}</h1>
        <div class="card">
            <h3>Flask Application Running!</h3>
            <p>Your Flask application is successfully deployed and running on Python.</p>
            <div>
                <a href="/api/info" class="api-link">API Info</a>
                <a href="/health" class="api-link">Health Check</a>
            </div>
        </div>
        <div class="card">
            <h3>🚀 Next Steps</h3>
            <ul>
                <li>Add your routes in <code>app.py</code></li>
                <li>Create templates for your pages</li>
                <li>Add static files (CSS, JS)</li>
                <li>Configure database connections</li>
            </ul>
        </div>
    </div>
</body>
</html>
'''

@app.route('/')
def index():
    return render_template_string(HTML_TEMPLATE)

@app.route('/api/info')
def api_info():
    return jsonify({
        'app': '{{APP_NAME}}',
        'framework': 'Flask',
        'version': '1.0.0',
        'python_version': sys.version,
        'timestamp': datetime.utcnow().isoformat(),
        'status': 'running'
    })

@app.route('/health')
def health():
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat()
    })

@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Not found'}), 404

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
EOF
}

# Create Django template
create_django_template() {
    local template_dir="$PYTHON_DATA_DIR/templates/django"
    create_directory "$template_dir" "root" "root" "755"
    create_directory "$template_dir/project" "root" "root" "755"
    
    cat > "$template_dir/Dockerfile" << 'EOF'
FROM python:{{PYTHON_VERSION}}-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV DJANGO_SETTINGS_MODULE=project.settings

RUN apt-get update && apt-get install -y gcc && rm -rf /var/lib/apt/lists/*

WORKDIR /app
RUN adduser --disabled-password --gecos '' --uid 1001 django

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
RUN python manage.py collectstatic --noinput || true
RUN chown -R django:django /app
USER django

EXPOSE 8000
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", "project.wsgi:application"]
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
      - "{{PORT}}:8000"
    environment:
      - DJANGO_SETTINGS_MODULE=project.settings
    labels:
      - "panel.app={{APP_NAME}}"
      - "panel.domain={{DOMAIN}}"
      - "panel.user={{USER_ID}}"
      - "panel.type=django"

networks:
  server-panel:
    external: true
EOF

    cat > "$template_dir/requirements.txt" << 'EOF'
Django==4.2.7
gunicorn==21.2.0
django-cors-headers==4.3.1
python-dotenv==1.0.0
whitenoise==6.6.0
EOF

    cat > "$template_dir/manage.py" << 'EOF'
#!/usr/bin/env python
import os
import sys

if __name__ == '__main__':
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'project.settings')
    try:
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        raise ImportError(
            "Couldn't import Django. Are you sure it's installed?"
        ) from exc
    execute_from_command_line(sys.argv)
EOF

    chmod +x "$template_dir/manage.py"

    cat > "$template_dir/project/__init__.py" << 'EOF'
EOF

    cat > "$template_dir/project/settings.py" << 'EOF'
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = 'django-insecure-dev-key-change-in-production'
DEBUG = False
ALLOWED_HOSTS = ['*']

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth', 
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'corsheaders',
]

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'project.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'project.wsgi.application'

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

CORS_ALLOW_ALL_ORIGINS = True
EOF

    cat > "$template_dir/project/urls.py" << 'EOF'
from django.contrib import admin
from django.urls import path
from django.http import JsonResponse, HttpResponse
from datetime import datetime
import sys

def index(request):
    html = '''
    <!DOCTYPE html>
    <html>
    <head>
        <title>{{APP_NAME}} - Django Application</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 0; padding: 40px; background: linear-gradient(135deg, #2E8B57 0%, #3CB371 100%); color: white; min-height: 100vh; }
            .container { max-width: 800px; margin: 0 auto; }
            h1 { font-size: 3em; margin-bottom: 20px; }
            .card { background: rgba(255,255,255,0.1); padding: 30px; border-radius: 15px; margin: 20px 0; backdrop-filter: blur(10px); }
            .api-link { display: inline-block; margin: 10px; padding: 10px 20px; background: #2E8B57; color: white; text-decoration: none; border-radius: 5px; }
            .api-link:hover { background: #228B22; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🐍 {{APP_NAME}}</h1>
            <div class="card">
                <h3>Django Application Running!</h3>
                <p>Your Django application is successfully deployed and running.</p>
                <div>
                    <a href="/api/info/" class="api-link">API Info</a>
                    <a href="/health/" class="api-link">Health Check</a>
                    <a href="/admin/" class="api-link">Admin Panel</a>
                </div>
            </div>
            <div class="card">
                <h3>🚀 Next Steps</h3>
                <ul>
                    <li>Create Django apps with <code>python manage.py startapp</code></li>
                    <li>Define models and run migrations</li>
                    <li>Create a superuser for admin access</li>
                    <li>Add your views and URLs</li>
                </ul>
            </div>
        </div>
    </body>
    </html>
    '''
    return HttpResponse(html)

def api_info(request):
    return JsonResponse({
        'app': '{{APP_NAME}}',
        'framework': 'Django',
        'version': '1.0.0',
        'python_version': sys.version,
        'timestamp': datetime.utcnow().isoformat(),
        'status': 'running'
    })

def health(request):
    return JsonResponse({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat()
    })

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', index, name='index'),
    path('api/info/', api_info, name='api_info'),
    path('health/', health, name='health'),
]
EOF

    cat > "$template_dir/project/wsgi.py" << 'EOF'
import os
from django.core.wsgi import get_wsgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'project.settings')
application = get_wsgi_application()
EOF
}

# Create FastAPI template
create_fastapi_template() {
    local template_dir="$PYTHON_DATA_DIR/templates/fastapi"
    create_directory "$template_dir" "root" "root" "755"
    
    cat > "$template_dir/Dockerfile" << 'EOF'
FROM python:{{PYTHON_VERSION}}-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y gcc && rm -rf /var/lib/apt/lists/*

WORKDIR /app
RUN adduser --disabled-password --gecos '' --uid 1001 fastapi

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
RUN chown -R fastapi:fastapi /app
USER fastapi

EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
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
      - "{{PORT}}:8000"
    labels:
      - "panel.app={{APP_NAME}}"
      - "panel.domain={{DOMAIN}}"
      - "panel.user={{USER_ID}}"
      - "panel.type=fastapi"

networks:
  server-panel:
    external: true
EOF

    cat > "$template_dir/requirements.txt" << 'EOF'
fastapi==0.104.1
uvicorn[standard]==0.24.0
python-dotenv==1.0.0
jinja2==3.1.2
python-multipart==0.0.6
EOF

    cat > "$template_dir/main.py" << 'EOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from datetime import datetime
import sys

app = FastAPI(
    title="{{APP_NAME}}",
    description="FastAPI application deployed with Server Panel",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

HTML_TEMPLATE = '''
<!DOCTYPE html>
<html>
<head>
    <title>{{APP_NAME}} - FastAPI Application</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 40px; background: linear-gradient(135deg, #ff6b6b 0%, #ee5a24 100%); color: white; min-height: 100vh; }
        .container { max-width: 800px; margin: 0 auto; }
        h1 { font-size: 3em; margin-bottom: 20px; }
        .card { background: rgba(255,255,255,0.1); padding: 30px; border-radius: 15px; margin: 20px 0; backdrop-filter: blur(10px); }
        .api-link { display: inline-block; margin: 10px; padding: 10px 20px; background: #ff6b6b; color: white; text-decoration: none; border-radius: 5px; }
        .api-link:hover { background: #ee5a24; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 {{APP_NAME}}</h1>
        <div class="card">
            <h3>FastAPI Application Running!</h3>
            <p>Your FastAPI application is successfully deployed and running with automatic API documentation.</p>
            <div>
                <a href="/api/info" class="api-link">API Info</a>
                <a href="/health" class="api-link">Health Check</a>
                <a href="/docs" class="api-link">Interactive Docs</a>
                <a href="/redoc" class="api-link">ReDoc</a>
            </div>
        </div>
        <div class="card">
            <h3>⚡ FastAPI Features</h3>
            <ul>
                <li>Automatic API documentation with Swagger UI</li>
                <li>High performance with async/await support</li>
                <li>Type hints for automatic validation</li>
                <li>Modern Python 3.7+ features</li>
            </ul>
        </div>
    </div>
</body>
</html>
'''

@app.get("/", response_class=HTMLResponse)
async def root():
    return HTML_TEMPLATE

@app.get("/api/info")
async def api_info():
    return {
        "app": "{{APP_NAME}}",
        "framework": "FastAPI",
        "version": "1.0.0",
        "python_version": sys.version,
        "timestamp": datetime.utcnow().isoformat(),
        "status": "running",
        "docs_url": "/docs",
        "redoc_url": "/redoc"
    }

@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat()
    }
EOF
}

# Main function
case "${1:-install}" in
    "install")
        install_python_support
        ;;
    *)
        echo "Usage: $0 [install]"
        exit 1
        ;;
esac
