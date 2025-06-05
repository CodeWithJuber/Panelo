#!/bin/bash

# Docker Installation Module
# Installs Docker Engine and Docker Compose

source "$(dirname "$0")/helper.sh" 2>/dev/null || true

install_docker() {
    log "INFO" "Starting Docker installation"
    
    # Check if Docker is already installed
    if command -v docker &>/dev/null; then
        log "INFO" "Docker is already installed"
        docker --version
        return 0
    fi
    
    local os_type
    os_type=$(get_system_info "os")
    
    case "$os_type" in
        "ubuntu"|"debian")
            install_docker_ubuntu_debian
            ;;
        "centos"|"rhel")
            install_docker_centos_rhel
            ;;
        "fedora")
            install_docker_fedora
            ;;
        *)
            log "ERROR" "Unsupported OS for Docker installation: $os_type"
            return 1
            ;;
    esac
    
    # Configure Docker
    configure_docker
    
    # Install Docker Compose
    install_docker_compose
    
    # Verify installation
    verify_docker_installation
}

install_docker_ubuntu_debian() {
    log "INFO" "Installing Docker on Ubuntu/Debian"
    
    # Update package index
    apt-get update
    
    # Install prerequisites
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/$(lsb_release -si | tr '[:upper:]' '[:lower:]')/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Set up the repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$(lsb_release -si | tr '[:upper:]' '[:lower:]') \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package index again
    apt-get update
    
    # Install Docker Engine
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    log "SUCCESS" "Docker installed on Ubuntu/Debian"
}

install_docker_centos_rhel() {
    log "INFO" "Installing Docker on CentOS/RHEL"
    
    # Install prerequisites
    yum install -y yum-utils
    
    # Add Docker repository
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    
    # Install Docker Engine
    yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    log "SUCCESS" "Docker installed on CentOS/RHEL"
}

install_docker_fedora() {
    log "INFO" "Installing Docker on Fedora"
    
    # Install prerequisites
    dnf install -y dnf-plugins-core
    
    # Add Docker repository
    dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    
    # Install Docker Engine
    dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    log "SUCCESS" "Docker installed on Fedora"
}

configure_docker() {
    log "INFO" "Configuring Docker"
    
    # Create Docker configuration directory
    mkdir -p /etc/docker
    
    # Configure Docker daemon
    cat > /etc/docker/daemon.json << 'EOF'
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2",
    "experimental": false,
    "live-restore": true,
    "userland-proxy": false,
    "default-address-pools": [
        {
            "base": "172.20.0.0/16",
            "size": 24
        }
    ]
}
EOF
    
    # Start and enable Docker service
    systemctl daemon-reload
    systemctl enable docker
    systemctl start docker
    
    # Wait for Docker to be ready
    wait_for_service "docker"
    
    # Add current user to docker group if not root
    if [[ $EUID -ne 0 ]]; then
        usermod -aG docker "$USER"
        log "INFO" "Added user to docker group. Please log out and log back in."
    fi
    
    log "SUCCESS" "Docker configured successfully"
}

install_docker_compose() {
    log "INFO" "Installing Docker Compose"
    
    # Check if Docker Compose plugin is available (newer Docker versions)
    if docker compose version &>/dev/null; then
        log "SUCCESS" "Docker Compose plugin is already available"
        return 0
    fi
    
    # Install standalone Docker Compose
    local compose_version="v2.21.0"
    local arch
    arch=$(uname -m)
    
    case "$arch" in
        "x86_64")
            arch="x86_64"
            ;;
        "aarch64"|"arm64")
            arch="aarch64"
            ;;
        *)
            log "ERROR" "Unsupported architecture: $arch"
            return 1
            ;;
    esac
    
    local compose_url="https://github.com/docker/compose/releases/download/${compose_version}/docker-compose-linux-${arch}"
    
    if download_file "$compose_url" "/usr/local/bin/docker-compose"; then
        chmod +x /usr/local/bin/docker-compose
        
        # Create symlink for docker compose command
        ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
        
        log "SUCCESS" "Docker Compose installed successfully"
    else
        log "ERROR" "Failed to install Docker Compose"
        return 1
    fi
}

verify_docker_installation() {
    log "INFO" "Verifying Docker installation"
    
    # Check Docker version
    if docker --version; then
        log "SUCCESS" "Docker version check passed"
    else
        log "ERROR" "Docker version check failed"
        return 1
    fi
    
    # Check Docker Compose
    if docker compose version || docker-compose --version; then
        log "SUCCESS" "Docker Compose version check passed"
    else
        log "ERROR" "Docker Compose version check failed"
        return 1
    fi
    
    # Test Docker with hello-world
    if docker run --rm hello-world &>/dev/null; then
        log "SUCCESS" "Docker hello-world test passed"
    else
        log "ERROR" "Docker hello-world test failed"
        return 1
    fi
    
    # Create server-panel network
    ensure_docker_network "server-panel"
    
    # Create data directories for Docker volumes
    create_directory "/var/server-panel/docker" "root" "root" "755"
    create_directory "/var/server-panel/docker/volumes" "root" "root" "755"
    
    log "SUCCESS" "Docker installation verification completed"
}

# Cleanup function
cleanup_docker() {
    log "INFO" "Cleaning up Docker installation"
    
    # Stop all containers
    docker stop $(docker ps -aq) 2>/dev/null || true
    
    # Remove all containers
    docker rm $(docker ps -aq) 2>/dev/null || true
    
    # Remove all images
    docker rmi $(docker images -q) 2>/dev/null || true
    
    # Remove all volumes
    docker volume prune -f 2>/dev/null || true
    
    # Remove all networks
    docker network prune -f 2>/dev/null || true
    
    log "SUCCESS" "Docker cleanup completed"
}

# Uninstall Docker (if needed)
uninstall_docker() {
    log "INFO" "Uninstalling Docker"
    
    # Stop Docker service
    systemctl stop docker 2>/dev/null || true
    systemctl disable docker 2>/dev/null || true
    
    # Clean up containers and images
    cleanup_docker
    
    local os_type
    os_type=$(get_system_info "os")
    
    case "$os_type" in
        "ubuntu"|"debian")
            apt-get remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
        "centos"|"rhel")
            yum remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
        "fedora")
            dnf remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
    esac
    
    # Remove Docker directories
    rm -rf /var/lib/docker
    rm -rf /etc/docker
    rm -f /usr/local/bin/docker-compose
    rm -f /usr/bin/docker-compose
    
    log "SUCCESS" "Docker uninstalled successfully"
}

# Main execution
main() {
    case "${1:-install}" in
        "install")
            install_docker
            ;;
        "cleanup")
            cleanup_docker
            ;;
        "uninstall")
            uninstall_docker
            ;;
        *)
            echo "Usage: $0 [install|cleanup|uninstall]"
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 