#!/bin/bash

# Fix Container Port Bindings
# This script fixes existing containers to bind to 0.0.0.0 instead of 127.0.0.1

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🔧 Fixing Server Panel Container Port Bindings...${NC}"

# Stop existing containers
echo -e "${YELLOW}Stopping existing containers...${NC}"
docker stop server-panel-backend server-panel-filemanager 2>/dev/null || true

# Remove existing containers (keep data volumes)
echo -e "${YELLOW}Removing old containers...${NC}"
docker rm server-panel-backend server-panel-filemanager 2>/dev/null || true

# Restart with fixed port bindings
echo -e "${GREEN}Starting containers with external access...${NC}"

# Start Backend with external access
echo -e "${BLUE}Starting backend...${NC}"
cd /opt/server-panel/backend
docker compose down 2>/dev/null || true
docker compose up -d

# Start Frontend with external access
echo -e "${BLUE}Starting frontend...${NC}"
cd /opt/server-panel/panel/frontend
docker compose down 2>/dev/null || true
docker compose up -d

# Restart File Manager with external access
echo -e "${BLUE}Restarting file manager...${NC}"
/opt/server-panel/modules/filemanager.sh restart

# Check container status
echo -e "${GREEN}Checking container status...${NC}"
docker ps | grep -E "(panel|server)"

# Test connectivity
echo -e "${BLUE}Testing connectivity...${NC}"
sleep 5

# Get server IP
SERVER_IP=$(curl -4 -s ifconfig.me 2>/dev/null || ip route get 8.8.8.8 | awk '{print $7; exit}' || echo "localhost")

echo -e "${GREEN}✅ Port binding fix completed!${NC}"
echo -e "${BLUE}📍 Access Points:${NC}"
echo -e "   • Panel Frontend: http://$SERVER_IP:3000"
echo -e "   • Backend API: http://$SERVER_IP:3001"  
echo -e "   • File Manager: http://$SERVER_IP:8080"

# Test ports
echo -e "${BLUE}Testing ports...${NC}"
for port in 3000 3001 8080; do
    if nc -z "$SERVER_IP" "$port" 2>/dev/null; then
        echo -e "   ✅ Port $port: ${GREEN}OPEN${NC}"
    else
        echo -e "   ❌ Port $port: ${RED}CLOSED${NC}"
    fi
done

echo -e "${YELLOW}Note: If ports show as closed, check your firewall settings${NC}" 