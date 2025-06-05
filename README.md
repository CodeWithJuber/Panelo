# Panelo - Complete cPanel Alternative

A complete server management panel that provides cPanel-like functionality with modern Docker-based architecture. This system supports WordPress, static sites, PHP, Node.js, Python applications with per-user isolation, file management, SSL certificates, and database management.

## 🚀 Features

### Core Infrastructure
- **Docker-based isolation** - Each application runs in its own container
- **Multiple web servers** - NGINX (default) or Apache support
- **Database support** - MySQL and PostgreSQL options
- **SSL/TLS management** - Automatic Let's Encrypt certificates
- **File management** - Web-based file browser with editing capabilities
- **User management** - Multi-user support with role-based access

### Application Support
- **WordPress** - One-click WordPress deployments
- **Static websites** - HTML/CSS/JS hosting
- **PHP applications** - Full PHP support with Apache/NGINX (Laravel, CodeIgniter)
- **Node.js applications** - Express, Next.js, NestJS support
- **Python applications** - Flask, Django, and other Python frameworks
- **Custom applications** - Support for custom Dockerfiles

### Management Features
- **Modern web interface** - Built with Next.js and Tailwind CSS
- **RESTful API** - Complete NestJS-based backend API
- **Real-time monitoring** - Prometheus + Grafana with custom metrics
- **System monitoring** - CPU, memory, disk usage tracking with alerts
- **Automatic backups** - Database and file backups with scheduling
- **Security** - Fail2ban, firewall management, and security headers
- **DNS management** - Optional Cloudflare integration

## 📋 Requirements

### System Requirements
- **Operating System**: Ubuntu 20.04+, Debian 11+, CentOS 8+, or RHEL 8+
- **Memory**: Minimum 2GB RAM (4GB+ recommended)
- **Storage**: Minimum 20GB free disk space
- **Network**: Public IP address and domain name
- **Root access**: Required for installation

### Prerequisites
- Fresh Linux server installation
- Domain name pointing to the server IP
- Email address for SSL certificates

## ⚡ Quick Installation

### 1. Download and Run Installer

```bash
# Download Panelo
git clone https://github.com/CodeWithJuber/Panelo.git
cd Panelo

# Make installer executable
chmod +x install.sh

# Run the installer as root
sudo ./install.sh
```

### 2. Interactive Setup

The installer will guide you through:

1. **Component Selection** - Choose which services to install
2. **Web Server** - Select NGINX (recommended) or Apache
3. **Database** - Choose MySQL (recommended) or PostgreSQL
4. **Applications** - Select supported application types (PHP, Node.js, Python, WordPress)
5. **Domain Configuration** - Enter your domain and email
6. **SSL Setup** - Automatic Let's Encrypt certificate generation
7. **Monitoring** - Prometheus + Grafana stack (optional)
8. **Backup System** - Automated backup configuration (optional)

### 3. Post-Installation

After installation completes:

1. **Access the panel** at `https://your-domain.com:3000`
2. **Backend API** at `https://your-domain.com:3001`
3. **Login credentials** are saved in `/var/server-panel/admin-credentials.txt`
4. **File manager** is available at `https://your-domain.com:8080`
5. **Grafana monitoring** at `https://your-domain.com:3001` (admin/admin123)
6. **Prometheus** at `https://your-domain.com:9090`

## 🛠️ Application Deployment

### Deploy WordPress

```bash
# Command line deployment
./modules/wordpress.sh deploy mysite example.com admin@email.com

# Or via web interface:
# 1. Go to Applications → New Application
# 2. Select WordPress
# 3. Enter domain and configuration
# 4. Click Deploy
```

### Deploy PHP/Laravel Application

```bash
# Deploy Laravel application
./modules/php.sh deploy myapp example.com laravel 8.2 user123

# Deploy basic PHP application
./modules/php.sh deploy myapp example.com basic 8.2 user123

# Supported PHP versions: 7.4, 8.0, 8.1, 8.2, 8.3
# Supported frameworks: basic, laravel, symfony, codeigniter
```

### Deploy Node.js Application

```bash
# Deploy Express.js application
./modules/nodejs.sh deploy myapi api.example.com express 18 user123

# Deploy Next.js application
./modules/nodejs.sh deploy myapp app.example.com nextjs 18 user123

# Supported Node.js versions: 16, 18, 20, 21
# Supported frameworks: express, nextjs, nestjs, react
```

### Deploy Python Application

```bash
# Deploy Flask application
./modules/python.sh deploy myapp app.example.com flask 3.9 user123

# Deploy Django application (when implemented)
./modules/python.sh deploy myapp app.example.com django 3.9 user123

# Supported Python versions: 3.8, 3.9, 3.10, 3.11
```

## 📁 Project Structure

