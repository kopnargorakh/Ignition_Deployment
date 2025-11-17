#!/bin/bash
set -e

# Full Pipeline Test Script
# Tests the complete GitFlow deployment workflow locally

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "Full Pipeline Test"
echo "=========================================="
echo ""

# Step 1: Check Docker containers
echo "Step 1: Checking Docker containers..."
if ! docker-compose ps | grep -q "Up"; then
  echo "Error: Docker containers not running"
  echo "Please run: docker-compose up -d"
  exit 1
fi
echo "✓ All containers running"
echo ""

# Step 2: Validate project structure
echo "Step 2: Validating project structure..."
"$SCRIPT_DIR/validate-names.sh" "$PROJECT_ROOT/projects"
echo ""

# Step 3: Package projects
echo "Step 3: Packaging projects..."
for project_dir in "$PROJECT_ROOT/projects"/*/; do
  if [ -d "$project_dir" ]; then
    "$SCRIPT_DIR/package-project.sh" "$project_dir"
  fi
done
echo ""

# Step 4: Run smoke tests on all environments
echo "Step 4: Running smoke tests..."
echo ""
echo "Testing Development environment:"
"$SCRIPT_DIR/smoke-test.sh" dev
echo ""

echo "Testing Staging environment:"
"$SCRIPT_DIR/smoke-test.sh" staging
echo ""

echo "Testing Production environment:"
"$SCRIPT_DIR/smoke-test.sh" prod
echo ""

# Step 5: Summary
echo "=========================================="
echo "✓ Full Pipeline Test Completed"
echo "=========================================="
echo ""
echo "All systems are operational:"
echo "  ✓ Docker containers running"
echo "  ✓ Project validation passed"
echo "  ✓ Project packaging successful"
echo "  ✓ All environment smoke tests passed"
echo ""
echo "Next steps:"
echo "  1. Access gateways at:"
echo "     - Dev: http://localhost:8088/web/home"
echo "     - Staging: http://localhost:8188/web/home"
echo "     - Production: http://localhost:8288/web/home"
echo ""
echo "  2. Push to GitHub:"
echo "     git remote add origin git@github.com:Mustry-Solutions/ignition-83-cicd.git"
echo "     git push -u origin main develop"
echo ""
echo "  3. Follow GITHUB_ACTIONS_QUICKSTART.md to complete CI/CD configuration"
echo ""
