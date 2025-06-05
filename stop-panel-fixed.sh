#!/bin/bash

echo "Stopping Server Panel services..."

# Stop frontend services  
echo "Stopping frontend services..."
cd /opt/server-panel/panel/frontend
if [ -f "docker-compose.yml" ]; then
    docker compose down
    echo "Frontend services stopped"
fi

# Stop backend services
echo "Stopping backend services..."
cd /opt/server-panel/backend
if [ -f "docker-compose.yml" ]; then
    docker compose down
    echo "Backend services stopped"
fi

echo "Server panel services stopped!" 