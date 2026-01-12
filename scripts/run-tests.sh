#!/bin/bash
# Run Jython tests via WebDev API
# Usage: ./scripts/run-tests.sh [environment]
# Example: ./scripts/run-tests.sh local

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENVIRONMENT="${1:-local}"

CONFIG_FILE="$PROJECT_ROOT/config/environments/${ENVIRONMENT}.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Configuration file not found: $CONFIG_FILE"
  exit 1
fi

GATEWAY_URL=$(grep "url:" "$CONFIG_FILE" | head -1 | awk '{print $2}')

echo "Running tests on $ENVIRONMENT..."
echo ""

RESPONSE=$(curl -s "${GATEWAY_URL}/system/webdev/TestProject/api/test")

echo "$RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('results', 'No results'))
except:
    print(sys.stdin.read())
"
