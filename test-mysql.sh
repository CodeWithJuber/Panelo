#!/bin/bash

# Simple MySQL Test Script

echo "🔍 Testing MySQL Connection..."

# Test if container is running
if docker ps | grep -q "server-panel-mysql"; then
    echo "✅ MySQL container is running"
else
    echo "❌ MySQL container is not running"
    exit 1
fi

# Test MySQL ping
if docker exec server-panel-mysql mysqladmin ping -h localhost --silent 2>/dev/null; then
    echo "✅ MySQL is responding to ping"
else
    echo "❌ MySQL is not responding"
    exit 1
fi

# Test root connection
if docker exec server-panel-mysql mysql -u root -proot_password_123 -e "SELECT 1;" &>/dev/null; then
    echo "✅ Root connection successful"
else
    echo "❌ Root connection failed"
fi

# Test panel user connection
if docker exec server-panel-mysql mysql -u panel_user -ppanel_password_123 -e "SELECT 1;" &>/dev/null; then
    echo "✅ Panel user connection successful"
else
    echo "⚠️  Panel user connection failed (will be created during setup)"
fi

# Test database access
if docker exec server-panel-mysql mysql -u root -proot_password_123 -e "SHOW DATABASES;" | grep -q "server_panel"; then
    echo "✅ Panel database exists"
else
    echo "⚠️  Panel database not found (will be created during setup)"
fi

echo ""
echo "🛠️  To fix MySQL connection issues, run:"
echo "   bash fix-mysql-connection.sh"
echo ""
echo "🔧 To restart MySQL:"
echo "   docker restart server-panel-mysql" 