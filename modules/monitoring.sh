#!/bin/bash

# System Monitoring Module
# Provides comprehensive monitoring with Prometheus, Grafana, and custom metrics

set -euo pipefail

# Source helper functions
source "$(dirname "$0")/helper.sh"

# Configuration
MONITORING_DIR="/var/server-panel/monitoring"
GRAFANA_PORT="3001"
PROMETHEUS_PORT="9090"
ALERT_MANAGER_PORT="9093"

# Install monitoring stack
install_monitoring() {
    log "INFO" "Installing monitoring stack"
    
    setup_monitoring_environment
    install_prometheus
    install_grafana
    install_alertmanager
    install_node_exporter
    setup_custom_metrics
    create_dashboards
    setup_alerting
    create_monitoring_scripts
    
    log "SUCCESS" "Monitoring stack installed"
}

# Setup monitoring environment
setup_monitoring_environment() {
    log "INFO" "Setting up monitoring environment"
    
    create_directory "$MONITORING_DIR" "root" "root" "755"
    create_directory "$MONITORING_DIR/prometheus" "root" "root" "755"
    create_directory "$MONITORING_DIR/grafana" "root" "root" "755"
    create_directory "$MONITORING_DIR/alertmanager" "root" "root" "755"
    create_directory "$MONITORING_DIR/scripts" "root" "root" "755"
    create_directory "$MONITORING_DIR/dashboards" "root" "root" "755"
    
    log "SUCCESS" "Monitoring environment setup completed"
}

# Install Prometheus
install_prometheus() {
    log "INFO" "Installing Prometheus"
    
    cat > "$MONITORING_DIR/prometheus/prometheus.yml" << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "/etc/prometheus/rules/*.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  # Prometheus itself
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Node Exporter for system metrics
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  # Docker metrics
  - job_name: 'docker'
    static_configs:
      - targets: ['host.docker.internal:9323']

  # Custom application metrics
  - job_name: 'server-panel'
    static_configs:
      - targets: ['backend:3001']
    metrics_path: '/api/metrics'

  # MySQL metrics
  - job_name: 'mysql'
    static_configs:
      - targets: ['mysqld-exporter:9104']

  # NGINX metrics
  - job_name: 'nginx'
    static_configs:
      - targets: ['nginx-exporter:9113']

  # Container metrics from cAdvisor
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
EOF

    # Create alert rules
    create_directory "$MONITORING_DIR/prometheus/rules" "root" "root" "755"
    
    cat > "$MONITORING_DIR/prometheus/rules/server-panel.yml" << 'EOF'
groups:
  - name: server-panel
    rules:
      # High CPU usage
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage detected"
          description: "CPU usage is above 80% for more than 5 minutes"

      # High memory usage
      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage detected"
          description: "Memory usage is above 85% for more than 5 minutes"

      # Low disk space
      - alert: LowDiskSpace
        expr: (node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100 < 10
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Low disk space"
          description: "Disk space is below 10%"

      # Container down
      - alert: ContainerDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Container is down"
          description: "Container {{ $labels.instance }} has been down for more than 1 minute"

      # High application response time
      - alert: HighResponseTime
        expr: http_request_duration_seconds{quantile="0.95"} > 2
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High application response time"
          description: "95th percentile response time is above 2 seconds"

      # Database connection issues
      - alert: DatabaseConnectionFailure
        expr: mysql_up == 0
        for: 30s
        labels:
          severity: critical
        annotations:
          summary: "Database connection failure"
          description: "MySQL database is not accessible"
EOF

    log "SUCCESS" "Prometheus configuration created"
}

# Install Grafana
install_grafana() {
    log "INFO" "Installing Grafana"
    
    # Create Grafana provisioning
    create_directory "$MONITORING_DIR/grafana/provisioning" "root" "root" "755"
    create_directory "$MONITORING_DIR/grafana/provisioning/datasources" "root" "root" "755"
    create_directory "$MONITORING_DIR/grafana/provisioning/dashboards" "root" "root" "755"
    
    # Datasource configuration
    cat > "$MONITORING_DIR/grafana/provisioning/datasources/prometheus.yml" << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF

    # Dashboard provisioning
    cat > "$MONITORING_DIR/grafana/provisioning/dashboards/dashboard.yml" << 'EOF'
apiVersion: 1

providers:
  - name: 'Server Panel Dashboards'
    orgId: 1
    folder: 'Server Panel'
    folderUid: 'server-panel'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    options:
      path: /var/lib/grafana/dashboards
EOF

    log "SUCCESS" "Grafana configuration created"
}

# Install Alertmanager
install_alertmanager() {
    log "INFO" "Installing Alertmanager"
    
    cat > "$MONITORING_DIR/alertmanager/alertmanager.yml" << 'EOF'
global:
  smtp_smarthost: 'localhost:587'
  smtp_from: 'alertmanager@serverpanel.local'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'

receivers:
  - name: 'web.hook'
    email_configs:
      - to: 'admin@serverpanel.local'
        subject: 'Server Panel Alert: {{ .GroupLabels.alertname }}'
        body: |
          {{ range .Alerts }}
          Alert: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          Labels:
          {{ range .Labels.SortedPairs }}  - {{ .Name }}: {{ .Value }}
          {{ end }}
          {{ end }}

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'dev', 'instance']
EOF

    log "SUCCESS" "Alertmanager configuration created"
}

