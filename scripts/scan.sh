#!/bin/bash
# Trigger Ignition resource scans after file changes
# Usage: ./scripts/scan.sh [environment]
# Default environment: local

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENVIRONMENT="${1:-local}"

CONFIG_FILE="$PROJECT_ROOT/config/environments/${ENVIRONMENT}.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Configuration file not found: $CONFIG_FILE"
  exit 1
fi

# Parse configuration
GATEWAY_URL=$(grep "url:" "$CONFIG_FILE" | head -1 | awk '{print $2}')
API_KEY=$(grep "api_key:" "$CONFIG_FILE" | head -1 | awk '{print $2}')

if [ -z "$API_KEY" ]; then
  echo "Error: No API key configured in $CONFIG_FILE"
  exit 1
fi

# Check gateway health first
if ! curl -s -f "${GATEWAY_URL}/StatusPing" > /dev/null 2>&1; then
  echo "Error: Gateway is not responding at $GATEWAY_URL"
  exit 1
fi

echo "Triggering Ignition scans on $ENVIRONMENT environment..."

# Trigger config scan
CONFIG_HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "X-Ignition-API-Token: $API_KEY" -X POST "${GATEWAY_URL}/data/api/v1/scan/config")
if [ "$CONFIG_HTTP_CODE" = "200" ]; then
  echo "  ✓ Config scan triggered"
else
  echo "  ✗ Config scan failed (HTTP $CONFIG_HTTP_CODE)"
fi

# Trigger projects scan
PROJECTS_HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "X-Ignition-API-Token: $API_KEY" -X POST "${GATEWAY_URL}/data/api/v1/scan/projects")
if [ "$PROJECTS_HTTP_CODE" = "200" ]; then
  echo "  ✓ Projects scan triggered"
else
  echo "  ✗ Projects scan failed (HTTP $PROJECTS_HTTP_CODE)"
fi

echo "Done!"
