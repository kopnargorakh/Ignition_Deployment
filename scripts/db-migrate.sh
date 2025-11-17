#!/bin/bash
set -e

# Database Migration Script using golang-migrate
# Usage: ./scripts/db-migrate.sh <environment> <command>
# Example: ./scripts/db-migrate.sh dev up
# Example: ./scripts/db-migrate.sh staging goto 5

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENVIRONMENT=$1
COMMAND=${2:-up}

if [ -z "$ENVIRONMENT" ]; then
  echo "Error: Environment not specified"
  echo "Usage: ./scripts/db-migrate.sh <environment> <command>"
  echo "Commands: up, down, goto <version>, version"
  exit 1
fi

CONFIG_FILE="$PROJECT_ROOT/config/environments/${ENVIRONMENT}.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Configuration file not found: $CONFIG_FILE"
  exit 1
fi

# Check for environment-specific DB_URL variable (CI/CD)
ENV_VAR_NAME="$(echo ${ENVIRONMENT} | tr '[:lower:]' '[:upper:]')_DB_URL"  # Convert to uppercase
DB_URL_FROM_ENV="$(eval echo \$${ENV_VAR_NAME})"

if [ -n "$DB_URL_FROM_ENV" ]; then
  # Use environment variable if set (preferred in CI/CD)
  DB_URL="$DB_URL_FROM_ENV"
  DB_NAME=$(echo "$DB_URL" | sed -n 's#.*/\([^?]*\).*#\1#p')
else
  # Fall back to parsing config file
  DB_HOST=$(grep "host:" "$CONFIG_FILE" | grep -A 5 "database:" | tail -1 | awk '{print $2}')
  DB_PORT=$(grep "port:" "$CONFIG_FILE" | grep -A 5 "database:" | tail -1 | awk '{print $2}')
  DB_NAME=$(grep "name:" "$CONFIG_FILE" | grep -A 5 "database:" | tail -1 | awk '{print $2}')
  DB_USER=$(grep "username:" "$CONFIG_FILE" | grep -A 5 "database:" | tail -1 | awk '{print $2}')
  DB_PASS=$(grep "password:" "$CONFIG_FILE" | grep -A 5 "database:" | tail -1 | awk '{print $2}')

  # Construct database URL
  DB_URL="postgres://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=disable"
fi

MIGRATIONS_PATH="$PROJECT_ROOT/migrations"

echo "=========================================="
echo "Database Migration - $ENVIRONMENT"
echo "=========================================="
echo "Database: $DB_NAME"
echo "Command: $COMMAND"
echo ""

# Check if migrate tool is installed
if ! command -v migrate &> /dev/null; then
  echo "Error: golang-migrate not found"
  echo ""
  echo "Installing migrate tool using Docker..."

  # Use migrate via Docker if not installed locally
  MIGRATE_CMD="docker run --rm -v ${MIGRATIONS_PATH}:/migrations --network host migrate/migrate"
else
  MIGRATE_CMD="migrate"
fi

# Execute migration based on command
case "$COMMAND" in
  up)
    echo "Running all pending migrations..."
    if [ "$MIGRATE_CMD" = "migrate" ]; then
      migrate -path "$MIGRATIONS_PATH" -database "$DB_URL" up
    else
      docker run --rm -v "${MIGRATIONS_PATH}:/migrations" --network host migrate/migrate \
        -path=/migrations -database "$DB_URL" up
    fi
    echo "✓ Migrations completed"
    ;;

  down)
    echo "Rolling back last migration..."
    if [ "$MIGRATE_CMD" = "migrate" ]; then
      migrate -path "$MIGRATIONS_PATH" -database "$DB_URL" down 1
    else
      docker run --rm -v "${MIGRATIONS_PATH}:/migrations" --network host migrate/migrate \
        -path=/migrations -database "$DB_URL" down 1
    fi
    echo "✓ Rollback completed"
    ;;

  goto)
    VERSION=$3
    if [ -z "$VERSION" ]; then
      echo "Error: Version not specified for goto command"
      exit 1
    fi
    echo "Migrating to version $VERSION..."
    if [ "$MIGRATE_CMD" = "migrate" ]; then
      migrate -path "$MIGRATIONS_PATH" -database "$DB_URL" goto "$VERSION"
    else
      docker run --rm -v "${MIGRATIONS_PATH}:/migrations" --network host migrate/migrate \
        -path=/migrations -database "$DB_URL" goto "$VERSION"
    fi
    echo "✓ Migration to version $VERSION completed"
    ;;

  version)
    echo "Current database version:"
    if [ "$MIGRATE_CMD" = "migrate" ]; then
      migrate -path "$MIGRATIONS_PATH" -database "$DB_URL" version
    else
      docker run --rm -v "${MIGRATIONS_PATH}:/migrations" --network host migrate/migrate \
        -path=/migrations -database "$DB_URL" version
    fi
    ;;

  *)
    echo "Error: Unknown command: $COMMAND"
    echo "Available commands: up, down, goto <version>, version"
    exit 1
    ;;
esac

echo ""
