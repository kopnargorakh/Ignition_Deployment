#!/bin/bash
set -e

# Ignition Gateway Deployment Script
# Usage: ./scripts/deploy.sh <environment>
# Example: ./scripts/deploy.sh dev

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENVIRONMENT=$1

if [ -z "$ENVIRONMENT" ]; then
  echo "Error: Environment not specified"
  echo "Usage: ./scripts/deploy.sh <environment>"
  echo "Available environments: dev, staging, prod"
  exit 1
fi

CONFIG_FILE="$PROJECT_ROOT/config/environments/${ENVIRONMENT}.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Configuration file not found: $CONFIG_FILE"
  exit 1
fi

echo "=========================================="
echo "Deploying to $ENVIRONMENT environment"
echo "=========================================="
echo ""

# Parse YAML config (basic parsing - in production, use yq or similar)
GATEWAY_URL=$(grep "url:" "$CONFIG_FILE" | head -1 | awk '{print $2}')
GATEWAY_USER=$(grep "username:" "$CONFIG_FILE" | head -1 | awk '{print $2}')
GATEWAY_PASS=$(grep "password:" "$CONFIG_FILE" | head -1 | awk '{print $2}')
CONTAINER_NAME=$(grep "container_name:" "$CONFIG_FILE" | awk '{print $2}')
AUTO_BACKUP=$(grep "auto_backup:" "$CONFIG_FILE" | awk '{print $2}')

echo "Gateway URL: $GATEWAY_URL"
echo "Container: $CONTAINER_NAME"
echo ""

# Step 1: Check if gateway is running
echo "Step 1: Checking gateway health..."
if ! curl -s -f "${GATEWAY_URL}/StatusPing" > /dev/null; then
  echo "Error: Gateway is not responding at ${GATEWAY_URL}"
  echo "Please ensure the Docker container is running: docker-compose up -d $CONTAINER_NAME"
  exit 1
fi
echo "✓ Gateway is healthy"
echo ""

# Step 2: Create backup if enabled
if [ "$AUTO_BACKUP" = "true" ]; then
  echo "Step 2: Creating backup..."
  "$SCRIPT_DIR/backup-gateway.sh" "$ENVIRONMENT"
  echo "✓ Backup created"
  echo ""
else
  echo "Step 2: Backup disabled, skipping..."
  echo ""
fi

# Step 3: Deploy gateway configuration
echo "Step 3: Deploying gateway configuration..."
CONFIG_SOURCE="$PROJECT_ROOT/config/gateway"
if [ -d "$CONFIG_SOURCE" ]; then
  case "$ENVIRONMENT" in
    dev|development)
      ENV_DIR="ignition-dev"
      ;;
    staging)
      ENV_DIR="ignition-staging"
      ;;
    prod|production)
      ENV_DIR="ignition-prod"
      ;;
    *)
      echo "Error: Unknown environment: $ENVIRONMENT"
      exit 1
      ;;
  esac

  CONFIG_TARGET="$PROJECT_ROOT/services/$ENV_DIR/config"
  echo "  Copying config from: config/gateway/"
  echo "  To: services/$ENV_DIR/config/"

  # Create target directory
  mkdir -p "$CONFIG_TARGET"

  # Copy configuration files (rsync preserves structure and only copies changes)
  rsync -av --delete \
    --exclude='local/' \
    --exclude='resources/local/' \
    --exclude='.resources/' \
    "$CONFIG_SOURCE/" "$CONFIG_TARGET/"

  echo "✓ Gateway configuration deployed"
else
  echo "⚠ Gateway configuration not found in config/gateway/, skipping..."
fi
echo ""

# Step 4: Run database migrations
echo "Step 4: Running database migrations..."
if [ -f "$SCRIPT_DIR/db-migrate.sh" ]; then
  "$SCRIPT_DIR/db-migrate.sh" "$ENVIRONMENT" up
  echo "✓ Database migrations completed"
else
  echo "⚠ Database migration script not found, skipping..."
fi
echo ""

# Step 5: Deploy projects
echo "Step 5: Deploying Ignition projects..."
BUILD_DIR="$PROJECT_ROOT/build"
if [ -d "$BUILD_DIR" ]; then
  for project_zip in "$BUILD_DIR"/*.zip; do
    if [ -f "$project_zip" ]; then
      project_name=$(basename "$project_zip" .zip)
      echo "  Deploying $project_name..."
      "$SCRIPT_DIR/deploy-project.sh" "$ENVIRONMENT" "$project_zip"
      echo "  ✓ $project_name deployed"
    fi
  done
else
  echo "⚠ No build artifacts found in $BUILD_DIR"
fi
echo ""

# Step 6: Run smoke tests
echo "Step 6: Running smoke tests..."
if [ -f "$SCRIPT_DIR/smoke-test.sh" ]; then
  "$SCRIPT_DIR/smoke-test.sh" "$ENVIRONMENT"
  echo "✓ Smoke tests passed"
else
  echo "⚠ Smoke test script not found, skipping..."
fi
echo ""

echo "=========================================="
echo "✓ Deployment to $ENVIRONMENT completed successfully!"
echo "=========================================="
echo ""
echo "Gateway URL: $GATEWAY_URL"
echo "Access the gateway at: ${GATEWAY_URL}/web/home"
