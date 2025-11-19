# Future CI/CD Checks

This document outlines additional automated checks to be implemented in the CI/CD pipeline to improve code quality, security, and deployment reliability.

---

## 1. Security Checks (No Hardcoded Credentials)

### Purpose
Prevent sensitive information like passwords, API keys, database credentials, and gateway URLs from being committed to the repository.

### Why This Matters
- Hardcoded credentials in version control pose a major security risk
- Credentials can be exposed if the repository becomes public
- Makes credential rotation difficult and error-prone
- Violates security best practices and compliance requirements

### Implementation Approach

```yaml
- name: Check for Hardcoded Credentials
  run: |
    echo "Scanning for hardcoded credentials..."

    # Check for common password patterns
    if grep -rE "password\s*=\s*['\"][^'\"]+['\"]" projects/ scripts/ config/ --include="*.json" --include="*.py" --include="*.yaml"; then
      echo "❌ Found hardcoded passwords"
      exit 1
    fi

    # Check for API keys
    if grep -rE "(api[_-]?key|apikey|api[_-]?secret)\s*=\s*['\"][^'\"]+['\"]" projects/ scripts/ --include="*.json" --include="*.py"; then
      echo "❌ Found hardcoded API keys"
      exit 1
    fi

    # Check for database connection strings
    if grep -rE "jdbc:.*://.*:.*@" projects/ scripts/ config/ --include="*.json" --include="*.py" --include="*.yaml"; then
      echo "❌ Found database connection strings with credentials"
      exit 1
    fi

    # Check for gateway credentials
    if grep -ri "localhost:8088.*admin.*password\|gateway.*admin.*password" projects/ scripts/; then
      echo "❌ Found hardcoded gateway credentials"
      exit 1
    fi

    echo "✅ No hardcoded credentials found"
```

### What to Check For
- Database connection strings with embedded passwords
- Gateway admin credentials (username/password)
- MQTT broker credentials
- API keys and tokens
- PLC connection passwords
- Certificate passphrases
- Any string matching common secret patterns

### Best Practices
- Use environment variables for all credentials
- Store secrets in GitHub Secrets for CI/CD workflows
- Use Ignition's credential management system
- Document required environment variables in `.env.example`
- Never commit `.env` files with actual values

### Example Error Message
```
❌ Error: Found hardcoded credentials in projects/my-project/gateway-config.json
Line 45: "password": "admin123"

Please use environment variables or Ignition credentials instead.
```

---

## 2. Migration Validation (Up/Down Scripts Paired)

### Purpose
Ensure every database migration has a corresponding rollback script, enabling safe deployment rollbacks without data loss.

### Why This Matters
- Failed deployments need a safe rollback path
- Production issues require quick recovery
- Prevents database schema inconsistencies
- Enables testing of rollback procedures before production
- Required for compliance and audit trails

### Implementation Approach

```yaml
- name: Validate Migration Scripts
  run: |
    echo "Validating migration scripts..."

    # Check that migrations directory structure exists
    if [ ! -d "migrations/up" ] || [ ! -d "migrations/down" ]; then
      echo "❌ Missing migrations/up or migrations/down directory"
      exit 1
    fi

    # Check for paired up/down scripts
    missing_rollbacks=()
    for migration in migrations/up/*.sql; do
      if [ ! -f "$migration" ]; then
        continue  # No migration files yet
      fi

      migration_name=$(basename "$migration")
      rollback="migrations/down/$migration_name"

      if [ ! -f "$rollback" ]; then
        missing_rollbacks+=("$migration_name")
      fi
    done

    # Check for orphaned down scripts
    orphaned_rollbacks=()
    for rollback in migrations/down/*.sql; do
      if [ ! -f "$rollback" ]; then
        continue  # No rollback files yet
      fi

      rollback_name=$(basename "$rollback")
      migration="migrations/up/$rollback_name"

      if [ ! -f "$migration" ]; then
        orphaned_rollbacks+=("$rollback_name")
      fi
    done

    # Report errors
    if [ ${#missing_rollbacks[@]} -gt 0 ]; then
      echo "❌ Migrations missing rollback scripts:"
      printf '%s\n' "${missing_rollbacks[@]}"
      exit 1
    fi

    if [ ${#orphaned_rollbacks[@]} -gt 0 ]; then
      echo "⚠️  Warning: Rollback scripts without migrations:"
      printf '%s\n' "${orphaned_rollbacks[@]}"
    fi

    echo "✅ All migrations have paired rollback scripts"

- name: Validate SQL Syntax
  run: |
    # Basic SQL syntax validation
    for file in migrations/up/*.sql migrations/down/*.sql; do
      if [ ! -f "$file" ]; then
        continue
      fi

      # Check for common SQL errors
      if grep -q ";" <<< "$(tail -c 1 "$file")"; then
        : # File ends with semicolon, good
      else
        echo "⚠️  Warning: $file doesn't end with semicolon"
      fi

      # Check for destructive operations in up scripts
      if [[ "$file" == migrations/up/* ]] && grep -qi "DROP TABLE\|TRUNCATE" "$file"; then
        echo "⚠️  Warning: Destructive operation in $file"
      fi
    done
```

