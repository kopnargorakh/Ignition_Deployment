#!/bin/bash
# Trigger Ignition resource scans after file changes
# Usage: ./scripts/scan.sh [environment]
# Default environment: local

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

if [ -f "$PROJECT_ROOT/.env.local" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$PROJECT_ROOT/.env.local"
  set +a
fi

ENVIRONMENT_INPUT="${1:-local}"

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

# Parse configuration
GATEWAY_URL_FROM_CONFIG=$(grep "url:" "$CONFIG_FILE" | head -1 | awk '{print $2}')
API_KEY_FROM_CONFIG=$(grep "api_key:" "$CONFIG_FILE" | head -1 | awk '{print $2}')

GATEWAY_URL_ENV_VAR="${ENV_VAR_PREFIX}_GATEWAY_URL"
GATEWAY_API_KEY_ENV_VAR="${ENV_VAR_PREFIX}_GATEWAY_API_KEY"
GATEWAY_URL="$(eval echo \$${GATEWAY_URL_ENV_VAR})"
API_KEY="$(eval echo \$${GATEWAY_API_KEY_ENV_VAR})"

if [ -z "$GATEWAY_URL" ]; then
  GATEWAY_URL="$GATEWAY_URL_FROM_CONFIG"
  GATEWAY_URL_SOURCE="config"
else
  GATEWAY_URL_SOURCE="env"
fi
if [ -z "$API_KEY" ]; then
  API_KEY="$API_KEY_FROM_CONFIG"
  API_KEY_SOURCE="config"
else
  API_KEY_SOURCE="env"
fi
if [ -z "$API_KEY" ] && [ -f "$PROJECT_ROOT/secrets/gateway_api_key" ]; then
  API_KEY=$(tr -d '\r\n' < "$PROJECT_ROOT/secrets/gateway_api_key")
  if [ -n "$API_KEY" ]; then
    API_KEY_SOURCE="secrets/gateway_api_key"
  fi
fi

if [ -z "$API_KEY" ]; then
  echo "Error: No API key configured"
  echo "Set ${GATEWAY_API_KEY_ENV_VAR} in .env.local, or add a non-empty secrets/gateway_api_key"
  exit 1
fi

# Local guardrail to prevent accidental temp auth profile persistence.
if [ "$ENVIRONMENT" = "local" ]; then
  LOCAL_SECURITY_FILE="$PROJECT_ROOT/config/gateway/resources/core/ignition/security-properties/config.json"
  LOCAL_USER_SOURCE_DIR="$PROJECT_ROOT/config/gateway/resources/core/ignition/user-source"
  LOCAL_IDP_DIR="$PROJECT_ROOT/config/gateway/resources/core/ignition/identity-provider"

  if [ ! -f "$LOCAL_SECURITY_FILE" ]; then
    echo "Error: Missing local security properties file: $LOCAL_SECURITY_FILE"
    exit 1
  fi

  if grep -Eq '"systemAuthProfile"[[:space:]]*:[[:space:]]*"temp(_[0-9]+)?"' "$LOCAL_SECURITY_FILE"; then
    echo "Error: local security-properties references temp systemAuthProfile."
    echo "Set systemAuthProfile to \"default\" before scanning."
    exit 1
  fi

  if grep -Eq '"systemIdentityProvider"[[:space:]]*:[[:space:]]*"temp(_[0-9]+)?"' "$LOCAL_SECURITY_FILE"; then
    echo "Error: local security-properties references temp systemIdentityProvider."
    echo "Set systemIdentityProvider to \"default\" before scanning."
    exit 1
  fi

  if find "$LOCAL_USER_SOURCE_DIR" -mindepth 1 -maxdepth 1 -type d -name 'temp*' | grep -q .; then
    echo "Error: temporary user-source directories found under local config."
    echo "Remove config/gateway/resources/core/ignition/user-source/temp* before scanning."
    exit 1
  fi

  if find "$LOCAL_IDP_DIR" -mindepth 1 -maxdepth 1 -type d -name 'temp*' | grep -q .; then
    echo "Error: temporary identity-provider directories found under local config."
    echo "Remove config/gateway/resources/core/ignition/identity-provider/temp* before scanning."
    exit 1
  fi
fi

# Check gateway health first
if ! curl -s -f "${GATEWAY_URL}/StatusPing" > /dev/null 2>&1; then
  echo "Error: Gateway is not responding at $GATEWAY_URL"
  exit 1
fi

echo "Triggering Ignition scans on $ENVIRONMENT environment..."
echo "Gateway URL source: $GATEWAY_URL_SOURCE"
echo "API key source: $API_KEY_SOURCE"

LOCAL_FALLBACK=false
SCAN_FAILED=false
ALLOW_LOCAL_RESTART_FALLBACK="${ALLOW_LOCAL_RESTART_FALLBACK:-false}"

# Trigger config scan
CONFIG_HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "X-Ignition-API-Token: $API_KEY" -X POST "${GATEWAY_URL}/data/api/v1/scan/config")
if [ "$CONFIG_HTTP_CODE" = "200" ]; then
  echo "  ✓ Config scan triggered"