```
Panelo/
├── install.sh                 # Main installer script
├── modules/                   # Installation modules
│   ├── helper.sh              # Common helper functions
│   ├── docker.sh              # Docker installation
│   ├── nginx.sh               # NGINX setup and management
│   ├── mysql.sh               # MySQL database setup
│   ├── filemanager.sh         # FileBrowser setup
│   ├── certbot.sh             # SSL certificate management
│   ├── wordpress.sh           # WordPress deployment support
│   ├── php.sh                 # PHP application deployment
│   ├── nodejs.sh              # Node.js application deployment
│   ├── python.sh              # Python application deployment
│   ├── monitoring.sh          # Prometheus + Grafana stack
│   ├── panel-frontend.sh      # Next.js frontend setup
│   └── panel-backend.sh       # NestJS backend API
├── templates/                 # Configuration templates
└── README.md                  # This file
```

## 🌐 Web Interface Features

### Dashboard
- Real-time system resource monitoring (CPU, Memory, Disk)
- Application status overview
- Quick stats (Applications, Databases, SSL certificates)
- Quick action buttons for common tasks

### Applications Management
- Deploy new applications with one-click
- Support for WordPress, PHP/Laravel, Node.js/Express/Next.js, Python/Flask
- Start/stop/restart applications
- View real-time application logs
- Resource usage monitoring per application
- SSL certificate management per domain

### File Manager
- Web-based file browser with full functionality
- File upload/download with drag-and-drop
- Online file editing with syntax highlighting
- Directory management and permissions
- User-isolated file access

### User Management
- Create and manage user accounts
- Role-based access control (Admin/User)
- Set resource limits per user
- Suspend/activate user accounts
- Usage monitoring and quotas

### Monitoring & Analytics
- Grafana dashboards for system metrics
- Application performance monitoring
- SSL certificate expiry tracking
- Automated alerting via email/webhooks
- Custom metrics for applications

## 🔧 API Documentation

### Authentication
```bash
# Login to get JWT token
curl -X POST https://your-domain.com:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@example.com","password":"your-password"}'
```

### Application Management
```bash
# Get all applications
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  https://your-domain.com:3001/api/apps

# Deploy new application
curl -X POST https://your-domain.com:3001/api/apps \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"myapp","domain":"app.example.com","type":"wordpress"}'
```

### User Management
```bash
# Get all users (admin only)
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  https://your-domain.com:3001/api/users

# Create new user (admin only)
curl -X POST https://your-domain.com:3001/api/users \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","name":"John Doe","password":"securepass"}'
```

## 🛡️ Security Features

- **Container Isolation** - Each application runs in isolated Docker containers
- **SSL/TLS Encryption** - Automatic Let's Encrypt certificates with auto-renewal
- **Firewall Configuration** - UFW/Firewalld with minimal open ports
- **Fail2ban Protection** - Automatic IP blocking for brute force attempts
- **Security Headers** - NGINX/Apache configured with security headers
- **JWT Authentication** - Secure API access with JSON Web Tokens
- **Role-based Access** - Admin and user roles with different permissions
- **Input Validation** - All API inputs validated and sanitized

## 📊 Monitoring & Alerting

### Metrics Collected
- System resources (CPU, Memory, Disk, Network)
- Application performance (response times, error rates)
- Container resource usage
- SSL certificate expiry dates
- Database performance and connections
- Backup status and history

### Alerting Rules
- High CPU usage (>80% for 5 minutes)
- High memory usage (>85% for 5 minutes)
- Low disk space (<10% available)
- Application downtime
- SSL certificate expiry (30 days warning)
- Failed backup notifications

## 🔄 Backup & Recovery

### Automated Backups
- **Database backups** - Daily MySQL dumps with compression
- **Application backups** - File system backups for user data
- **Configuration backups** - NGINX, SSL, and application configs
- **Retention policy** - Configurable backup retention (default: 30 days)

### Manual Backup Commands
```bash
# Backup specific application
./modules/backup.sh app myapp-name

# Backup all databases
./modules/backup.sh database all

# Backup system configuration
./modules/backup.sh config
```

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Setup
```bash
git clone https://github.com/CodeWithJuber/Panelo.git
cd Panelo
./install.sh  # For full installation
# Or install components individually for development
```

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🎯 Roadmap

- [ ] **Email Hosting** - Mailcow integration
- [ ] **DNS Management** - PowerDNS integration
- [ ] **Load Balancing** - Multi-server deployments
- [ ] **CDN Integration** - CloudFlare/AWS CloudFront
- [ ] **Advanced Monitoring** - Custom dashboards
- [ ] **Plugin System** - Third-party integrations
- [ ] **Mobile App** - iOS/Android management app
- [ ] **Multi-language Support** - i18n implementation

## ⭐ Support

If you find Panelo helpful, please give it a star on GitHub! 

For support and questions:
- 📧 Email: support@panelo.dev
- 💬 Discord: [Join our community](https://discord.gg/panelo)
- 🐛 Issues: [GitHub Issues](https://github.com/CodeWithJuber/Panelo/issues)

**Made with ❤️ for the open-source community**