### Migration Naming Convention
```
migrations/
├── up/
│   ├── 001_create_users_table.sql
│   ├── 002_add_timestamps.sql
│   └── 003_create_indexes.sql
└── down/
    ├── 001_create_users_table.sql
    ├── 002_add_timestamps.sql
    └── 003_create_indexes.sql
```

### Required Checks
- Every `up/*.sql` has matching `down/*.sql`
- Migration files follow naming convention (sequential numbers)
- SQL files are valid (basic syntax check)
- No orphaned rollback scripts
- Warn on destructive operations in up scripts

### Example Error Message
```
❌ Migrations missing rollback scripts:
  - 003_create_indexes.sql
  - 004_add_user_roles.sql

Please create corresponding files in migrations/down/ before proceeding.
```

---

## 3. Version Bump Enforcement (On Release Branches)

### Purpose
Ensure that version numbers are incremented when creating release branches, preventing version conflicts and deployment confusion.

### Why This Matters
- Prevents deploying multiple builds with same version number
- Ensures traceability between releases and code changes
- Required for proper artifact versioning
- Helps track which version is deployed to each environment
- Enables rollback to specific versions

### Implementation Approach

```yaml
- name: Enforce Version Bump on Release Branch
  if: startsWith(github.head_ref, 'release/') && github.base_ref == 'main'
  run: |
    echo "Checking version bump for release branch..."

    # Extract version from release branch name
    # Expected format: release/v1.2.3
    BRANCH_VERSION="${{ github.head_ref }}"
    BRANCH_VERSION="${BRANCH_VERSION#release/}"
    BRANCH_VERSION="${BRANCH_VERSION#v}"

    echo "Release branch version: $BRANCH_VERSION"

    # Get version from main branch
    git fetch origin main
    MAIN_VERSION=$(git show origin/main:VERSION 2>/dev/null || echo "0.0.0")

    echo "Main branch version: $MAIN_VERSION"

    # Compare versions (simplified - could use semver comparison)
    if [ "$BRANCH_VERSION" == "$MAIN_VERSION" ]; then
      echo "❌ Version not bumped! Release branch has same version as main."
      echo "Please update VERSION file to $BRANCH_VERSION"
      exit 1
    fi

    # Validate semantic versioning format
    if [[ ! "$BRANCH_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo "❌ Invalid version format: $BRANCH_VERSION"
      echo "Expected format: MAJOR.MINOR.PATCH (e.g., 1.2.3)"
      exit 1
    fi

    # Check that VERSION file matches branch name
    CURRENT_VERSION=$(cat VERSION 2>/dev/null || echo "0.0.0")
    if [ "$CURRENT_VERSION" != "$BRANCH_VERSION" ]; then
      echo "❌ VERSION file ($CURRENT_VERSION) doesn't match release branch ($BRANCH_VERSION)"
      exit 1
    fi

    echo "✅ Version bump validated: $MAIN_VERSION → $BRANCH_VERSION"
```

### Version File Location
Create a `VERSION` file in the repository root:
```
1.2.3
```

### Release Branch Naming Convention
```
release/v1.0.0  → Major release
release/v1.1.0  → Minor release (new features)
release/v1.0.1  → Patch release (bug fixes)
```

### Validation Rules
- Version must follow semantic versioning (MAJOR.MINOR.PATCH)
- Version in `VERSION` file must match release branch name
- Version must be higher than current main branch version
- Version must not already exist as a git tag

### Example Error Message
```
❌ Version not bumped! Release branch has same version as main.

Current main version: 1.2.3
Release branch: release/v1.2.3

Please update VERSION file to 1.3.0 (or appropriate version)
```

---

## 4. Tag Format Validation (For Production Releases)

### Purpose
Enforce consistent git tag formatting for production releases, ensuring clear version history and enabling automated release processes.

