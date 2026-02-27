#!/bin/bash
set -e

# Ignition Gateway Deployment Script
# Usage: ./scripts/deploy.sh <environment>
# Example: ./scripts/deploy.sh dev

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENVIRONMENT_INPUT=$1

if [ -z "$ENVIRONMENT_INPUT" ]; then
  echo "Error: Environment not specified"
  echo "Usage: ./scripts/deploy.sh <environment>"
  echo "Available environments: local, dev, staging, prod"
  exit 1
fi

case "$ENVIRONMENT_INPUT" in
  local)
    ENVIRONMENT="local"
    ENV_VAR_PREFIX="LOCAL"
    ;;
  dev|development)
    ENVIRONMENT="dev"
    ENV_VAR_PREFIX="DEV"
    ;;
  staging)
    ENVIRONMENT="staging"
    ENV_VAR_PREFIX="STAGING"
    ;;
  prod|production)
    ENVIRONMENT="prod"
    ENV_VAR_PREFIX="PROD"
    ;;
  *)
    echo "Error: Unknown environment: $ENVIRONMENT_INPUT"
    echo "Available environments: local, dev, staging, prod"
    exit 1
    ;;
esac

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
GATEWAY_URL_FROM_CONFIG=$(grep "url:" "$CONFIG_FILE" | head -1 | awk '{print $2}')
GATEWAY_USER_FROM_CONFIG=$(grep "username:" "$CONFIG_FILE" | head -1 | awk '{print $2}')
GATEWAY_PASS_FROM_CONFIG=$(grep "password:" "$CONFIG_FILE" | head -1 | awk '{print $2}')
CONTAINER_NAME=$(grep "container_name:" "$CONFIG_FILE" | awk '{print $2}')
AUTO_BACKUP=$(grep "auto_backup:" "$CONFIG_FILE" | head -1 | awk '{print $2}')
API_KEY_FROM_CONFIG=$(grep "api_key:" "$CONFIG_FILE" | head -1 | awk '{print $2}')

GATEWAY_URL_ENV_VAR="${ENV_VAR_PREFIX}_GATEWAY_URL"
GATEWAY_USER_ENV_VAR="${ENV_VAR_PREFIX}_GATEWAY_USER"
GATEWAY_PASS_ENV_VAR="${ENV_VAR_PREFIX}_GATEWAY_PASS"
GATEWAY_API_KEY_ENV_VAR="${ENV_VAR_PREFIX}_GATEWAY_API_KEY"

GATEWAY_URL="$(eval echo \$${GATEWAY_URL_ENV_VAR})"
GATEWAY_USER="$(eval echo \$${GATEWAY_USER_ENV_VAR})"
GATEWAY_PASS="$(eval echo \$${GATEWAY_PASS_ENV_VAR})"
API_KEY="$(eval echo \$${GATEWAY_API_KEY_ENV_VAR})"

if [ -z "$GATEWAY_URL" ]; then
  GATEWAY_URL="$GATEWAY_URL_FROM_CONFIG"
fi
if [ -z "$GATEWAY_USER" ]; then
  GATEWAY_USER="$GATEWAY_USER_FROM_CONFIG"
fi
if [ -z "$GATEWAY_PASS" ]; then
  GATEWAY_PASS="$GATEWAY_PASS_FROM_CONFIG"
fi
if [ -z "$API_KEY" ]; then
  API_KEY="$API_KEY_FROM_CONFIG"
fi
if [ -z "$API_KEY" ] && [ -f "$PROJECT_ROOT/secrets/gateway_api_key" ]; then
  API_KEY=$(tr -d '\r\n' < "$PROJECT_ROOT/secrets/gateway_api_key")
fi

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
if [ -z "$API_KEY" ]; then
  echo "API key: not set (resource scans may be skipped)"
fi
echo ""

# Step 1.5: Validate scan API permissions for development deployments
preflight_scan_permissions() {
  if [ "$ENVIRONMENT" != "dev" ]; then
    return 0
  fi

  echo "Step 1.5: Validating Ignition scan API permissions (dev)..."
  if [ -z "$API_KEY" ]; then
    echo "Error: DEV_GATEWAY_API_KEY is required for dev deployment"
    return 1
  fi

  local scan_failed=0
  local endpoint
  local preflight_http_code

  for endpoint in config projects; do
    preflight_http_code=$(curl -s -o /dev/null -w "%{http_code}" -H "X-Ignition-API-Token: $API_KEY" -X POST "${GATEWAY_URL}/data/api/v1/scan/${endpoint}")
    if [ "$preflight_http_code" = "200" ]; then
      echo "  ✓ /scan/${endpoint} permission OK (HTTP 200)"
    else
      echo "  ✗ /scan/${endpoint} permission failed (HTTP $preflight_http_code)"
      scan_failed=1
    fi
  done

  if [ "$scan_failed" -ne 0 ]; then
    echo "Error: Scan API preflight failed; aborting deployment."
    return 1
  fi

  echo "✓ Scan API preflight passed"
  echo ""
}

# Step 1: Check if gateway is running
echo "Step 1: Checking gateway health..."
if ! curl -s -f "${GATEWAY_URL}/StatusPing" > /dev/null; then
  echo "Error: Gateway is not responding at ${GATEWAY_URL}"
  echo "Please ensure the Docker container is running: docker-compose up -d $CONTAINER_NAME"
  exit 1
fi
echo "✓ Gateway is healthy"
echo ""

if ! preflight_scan_permissions; then
  exit 1
fi

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
      echo "Error: Aborting deployment due to config scan failure."
      exit 1
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
