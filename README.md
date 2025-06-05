# Server Panel - Complete cPanel Alternative

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
- **PHP applications** - Full PHP support with Apache/NGINX
- **Node.js applications** - Express, Next.js, and other Node frameworks
- **Python applications** - Flask, Django, and other Python frameworks
- **Custom applications** - Support for custom Dockerfiles

### Management Features
- **Modern web interface** - Built with Next.js and Tailwind CSS
- **RESTful API** - NestJS-based backend API
- **Real-time monitoring** - CPU, memory, and disk usage tracking
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
# Download the server panel
git clone https://github.com/your-repo/server-panel.git
cd server-panel

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
4. **Applications** - Select supported application types
5. **Domain Configuration** - Enter your domain and email
6. **SSL Setup** - Automatic Let's Encrypt certificate generation

### 3. Post-Installation

After installation completes:

1. **Access the panel** at `https://your-domain.com:3000`
2. **Login credentials** are saved in `/var/server-panel/admin-credentials.txt`
3. **File manager** is available at `https://your-domain.com:8080`

## 🛠️ Manual Installation Options

### Custom Installation

```bash
# Install specific components only
./install.sh

# Then select components in the interactive menu
```

### Component-Specific Installation

```bash
# Install only Docker and NGINX
./modules/docker.sh install
./modules/nginx.sh install

# Install only WordPress support
./modules/wordpress.sh install

# Install SSL support
./modules/certbot.sh install yourdomain.com admin@yourdomain.com
```

## 📁 Project Structure

```
server-panel/
├── install.sh                 # Main installer script
├── modules/                   # Installation modules
│   ├── helper.sh              # Common helper functions
│   ├── docker.sh              # Docker installation
│   ├── nginx.sh               # NGINX setup and management
│   ├── mysql.sh               # MySQL database setup
│   ├── filemanager.sh         # FileBrowser setup
│   ├── certbot.sh             # SSL certificate management
│   ├── wordpress.sh           # WordPress deployment support
│   └── panel-frontend.sh      # Panel web interface
├── templates/                 # Configuration templates
│   ├── nginx-vhost.conf       # NGINX virtual host template
│   ├── apache-vhost.conf      # Apache virtual host template
│   └── docker-compose.base.yml
└── panel/                     # Web panel source code
    ├── frontend/              # Next.js frontend
    └── backend/               # NestJS backend
```

## 🌐 Web Interface

### Dashboard
- System resource monitoring (CPU, Memory, Disk)
- Quick stats (Applications, Databases, SSL certificates)
- Quick action buttons for common tasks

### Applications Management
- Deploy new applications (WordPress, Static, PHP, Node.js, Python)
- Start/stop/restart applications
- View application logs
- Manage application settings

### File Manager
- Web-based file browser
- File upload/download
- Online file editing
- Directory management
- File permissions management

### SSL Management
- View all SSL certificates
- Request new certificates
- Automatic renewal monitoring
- Certificate status checking

## 📖 Usage Examples

### Deploy a WordPress Site

```bash
# Via command line
./modules/wordpress.sh deploy mysite example.com user@email.com

# Via web interface
1. Go to Applications → New Application
2. Select WordPress
3. Enter domain and configuration
4. Click Deploy
```

### Create SSL Certificate

```bash
# Via command line
./modules/certbot.sh add-domain newdomain.com admin@email.com

# Automatic via web interface when deploying applications
```

### Manage Files

1. Access file manager at `https://your-domain.com:8080`
2. Login with panel credentials
3. Navigate, upload, edit files through web interface

### Database Management

```bash
# Create database for application
./modules/mysql.sh create-db myapp db_user db_password

# Backup database
./modules/mysql.sh backup myapp

# View database status
./modules/mysql.sh status
```

## 🔧 Configuration

### Environment Variables

Key configuration files:
- `/var/server-panel/` - Main data directory
- `/opt/server-panel/` - Installation directory
- `/etc/nginx/sites-available/` - NGINX configurations
- `/etc/letsencrypt/` - SSL certificates

### Service Management

```bash
# Panel services
systemctl start server-panel
systemctl stop server-panel
systemctl restart server-panel

# Individual components
systemctl restart nginx
systemctl restart mysql
docker restart server-panel-filemanager
```

## 🚨 Security Features

- **Firewall configuration** - Automatic UFW/firewalld setup
- **Fail2ban protection** - SSH brute force protection
- **SSL enforcement** - Automatic HTTPS redirects
- **Container isolation** - Each app runs in isolated containers
- **Security headers** - NGINX security headers enabled
- **File permissions** - Proper file system permissions

## 📊 Monitoring & Maintenance

### Automatic Tasks
- **SSL renewal** - Certificates renew automatically
- **Database backups** - Daily automatic backups
- **Log rotation** - Automatic log management
- **Security updates** - Container image updates

### Manual Monitoring

```bash
# View panel logs
journalctl -u server-panel -f

# Check SSL certificate status
./modules/certbot.sh status

# View system resources
htop
df -h
```

## 🔄 Backup & Recovery

### Automatic Backups
- Database backups stored in `/var/server-panel/mysql/backups/`
- Application backups in `/var/server-panel/backups/`
- SSL certificates backed up before renewal

### Manual Backup

```bash
# Backup specific application
./modules/wordpress.sh manage backup mysite

# Backup all databases
./modules/mysql.sh backup all
```

## 🐛 Troubleshooting

### Common Issues

**Installation fails**
```bash
# Check system requirements
free -h
df -h
# Ensure running as root
sudo -i
```

**Can't access panel**
```bash
# Check if services are running
systemctl status server-panel
docker ps

# Check firewall
ufw status
```

**SSL certificate issues**
```bash
# Check DNS resolution
nslookup your-domain.com

# Manual certificate request
./modules/certbot.sh add-domain your-domain.com your@email.com
```

### Log Locations
- Panel logs: `/var/log/server-panel/`
- NGINX logs: `/var/log/nginx/`
- SSL renewal logs: `/var/log/server-panel/ssl-renewal.log`

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: Check this README and inline comments
- **Issues**: Report bugs on GitHub Issues
- **Community**: Join our Discord/Slack community

## 🔮 Roadmap

### Upcoming Features
- **Kubernetes support** - Deploy to K8s clusters
- **Multi-server management** - Manage multiple servers
- **Advanced monitoring** - Prometheus/Grafana integration
- **CI/CD integration** - Git-based deployments
- **Billing integration** - WHMCS/Stripe integration
- **More applications** - Ruby, Go, Rust support

---

**Made with ❤️ for the open-source community** 