# Install Node Exporter
install_node_exporter() {
    log "INFO" "Installing Node Exporter"
    
    # Node exporter will be run as Docker container
    log "SUCCESS" "Node Exporter configuration ready"
}

# Setup custom metrics
setup_custom_metrics() {
    log "INFO" "Setting up custom metrics collection"
    
    cat > "$MONITORING_DIR/scripts/collect-metrics.sh" << 'EOF'
#!/bin/bash

# Custom metrics collection script
# Collects server panel specific metrics

METRICS_FILE="/tmp/server-panel-metrics.txt"

# Function to write metric
write_metric() {
    local name="$1"
    local value="$2"
    local labels="$3"
    echo "${name}${labels} ${value}" >> "$METRICS_FILE"
}

# Clear previous metrics
> "$METRICS_FILE"

# Collect application metrics
collect_app_metrics() {
    # Count running containers
    local running_containers=$(docker ps --format "table {{.Names}}" | grep "^panel-" | wc -l)
    write_metric "server_panel_containers_running" "$running_containers" ""
    
    # Count total applications
    local total_apps=$(find /var/server-panel/users -mindepth 2 -maxdepth 2 -type d | wc -l)
    write_metric "server_panel_apps_total" "$total_apps" ""
    
    # Count users
    local user_count=$(find /var/server-panel/users -mindepth 1 -maxdepth 1 -type d | wc -l)
    write_metric "server_panel_users_total" "$user_count" ""
    
    # Database count
    local db_count=$(docker exec mysql mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SHOW DATABASES;" 2>/dev/null | grep -v -E '^(Database|information_schema|performance_schema|mysql|sys)$' | wc -l)
    write_metric "server_panel_databases_total" "$db_count" ""
}

# Collect resource usage per application
collect_app_resource_usage() {
    # Get container stats
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" | grep "^panel-" | while read -r line; do
        local container=$(echo "$line" | awk '{print $1}')
        local cpu=$(echo "$line" | awk '{print $2}' | sed 's/%//')
        local mem_usage=$(echo "$line" | awk '{print $3}' | cut -d'/' -f1)
        local mem_limit=$(echo "$line" | awk '{print $3}' | cut -d'/' -f2)
        
        # Convert memory to bytes
        mem_usage_bytes=$(numfmt --from=iec "$mem_usage" 2>/dev/null || echo "0")
        mem_limit_bytes=$(numfmt --from=iec "$mem_limit" 2>/dev/null || echo "0")
        
        write_metric "server_panel_container_cpu_percent" "$cpu" "{container=\"$container\"}"
        write_metric "server_panel_container_memory_usage_bytes" "$mem_usage_bytes" "{container=\"$container\"}"
        write_metric "server_panel_container_memory_limit_bytes" "$mem_limit_bytes" "{container=\"$container\"}"
    done
}

# Collect SSL certificate expiry
collect_ssl_metrics() {
    # Check SSL certificates
    find /etc/letsencrypt/live -name "cert.pem" | while read -r cert; do
        local domain=$(basename "$(dirname "$cert")")
        local expiry_date=$(openssl x509 -enddate -noout -in "$cert" 2>/dev/null | cut -d= -f2)
        local expiry_timestamp=$(date -d "$expiry_date" +%s 2>/dev/null || echo "0")
        
        write_metric "server_panel_ssl_cert_expiry_timestamp" "$expiry_timestamp" "{domain=\"$domain\"}"
    done
}

# Collect backup metrics
collect_backup_metrics() {
    # Count backups
    local backup_count=$(find /var/server-panel/backups -name "*.sql" -o -name "*.tar.gz" | wc -l)
    write_metric "server_panel_backups_total" "$backup_count" ""
    
    # Latest backup timestamp
    local latest_backup=$(find /var/server-panel/backups -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f1)
    write_metric "server_panel_last_backup_timestamp" "${latest_backup:-0}" ""
}

# Run collection functions
collect_app_metrics
collect_app_resource_usage
collect_ssl_metrics
collect_backup_metrics

# Add timestamp
write_metric "server_panel_metrics_last_updated" "$(date +%s)" ""

echo "Metrics collected: $(wc -l < "$METRICS_FILE") metrics"
EOF

    chmod +x "$MONITORING_DIR/scripts/collect-metrics.sh"
    
    # Create metrics endpoint for Prometheus
    cat > "$MONITORING_DIR/scripts/metrics-server.py" << 'EOF'
#!/usr/bin/env python3

import http.server
import socketserver
import subprocess
import os

class MetricsHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/metrics':
            # Run metrics collection script
            subprocess.run(['/var/server-panel/monitoring/scripts/collect-metrics.sh'])
            
            # Read metrics file
            metrics_file = '/tmp/server-panel-metrics.txt'
            if os.path.exists(metrics_file):
                with open(metrics_file, 'r') as f:
                    metrics_content = f.read()
            else:
                metrics_content = "# No metrics available\n"
            
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(metrics_content.encode())
        else:
            self.send_response(404)
            self.end_headers()

PORT = 9091
with socketserver.TCPServer(("", PORT), MetricsHandler) as httpd:
    print(f"Serving metrics on port {PORT}")
    httpd.serve_forever()
EOF

    chmod +x "$MONITORING_DIR/scripts/metrics-server.py"
    
    log "SUCCESS" "Custom metrics setup completed"
}

# Create monitoring dashboards
create_dashboards() {
    log "INFO" "Creating monitoring dashboards"
    
    # System overview dashboard
    cat > "$MONITORING_DIR/dashboards/system-overview.json" << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "Server Panel - System Overview",
    "tags": ["server-panel"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "CPU Usage",
        "type": "stat",
        "targets": [
          {
            "expr": "100 - (avg(rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
            "legendFormat": "CPU Usage %"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "thresholds": {
              "steps": [
                {"color": "green", "value": null},
                {"color": "yellow", "value": 70},
                {"color": "red", "value": 90}
              ]
            }
          }
        },
        "gridPos": {"h": 8, "w": 6, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "Memory Usage",
        "type": "stat",
        "targets": [
          {
            "expr": "(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100",
            "legendFormat": "Memory Usage %"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "thresholds": {
              "steps": [
                {"color": "green", "value": null},
                {"color": "yellow", "value": 70},
                {"color": "red", "value": 90}
              ]
            }
          }
        },
        "gridPos": {"h": 8, "w": 6, "x": 6, "y": 0}
      },
      {
        "id": 3,
        "title": "Disk Usage",
        "type": "stat",
        "targets": [
          {
            "expr": "(node_filesystem_size_bytes - node_filesystem_avail_bytes) / node_filesystem_size_bytes * 100",
            "legendFormat": "Disk Usage %"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "thresholds": {
              "steps": [
                {"color": "green", "value": null},
                {"color": "yellow", "value": 70},
                {"color": "red", "value": 90}
              ]
            }
          }
        },
        "gridPos": {"h": 8, "w": 6, "x": 12, "y": 0}
      },
      {
        "id": 4,
        "title": "Running Applications",
        "type": "stat",
        "targets": [
          {
            "expr": "server_panel_containers_running",
            "legendFormat": "Running Apps"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "short",
            "color": {"mode": "thresholds"},
            "thresholds": {
              "steps": [
                {"color": "blue", "value": null}
              ]
            }
          }
        },
        "gridPos": {"h": 8, "w": 6, "x": 18, "y": 0}
      }
    ],
    "time": {"from": "now-1h", "to": "now"},
    "refresh": "5s"
  }
}
EOF

    log "SUCCESS" "Monitoring dashboards created"
}

