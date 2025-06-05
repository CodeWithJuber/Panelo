#!/bin/bash

echo "Starting Server Panel services..."

# Start backend services
echo "Starting backend services..."
cd /opt/server-panel/backend
if [ -f "docker-compose.yml" ]; then
    docker compose up -d
    echo "Backend services started"
else
    echo "Warning: Backend docker-compose.yml not found"
fi

# Start frontend services  
echo "Starting frontend services..."
cd /opt/server-panel/panel/frontend
if [ -f "docker-compose.yml" ]; then
    docker compose up -d
    echo "Frontend services started"
else
    echo "Warning: Frontend docker-compose.yml not found"
fi

echo "Server panel services startup completed!" 