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
DEPLOY_ROOT=$(grep "^deploy_root:" "$CONFIG_FILE" | awk '{print $2}')
GATEWAY_URL=$(grep "url:" "$CONFIG_FILE" | head -1 | awk '{print $2}')
GATEWAY_USER=$(grep "username:" "$CONFIG_FILE" | head -1 | awk '{print $2}')
GATEWAY_PASS=$(grep "password:" "$CONFIG_FILE" | head -1 | awk '{print $2}')
CONTAINER_NAME=$(grep "container_name:" "$CONFIG_FILE" | awk '{print $2}')
AUTO_BACKUP=$(grep "auto_backup:" "$CONFIG_FILE" | awk '{print $2}')
API_KEY=$(grep "api_key:" "$CONFIG_FILE" | head -1 | awk '{print $2}')

# Use deploy_root if specified, otherwise use PROJECT_ROOT
if [ -n "$DEPLOY_ROOT" ]; then
  echo "Using deploy root: $DEPLOY_ROOT"
  DEPLOY_TARGET="$DEPLOY_ROOT"
else
  echo "Using project root: $PROJECT_ROOT"
  DEPLOY_TARGET="$PROJECT_ROOT"
fi

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
CONFIG_SOURCE="$DEPLOY_TARGET/config/gateway"
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

  CONFIG_TARGET="$DEPLOY_TARGET/services/$ENV_DIR/config"
  echo "  Copying config from: config/gateway/"
  echo "  To: $CONFIG_TARGET"

  # Create target directory
  mkdir -p "$CONFIG_TARGET"

  # Delete .resources cache so Ignition rebuilds it from actual files
  # This prevents stale/deleted resources from being regenerated
  if [ -d "$CONFIG_TARGET/resources/.resources" ]; then
    echo "  Clearing resource cache (.resources/)..."
    rm -rf "$CONFIG_TARGET/resources/.resources"
  fi

  # Copy configuration files (rsync preserves structure and only copies changes)
  rsync -a --delete \
    --exclude='local/' \
    --exclude='resources/local/' \
    --exclude='.resources/' \
    "$CONFIG_SOURCE/" "$CONFIG_TARGET/"

  echo "✓ Gateway configuration deployed"

  # Trigger config scan to sync file system changes to Ignition
  echo "  Triggering Ignition config scan..."
  if [ -n "$API_KEY" ]; then
    SCAN_HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "X-Ignition-API-Token: $API_KEY" -X POST "${GATEWAY_URL}/data/api/v1/scan/config")
    if [ "$SCAN_HTTP_CODE" = "200" ]; then
      echo "  ✓ Config scan triggered"
      sleep 2  # Give Ignition time to process
    else
      echo "  ✗ Config scan failed (HTTP $SCAN_HTTP_CODE)"
    fi
  else
    echo "  ⚠ No API key configured, skipping config scan"
  fi
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
PROJECTS_DIR="$PROJECT_ROOT/projects"

# Package projects from source if projects/ exists (local development scenario)
# CI/CD packages separately before calling deploy.sh, but locally we do it here
# Always repackage to ensure latest changes are deployed
if [ -d "$PROJECTS_DIR" ] && [ -n "$(ls -A "$PROJECTS_DIR" 2>/dev/null)" ]; then
  echo "  Packaging projects from source..."
  rm -rf "$BUILD_DIR"
  mkdir -p "$BUILD_DIR"

  for dir in "$PROJECTS_DIR"/*/; do
    if [ -d "$dir" ]; then
      project_name=$(basename "$dir")
      echo "  Packaging $project_name..."
      "$SCRIPT_DIR/package-project.sh" "$dir"
    fi
  done
  echo ""
fi

if [ -d "$BUILD_DIR" ]; then
  # Check for no-projects marker
  if [ -f "$BUILD_DIR/.no-projects" ]; then
    echo "  ℹ No projects to deploy (config-only deployment)"
  else
    project_count=0
    for project_zip in "$BUILD_DIR"/*.zip; do
      if [ -f "$project_zip" ]; then
        project_name=$(basename "$project_zip" .zip)
        echo "  Deploying $project_name..."
        "$SCRIPT_DIR/deploy-project.sh" "$ENVIRONMENT" "$project_zip"
        echo "  ✓ $project_name deployed"
        project_count=$((project_count + 1))
      fi
    done

    if [ $project_count -eq 0 ]; then
      echo "  ℹ No project packages found"
    fi
  fi
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
