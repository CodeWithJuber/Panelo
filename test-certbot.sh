#!/bin/bash

# Test script to debug certbot arguments
echo "=== Certbot Debug Test ==="
echo "Script: $0"
echo "All arguments: $@"
echo "Argument count: $#"
echo "Arg 1: '$1'"
echo "Arg 2: '$2'" 
echo "Arg 3: '$3'"
echo ""

# Test the actual call
echo "=== Testing Certbot Call ==="
INSTALL_DIR="/opt/server-panel"
DOMAIN="test.example.com"
EMAIL="test@example.com"

echo "INSTALL_DIR: $INSTALL_DIR"
echo "DOMAIN: $DOMAIN"
echo "EMAIL: $EMAIL"
echo ""

echo "Command to run:"
echo "bash \"$INSTALL_DIR/modules/certbot.sh\" install \"$DOMAIN\" \"$EMAIL\""
echo ""

echo "Actually running it now:"
bash "$INSTALL_DIR/modules/certbot.sh" install "$DOMAIN" "$EMAIL" 