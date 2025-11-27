#!/bin/bash
set -e

# Deploy Individual Ignition Project
# Usage: ./scripts/deploy-project.sh <environment> <project_zip_file|project_directory>
# Example: ./scripts/deploy-project.sh dev ./build/my-project.zip
# Example: ./scripts/deploy-project.sh dev projects/TestProject

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENVIRONMENT=$1
PROJECT_SOURCE=$2

if [ -z "$ENVIRONMENT" ] || [ -z "$PROJECT_SOURCE" ]; then
  echo "Error: Missing required arguments"
  echo "Usage: ./scripts/deploy-project.sh <environment> <project_zip_file|project_directory>"
  exit 1
fi

# Check if source is zip file or directory
IS_ZIP=false
if [ -f "$PROJECT_SOURCE" ] && [[ "$PROJECT_SOURCE" == *.zip ]]; then
  IS_ZIP=true
elif [ ! -d "$PROJECT_SOURCE" ]; then
  echo "Error: Project source not found: $PROJECT_SOURCE"
  exit 1
fi

CONFIG_FILE="$PROJECT_ROOT/config/environments/${ENVIRONMENT}.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Configuration file not found: $CONFIG_FILE"
  exit 1
fi

# Parse configuration
DEPLOY_ROOT=$(grep "^deploy_root:" "$CONFIG_FILE" | awk '{print $2}')
CONTAINER_NAME=$(grep "container_name:" "$CONFIG_FILE" | awk '{print $2}')
GATEWAY_URL=$(grep "url:" "$CONFIG_FILE" | head -1 | awk '{print $2}')
API_KEY=$(grep "api_key:" "$CONFIG_FILE" | head -1 | awk '{print $2}')

# Use deploy_root if specified, otherwise use PROJECT_ROOT
if [ -n "$DEPLOY_ROOT" ]; then
  DEPLOY_TARGET="$DEPLOY_ROOT"
else
  DEPLOY_TARGET="$PROJECT_ROOT"
fi

# Determine project name and prepare source
if [ "$IS_ZIP" = true ]; then
  TEMP_DIR=$(mktemp -d)
  unzip -q "$PROJECT_SOURCE" -d "$TEMP_DIR"
  SOURCE_DIR="$TEMP_DIR"

  # Strip version from ZIP filename to get project name
  # This handles patterns like:
  #   ProjectName-1.0.0-abc123, ProjectName-v1.0.0, ProjectName-abc123 (single dash)
  #   ProjectName--1.0.0-abc123, ProjectName--v1.0.0 (double dash, legacy)
  ZIP_BASENAME=$(basename "$PROJECT_SOURCE" .zip)

  # Try to extract project name by removing version suffix
  # Pattern: remove -v1.0.0-abc123 or -1.0.0-abc123 or -abc123 or --anything
  PROJECT_NAME=$(echo "$ZIP_BASENAME" | sed -E 's/-+[v]?[0-9]+\.[0-9]+\.[0-9]+(-[a-f0-9]+)?$//' | sed -E 's/-+[a-f0-9]{7,}$//')

  # If the regex didn't match anything (no version in filename), use the full basename
  if [ -z "$PROJECT_NAME" ] || [ "$PROJECT_NAME" = "$ZIP_BASENAME" ]; then
    PROJECT_NAME="$ZIP_BASENAME"
  fi
else
  PROJECT_NAME=$(basename "$PROJECT_SOURCE")
  SOURCE_DIR="$PROJECT_SOURCE"
fi

echo "=========================================="
echo "Deploying Project: $PROJECT_NAME"
echo "Environment: $ENVIRONMENT"
echo "=========================================="