# Setup alerting
setup_alerting() {
    log "INFO" "Setting up alerting system"
    
    # Create alerting script
    cat > "$MONITORING_DIR/scripts/send-alert.sh" << 'EOF'
#!/bin/bash

# Alert notification script
# Sends alerts via multiple channels

ALERT_TYPE="$1"
ALERT_MESSAGE="$2"
ALERT_SEVERITY="${3:-warning}"

send_email_alert() {
    if command -v mail &> /dev/null; then
        echo "$ALERT_MESSAGE" | mail -s "Server Panel Alert: $ALERT_TYPE" "$ADMIN_EMAIL"
    fi
}

send_webhook_alert() {
    if [[ -n "${WEBHOOK_URL:-}" ]]; then
        curl -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"text\": \"Server Panel Alert: $ALERT_TYPE - $ALERT_MESSAGE\"}" \
            2>/dev/null || true
    fi
}

log_alert() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$ALERT_SEVERITY] $ALERT_TYPE: $ALERT_MESSAGE" >> /var/log/server-panel-alerts.log
}

# Send alerts
log_alert
send_email_alert
send_webhook_alert
EOF

    chmod +x "$MONITORING_DIR/scripts/send-alert.sh"
    
    log "SUCCESS" "Alerting system setup completed"
}

