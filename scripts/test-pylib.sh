#!/bin/bash
# Run pylib tests
# Usage: ./scripts/test-pylib.sh [test_path]
# Example: ./scripts/test-pylib.sh pylib/Mustry/Tests/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_PATH="${1:-pylib/}"

cd "$PROJECT_ROOT"

# Check if venv exists, create if not
if [ ! -d "venv" ]; then
  echo "Creating virtual environment..."
  python3 -m venv venv
fi

# Activate venv and install pytest if needed
source venv/bin/activate

if ! pip show pytest > /dev/null 2>&1; then
  echo "Installing pytest..."
  pip install pytest -q
fi

echo "Running tests in $TEST_PATH..."
python -m pytest "$TEST_PATH" -v

deactivate