# Map environment to deployment directory
case "$ENVIRONMENT" in
  local)
    # Local mounts ./projects/ directly - deploy to source
    DEPLOY_DIR="$DEPLOY_TARGET/projects/$PROJECT_NAME"
    ;;
  dev|development)
    DEPLOY_DIR="$DEPLOY_TARGET/services/ignition-dev/projects/$PROJECT_NAME"
    ;;
  staging)
    DEPLOY_DIR="$DEPLOY_TARGET/services/ignition-staging/projects/$PROJECT_NAME"
    ;;
  prod|production)
    DEPLOY_DIR="$DEPLOY_TARGET/services/ignition-prod/projects/$PROJECT_NAME"
    ;;
  *)
    echo "Error: Unknown environment: $ENVIRONMENT"
    exit 1
    ;;
esac

echo "Deploying to: $DEPLOY_DIR"

# Create projects directory if it doesn't exist
mkdir -p "$(dirname "$DEPLOY_DIR")"

# Remove existing project if it exists
if [ -d "$DEPLOY_DIR" ]; then
  echo "Removing existing project..."
  rm -rf "$DEPLOY_DIR"
fi

# Copy project files
echo "Copying project files..."
cp -r "$SOURCE_DIR" "$DEPLOY_DIR"

# Clean up temp directory if we extracted a zip
if [ "$IS_ZIP" = true ]; then
  rm -rf "$TEMP_DIR"
fi

# Function to wait for gateway to be ready
wait_for_gateway() {
  local max_attempts=3
  local attempt=1
  echo "Waiting for gateway to be ready (max 5 seconds)..."

  while [ $attempt -le $max_attempts ]; do
    if curl -s -f "${GATEWAY_URL}/StatusPing" > /dev/null 2>&1; then
      echo "Gateway is ready!"
      return 0
    fi
    echo "  Attempt $attempt/$max_attempts..."
    sleep 2
    attempt=$((attempt + 1))
  done

  echo "ERROR: Gateway did not become ready within 5 seconds"
  return 1
}

# Function to trigger Ignition scans
trigger_ignition_scans() {
  echo "Triggering Ignition resource scans..."

  # Check if API key is configured
  if [ -z "$API_KEY" ]; then
    echo "  ⚠ No API key configured, skipping resource scans"
    echo "    Note: Gateway will auto-detect changes, but may take longer"
    return 0
  fi

  # Trigger config scan
  echo "  - Scanning gateway configuration..."
  CONFIG_HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "X-Ignition-API-Token: $API_KEY" -X POST "${GATEWAY_URL}/data/api/v1/scan/config")
  if [ "$CONFIG_HTTP_CODE" = "200" ]; then
    echo "    ✓ Config scan triggered"
  else
    echo "    ✗ Config scan failed (HTTP $CONFIG_HTTP_CODE)"
  fi

  # Trigger projects scan
  echo "  - Scanning projects..."
  PROJECTS_HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "X-Ignition-API-Token: $API_KEY" -X POST "${GATEWAY_URL}/data/api/v1/scan/projects")
  if [ "$PROJECTS_HTTP_CODE" = "200" ]; then
    echo "    ✓ Projects scan triggered"
  else
    echo "    ✗ Projects scan failed (HTTP $PROJECTS_HTTP_CODE)"
  fi
}

# Verify gateway is running
echo "Verifying gateway health..."
if ! curl -s -f "${GATEWAY_URL}/StatusPing" > /dev/null 2>&1; then
  echo ""
  echo "✗ Project deployment FAILED - Gateway is not responding"
  echo "  Project: $PROJECT_NAME"
  echo "  Environment: $ENVIRONMENT ($ENV_DIR)"
  echo "  Gateway URL: $GATEWAY_URL"
  echo ""
  echo "  The project files were copied but the gateway is not running."
  echo "  Please ensure the Docker container is running: docker ps"
  echo ""
  exit 1
fi
echo "✓ Gateway is healthy"

# Trigger Ignition to scan for new project
trigger_ignition_scans

echo ""
echo "✓ Project deployed successfully!"
echo "  Project: $PROJECT_NAME"
echo "  Environment: $ENVIRONMENT"
echo "  Location: $DEPLOY_DIR"
echo "  Gateway URL: ${GATEWAY_URL}/web/home"
echo ""
