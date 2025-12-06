#!/bin/bash
# ============================================
# Frappe Press - Health Check Script
# ============================================

SITE_NAME="${FRAPPE_SITE_NAME:-cloud.localhost}"

# Check if gunicorn is running
if ! pgrep -x "gunicorn" > /dev/null; then
    echo "Gunicorn is not running"
    exit 1
fi

# Check HTTP endpoint
response=$(curl -sf -o /dev/null -w "%{http_code}" "http://localhost:8000/api/method/ping")

if [ "$response" = "200" ]; then
    echo "Health check passed"
    exit 0
else
    echo "Health check failed: HTTP $response"
    exit 1
fi