else
  if [ "$ENVIRONMENT" = "local" ] && { [ "$CONFIG_HTTP_CODE" = "401" ] || [ "$CONFIG_HTTP_CODE" = "403" ]; }; then
    if [ "$ALLOW_LOCAL_RESTART_FALLBACK" = "true" ]; then
      echo "  ⚠ Config scan API denied (HTTP $CONFIG_HTTP_CODE), will use local restart fallback"
      LOCAL_FALLBACK=true
    else
      echo "  ✗ Config scan API denied (HTTP $CONFIG_HTTP_CODE)"
      SCAN_FAILED=true
    fi
  else
    echo "  ✗ Config scan failed (HTTP $CONFIG_HTTP_CODE)"
    SCAN_FAILED=true
  fi
fi

# Trigger projects scan
PROJECTS_HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "X-Ignition-API-Token: $API_KEY" -X POST "${GATEWAY_URL}/data/api/v1/scan/projects")
if [ "$PROJECTS_HTTP_CODE" = "200" ]; then
  echo "  ✓ Projects scan triggered"
else
  if [ "$ENVIRONMENT" = "local" ] && { [ "$PROJECTS_HTTP_CODE" = "401" ] || [ "$PROJECTS_HTTP_CODE" = "403" ]; }; then
    if [ "$ALLOW_LOCAL_RESTART_FALLBACK" = "true" ]; then
      echo "  ⚠ Projects scan API denied (HTTP $PROJECTS_HTTP_CODE), will use local restart fallback"
      LOCAL_FALLBACK=true
    else
      echo "  ✗ Projects scan API denied (HTTP $PROJECTS_HTTP_CODE)"
      SCAN_FAILED=true
    fi
  else
    echo "  ✗ Projects scan failed (HTTP $PROJECTS_HTTP_CODE)"
    SCAN_FAILED=true
  fi
fi

if [ "$LOCAL_FALLBACK" = "true" ]; then
  echo "Applying local fallback: restarting ignition-local to force config/project reload..."
  docker restart ignition-local > /dev/null

  MAX_WAIT=60
  WAIT_COUNT=0
  while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    if curl -s -f "${GATEWAY_URL}/StatusPing" > /dev/null 2>&1; then
      echo "  ✓ Local gateway restarted and responsive"
      break
    fi
    sleep 1
    WAIT_COUNT=$((WAIT_COUNT + 1))
  done

  if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
    echo "  ✗ Local gateway did not become ready after restart"
    exit 1
  fi
fi

if [ "$SCAN_FAILED" = "true" ]; then
  echo "Done with errors."
  exit 1
fi

echo "Done!"
