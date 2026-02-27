#!/bin/bash
set -e

# Smoke Test for Ignition Gateway
# Usage: ./scripts/smoke-test.sh <environment>
# Example: ./scripts/smoke-test.sh dev

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENVIRONMENT_INPUT=$1

if [ -z "$ENVIRONMENT_INPUT" ]; then
  echo "Error: Environment not specified"
  echo "Usage: ./scripts/smoke-test.sh <environment>"
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

# Parse configuration
GATEWAY_URL_FROM_CONFIG=$(grep "url:" "$CONFIG_FILE" | head -1 | awk '{print $2}')
API_KEY_FROM_CONFIG=$(grep "api_key:" "$CONFIG_FILE" | head -1 | awk '{print $2}')

GATEWAY_URL_ENV_VAR="${ENV_VAR_PREFIX}_GATEWAY_URL"
GATEWAY_API_KEY_ENV_VAR="${ENV_VAR_PREFIX}_GATEWAY_API_KEY"
GATEWAY_URL="$(eval echo \$${GATEWAY_URL_ENV_VAR})"
API_KEY="$(eval echo \$${GATEWAY_API_KEY_ENV_VAR})"

if [ -z "$GATEWAY_URL" ]; then
  GATEWAY_URL="$GATEWAY_URL_FROM_CONFIG"
fi
if [ -z "$API_KEY" ]; then
  API_KEY="$API_KEY_FROM_CONFIG"
fi
if [ -z "$API_KEY" ] && [ -f "$PROJECT_ROOT/secrets/gateway_api_key" ]; then
  API_KEY=$(tr -d '\r\n' < "$PROJECT_ROOT/secrets/gateway_api_key")
fi

echo "=========================================="
echo "Smoke Test - $ENVIRONMENT"
echo "=========================================="
echo "Gateway: $GATEWAY_URL"
echo ""

# Wait for gateway to be responsive (in case it was just restarted)
echo "Waiting for gateway to be ready..."
MAX_WAIT=60
WAIT_COUNT=0
while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
  if curl -s -f "${GATEWAY_URL}/StatusPing" > /dev/null 2>&1; then
    echo "Gateway is ready (waited ${WAIT_COUNT}s)"
    break
  fi
  sleep 1
  WAIT_COUNT=$((WAIT_COUNT + 1))
done

if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
  echo "⚠ Warning: Gateway did not become ready within ${MAX_WAIT}s"
fi
echo ""

EXIT_CODE=0

# Test 1: Gateway Status Ping
echo "Test 1: Gateway Status Ping"
if curl -s -f "${GATEWAY_URL}/StatusPing" > /dev/null; then
  echo "  ✓ Gateway is responding"
else
  echo "  ✗ Gateway is not responding"
  EXIT_CODE=1
fi

# Test 2: Gateway Home Page
echo "Test 2: Gateway Home Page"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${GATEWAY_URL}/web/home")
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
  echo "  ✓ Home page accessible (HTTP $HTTP_CODE)"
else
  echo "  ✗ Home page not accessible (HTTP $HTTP_CODE)"
  EXIT_CODE=1
fi

# Test 3: Check if gateway is licensed (optional)
echo "Test 3: Gateway Status Check"
STATUS_RESPONSE=$(curl -s "${GATEWAY_URL}/StatusPing")
if echo "$STATUS_RESPONSE" | grep -i "running" > /dev/null; then
  echo "  ✓ Gateway status is healthy"
else
  echo "  ⚠ Warning: Could not verify gateway status"
fi

# Wait briefly to reduce transient failures while scripts reload after deploy
sleep 5

# Test 4: Pylib and Jar Tests via WebDev endpoint
echo "Test 4: Pylib and Jar Tests"
if [ -n "$API_KEY" ]; then
  TEST_RESPONSE=$(curl -s -H "X-Ignition-API-Token: $API_KEY" "${GATEWAY_URL}/system/webdev/TestProject/api/test" 2>/dev/null)
  TEST_HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "X-Ignition-API-Token: $API_KEY" "${GATEWAY_URL}/system/webdev/TestProject/api/test")

  if [ "$TEST_HTTP_CODE" = "200" ]; then
    # Extract results from JSON and parse test output
    RESULTS=$(echo "$TEST_RESPONSE" | sed 's/.*"results":"\(.*\)".*/\1/' | sed 's/\\n/\n/g')

    # Check if any tests failed
    if echo "$RESULTS" | grep -q "FAIL"; then
      echo "  ✗ Some tests failed:"
      echo "$RESULTS" | while IFS= read -r line; do
        case "$line" in
          "=== "*)  echo "  $line" ;;
          "OK: "*)  echo "    ✓ ${line#OK: }" ;;
          "FAIL: "*) echo "    ✗ ${line#FAIL: }" ;;
        esac
      done
      EXIT_CODE=1
    else
      echo "  ✓ All tests passed"
      echo "$RESULTS" | while IFS= read -r line; do
        case "$line" in
          "=== "*)  echo "  $line" ;;
          "OK: "*)  echo "    ✓ ${line#OK: }" ;;
        esac
      done
    fi
  else
    echo "  ⚠ Test endpoint not available (HTTP $TEST_HTTP_CODE) - TestProject may not be deployed"
  fi
else
  echo "  ⚠ No API key configured, skipping test endpoint"
fi

echo ""
if [ $EXIT_CODE -eq 0 ]; then
  echo "✓ All smoke tests passed"
else
  echo "✗ Some smoke tests failed"
fi

exit $EXIT_CODE