### Why This Matters
- Enables automated deployment triggered by tags
- Provides clear release history in git
- Allows semantic versioning tools to work correctly
- Prevents accidental or malformed releases
- Required for changelog generation and release notes

### Implementation Approach

```yaml
- name: Validate Tag Format
  if: startsWith(github.ref, 'refs/tags/')
  run: |
    TAG_NAME="${{ github.ref_name }}"
    echo "Validating tag: $TAG_NAME"

    # Validate semantic versioning format with 'v' prefix
    if [[ ! "$TAG_NAME" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo "❌ Invalid tag format: $TAG_NAME"
      echo "Expected format: vMAJOR.MINOR.PATCH (e.g., v1.2.3)"
      echo ""
      echo "Valid examples:"
      echo "  - v1.0.0 (major release)"
      echo "  - v1.1.0 (minor release with new features)"
      echo "  - v1.0.1 (patch release with bug fixes)"
      exit 1
    fi

    # Extract version number
    VERSION="${TAG_NAME#v}"

    # Verify tag matches VERSION file
    if [ -f "VERSION" ]; then
      FILE_VERSION=$(cat VERSION)
      if [ "$FILE_VERSION" != "$VERSION" ]; then
        echo "❌ Tag version ($VERSION) doesn't match VERSION file ($FILE_VERSION)"
        exit 1
      fi
    fi

    # Verify tag is created from main branch
    BRANCH=$(git branch -r --contains "tags/$TAG_NAME" | grep -o "origin/main" || echo "")
    if [ "$BRANCH" != "origin/main" ]; then
      echo "❌ Tag $TAG_NAME is not on main branch"
      echo "Production tags must be created from main branch only"
      exit 1
    fi

    echo "✅ Tag format validated: $TAG_NAME"

- name: Check for Duplicate Tag
  if: startsWith(github.ref, 'refs/tags/')
  run: |
    TAG_NAME="${{ github.ref_name }}"

    # Check if tag already exists remotely
    if git ls-remote --tags origin | grep -q "refs/tags/$TAG_NAME$"; then
      echo "⚠️  Warning: Tag $TAG_NAME already exists remotely"
    fi

- name: Validate Tag Corresponds to Release Branch
  if: startsWith(github.ref, 'refs/tags/')
  run: |
    TAG_NAME="${{ github.ref_name }}"
    VERSION="${TAG_NAME#v}"

    # Check git history for corresponding release branch
    RELEASE_BRANCH="release/v$VERSION"

    if ! git branch -r --contains "tags/$TAG_NAME" | grep -q "$RELEASE_BRANCH"; then
      echo "⚠️  Warning: Tag $TAG_NAME doesn't correspond to release branch $RELEASE_BRANCH"
      echo "This may indicate the tag was created outside the standard workflow"
    else
      echo "✅ Tag corresponds to release branch: $RELEASE_BRANCH"
    fi
```

### Tag Naming Convention
```
v1.0.0  → Production release (major)
v1.1.0  → Production release (minor)
v1.0.1  → Production release (patch)
```

### Validation Rules
- Must start with lowercase 'v'
- Must follow semantic versioning: vMAJOR.MINOR.PATCH
- All components must be numeric (no pre-release suffixes)
- Must match VERSION file in repository
- Should be created from main branch only
- Should correspond to a release branch

### Invalid Tag Examples
```
❌ 1.0.0        (missing 'v' prefix)
❌ V1.0.0       (uppercase 'V')
❌ v1.0         (missing patch version)
❌ v1.0.0-beta  (pre-release suffix not allowed for production)
❌ v01.00.00    (leading zeros not allowed)
```

### Example Error Message
```
❌ Invalid tag format: 1.2.3
Expected format: vMAJOR.MINOR.PATCH (e.g., v1.2.3)

Valid examples:
  - v1.0.0 (major release)
  - v1.1.0 (minor release with new features)
  - v1.0.1 (patch release with bug fixes)
```

---

## Implementation Priority

1. **Security Checks** - Immediate priority to prevent credential leaks
2. **Migration Validation** - Important for safe deployments
3. **Tag Format Validation** - Needed before next production release
4. **Version Bump Enforcement** - Can be implemented alongside tag validation

## Testing Strategy

Before enabling these checks as required:
1. Run them manually on current codebase
2. Fix any existing violations
3. Enable as non-blocking warnings first
4. Monitor for false positives
5. Enable as required checks after validation period

## Related Documentation

- See `cicd-setup.md` for current CI/CD configuration
- See `db-migration.md` for migration best practices
- See `.github/workflows/ci-cd.yml` for existing checks