# Create monitoring scripts
create_monitoring_scripts() {
    log "INFO" "Creating monitoring management scripts"
    
    # Main monitoring docker-compose
    cat > "$MONITORING_DIR/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: server-panel-prometheus
    restart: unless-stopped
    networks:
      - server-panel
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus:/etc/prometheus
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'

  grafana:
    image: grafana/grafana:latest
    container_name: server-panel-grafana
    restart: unless-stopped
    networks:
      - server-panel
    ports:
      - "3001:3000"
    volumes:
      - ./grafana/provisioning:/etc/grafana/provisioning
      - ./dashboards:/var/lib/grafana/dashboards
      - grafana_data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
      - GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-simple-json-datasource

  alertmanager:
    image: prom/alertmanager:latest
    container_name: server-panel-alertmanager
    restart: unless-stopped
    networks:
      - server-panel
    ports:
      - "9093:9093"
    volumes:
      - ./alertmanager:/etc/alertmanager

  node-exporter:
    image: prom/node-exporter:latest
    container_name: server-panel-node-exporter
    restart: unless-stopped
    networks:
      - server-panel
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.ignored-mount-points=^/(sys|proc|dev|host|etc)($$|/)'

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: server-panel-cadvisor
    restart: unless-stopped
    networks:
      - server-panel
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:rw
      - /sys:/sys:ro
      - /var/lib/docker:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    privileged: true

  custom-metrics:
    image: python:3.9-alpine
    container_name: server-panel-metrics
    restart: unless-stopped
    networks:
      - server-panel
    ports:
      - "9091:9091"
    volumes:
      - ./scripts:/scripts
      - /var/server-panel:/var/server-panel:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    command: python3 /scripts/metrics-server.py

volumes:
  prometheus_data:
  grafana_data:

networks:
  server-panel:
    external: true
EOF

    # Control script
    cat > "$MONITORING_DIR/control.sh" << 'EOF'
#!/bin/bash

action="${1:-help}"

case "$action" in
    "start")
        echo "Starting monitoring stack..."
        cd /var/server-panel/monitoring
        docker-compose up -d
        echo "Monitoring stack started!"
        echo "Grafana: http://localhost:3001 (admin/admin123)"
        echo "Prometheus: http://localhost:9090"
        echo "Alertmanager: http://localhost:9093"
        ;;
    "stop")
        echo "Stopping monitoring stack..."
        cd /var/server-panel/monitoring
        docker-compose down
        echo "Monitoring stack stopped!"
        ;;
    "restart")
        echo "Restarting monitoring stack..."
        cd /var/server-panel/monitoring
        docker-compose restart
        echo "Monitoring stack restarted!"
        ;;
    "status")
        cd /var/server-panel/monitoring
        docker-compose ps
        ;;
    "logs")
        cd /var/server-panel/monitoring
        docker-compose logs -f
        ;;
    *)
        echo "Usage: $0 [start|stop|restart|status|logs]"
        exit 1
        ;;
esac
EOF

    chmod +x "$MONITORING_DIR/control.sh"
    
    log "SUCCESS" "Monitoring scripts created"
}

# Main function
case "${1:-install}" in
    "install")
        install_monitoring
        ;;
    "start")
        "$MONITORING_DIR/control.sh" start
        ;;
    "stop")
        "$MONITORING_DIR/control.sh" stop
        ;;
    "restart")
        "$MONITORING_DIR/control.sh" restart
        ;;
    "status")
        "$MONITORING_DIR/control.sh" status
        ;;
    *)
        echo "Usage: $0 [install|start|stop|restart|status]"
        exit 1
        ;;
esac 