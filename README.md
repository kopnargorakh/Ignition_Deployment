# Ignition 8.3 GitFlow CI/CD Setup

Complete GitFlow-based CI/CD pipeline for Ignition SCADA projects using GitHub Actions.

## Repository

```
git@github.com:Mustry-Solutions/ignition-83-cicd.git
```

## Architecture Overview

This repository implements a complete GitFlow workflow with automated deployments to multiple Ignition environments:

- **Development (dev)**: Auto-deploys from `develop` branch
- **Staging**: Auto-deploys from `release/*` branches
- **Production**: Auto-deploys from tags on `main` branch (e.g., `v1.0.0`)

## Repository Structure

```
.
├── .github/
│   └── workflows/
│       ├── ci-cd.yml             # Main CI/CD pipeline
│       └── promote-release.yml   # Release promotion pipeline
├── docker-compose.yml            # Multi-environment Docker setup
├── projects/
│   └── example-project/          # Ignition projects
│       ├── project.json
│       ├── com.inductiveautomation.perspective/
│       └── ignition/script-python/
├── config/
│   └── environments/             # Environment-specific configs
│       ├── dev.yaml
│       ├── staging.yaml
│       └── prod.yaml
├── scripts/
│   ├── deploy.sh                 # Main deployment script
│   ├── backup-gateway.sh         # Gateway backup
│   ├── restore-gateway.sh        # Gateway restore
│   ├── deploy-project.sh         # Deploy individual project
│   ├── package-project.sh        # Package project as ZIP
│   ├── db-migrate.sh             # Database migrations
│   ├── db-rollback.sh            # Database rollback
│   ├── validate-names.sh         # Linting and validation
│   └── smoke-test.sh             # Smoke tests
├── migrations/                   # Database migration files
└── backups/                      # Gateway backups
    ├── dev/
    ├── staging/
    └── prod/
```

## Quick Start

### 1. Start All Environments

```bash
docker-compose up -d
```

This starts three Ignition gateways:
- **Dev**: http://localhost:8088 (admin/Test123!)
- **Staging**: http://localhost:8188 (admin/Test123!)
- **Production**: http://localhost:8288 (admin/Test123!)

Plus a PostgreSQL database on port 5432.

### 2. Package and Deploy a Project

```bash
# Package a project
./scripts/package-project.sh projects/example-project

# Deploy to development
./scripts/deploy.sh dev
```

### 3. Run Database Migration

```bash
# Apply all migrations to dev
./scripts/db-migrate.sh dev up

# Check current version
./scripts/db-migrate.sh dev version
```

## GitFlow Workflow

### Branch Strategy

```
feature/* → develop → release/* → main
                                    ↓
                                  tags (v1.0.0)
```

| Branch Type | Purpose | Environment | Auto-Deploy |
|------------|---------|-------------|-------------|
| `develop` | Integration & QA | Development | Yes |
| `release/*` | UAT & Stabilization | Staging | Yes |
| `main` + tag | Production code | Production | Yes (on tag) |
| `feature/*` | Feature development | Local | No |
| `hotfix/*` | Critical fixes | Production | Yes (via tag) |

### Development Workflow

1. **Create feature branch**:
   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b feature/my-new-feature
   ```

2. **Develop and commit**:
   ```bash
   # Make changes to projects/
   git add .
   git commit -m "Add new feature"
   git push origin feature/my-new-feature
   ```

3. **Create Pull Request** to `develop`:
   - CI pipeline validates and builds
   - After merge, auto-deploys to Development

4. **Create release branch**:
   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b release/1.0.0
   git push origin release/1.0.0
   ```
   - Auto-deploys to Staging
   - Run UAT and testing

5. **Promote to production**:
   - Option A: Use promote-release pipeline (manual)
   - Option B: Create tag manually:
     ```bash
     git checkout main
     git merge release/1.0.0 --no-ff
     git tag -a v1.0.0 -m "Release version 1.0.0"
     git push origin main --tags
     ```
   - Auto-deploys to Production

## GitHub Actions Setup

### Prerequisites

1. **GitHub Repository**: Mustry-Solutions/ignition-83-cicd
2. **GitHub Actions**: Enabled by default
3. **Secrets**: Configure in repository settings for sensitive credentials

### Workflow Configuration

#### Main Pipeline (`.github/workflows/ci-cd.yml`)

This is automatically triggered on:
- Push to `develop`, `release/*`, `main`
- Tags matching `v*`
- Pull requests

#### Promote Release Workflow (`.github/workflows/promote-release.yml`)

Manually triggered workflow to promote releases:
1. Go to Actions → Promote Release
2. Click "Run workflow"
3. Enter release branch (e.g., `release/1.0.0`)
4. Enter tag (e.g., `v1.0.0`)
5. Choose whether to merge to main
6. Click "Run workflow"

### Required GitHub Secrets

Configure these in Settings → Secrets and variables → Actions:

#### Development Environment
- `DEV_GATEWAY_URL`: http://localhost:8088
- `DEV_GATEWAY_USER`: admin
- `DEV_GATEWAY_PASS`: Test123!
- `DEV_GATEWAY_API_KEY`: API token with config/project scan access
- `DEV_DB_URL`: postgres://ignition:<password>@localhost:5432/ignition_dev?sslmode=disable

#### Staging Environment
- `STAGING_GATEWAY_URL`: http://localhost:8188
- `STAGING_GATEWAY_USER`: admin
- `STAGING_GATEWAY_PASS`: Test123!
- `STAGING_GATEWAY_API_KEY`: API token with config/project scan access
- `STAGING_DB_URL`: postgres://ignition:ignition-db-password@localhost:5432/ignition_staging?sslmode=disable

#### Production Environment
- `PROD_GATEWAY_URL`: http://localhost:8288
- `PROD_GATEWAY_USER`: admin
- `PROD_GATEWAY_PASS`: Test123!
- `PROD_GATEWAY_API_KEY`: API token with config/project scan access
- `PROD_DB_URL`: postgres://ignition:ignition-db-password@localhost:5432/ignition_prod?sslmode=disable

**Note**: Use GitHub Environments and Secrets for secure credential management.

### Local Secret Handling

- Do not commit passwords or API keys in `config/environments/*.yaml`.
- Copy `.env.example` to `.env.local` and set local values.
- Optional local fallback: put only the API token in `secrets/gateway_api_key` (used when `*_GATEWAY_API_KEY` is not set).
- `ignition-local` now persists the full gateway data directory in the Docker named volume `ignition-local-data`, so local commissioning/auth/runtime state is retained outside version control.
- Local commissioning uses Docker-image environment variables (`GATEWAY_ADMIN_USERNAME` and `GATEWAY_ADMIN_PASSWORD`).
- Keep `GATEWAY_ADMIN_PASSWORD` set in your local environment so a fresh local gateway can complete `authSetup` without manual `/welcome` user creation.
- `secrets/` is local-only and gitignored (`.gitignore`), so this is acceptable for local Docker development.
- In CI/CD, always use GitHub Environment Secrets (or an external secrets manager), not files in the repo.
- Load variables before running scripts locally:

```bash
set -a
source .env.local
set +a
```

### Setting Up Environments in GitHub

1. Go to **Settings** → **Environments**
2. Create three environments:
   - `development` (no approval required)
   - `staging` (optional approval)
   - `production` (approval required)
3. Add secrets to each environment as needed
4. For production, configure required reviewers under environment protection rules

## Database Migrations

Using [golang-migrate](https://github.com/golang-migrate/migrate) for database versioning.

### Create New Migration

```bash
# Using migrate CLI (if installed)
migrate create -ext sql -dir migrations -seq add_new_table

# Or manually create:
# migrations/000003_add_new_table.up.sql
# migrations/000003_add_new_table.down.sql
```

### Run Migrations

```bash
# Apply all pending migrations
./scripts/db-migrate.sh dev up

# Rollback last migration
./scripts/db-migrate.sh dev down

# Go to specific version
./scripts/db-migrate.sh dev goto 2

# Check current version
./scripts/db-migrate.sh dev version
```

### Safe Rollback

```bash
./scripts/db-rollback.sh staging 5
```

This ensures the database stays in a good state after rollback.

## Linting and Validation

Code style requirements:
- Files: camelCase
- Functions: camelCase
- Variables: camelCase
- Indentation: tabs (not spaces)
- No print statements in Python code
- Perspective components: PascalCase
- Component properties: camelCase

### Run Validation

```bash
./scripts/validate-names.sh projects/
```

This is automatically run in the CI pipeline.

## Backup and Restore

### Create Backup

```bash
./scripts/backup-gateway.sh prod
```

Backups are stored in `backups/<environment>/` and automatically cleaned up based on retention policy.

### Restore from Backup

```bash
./scripts/restore-gateway.sh prod ./backups/prod/gateway_backup_prod_20240101_120000.gwbk
```

## Docker Environment Management

### Start Specific Environment

```bash
# Start only development
docker-compose up -d ignition-dev

# Start dev and staging
docker-compose up -d ignition-dev ignition-staging
```

### View Logs

```bash
# All services
docker-compose logs -f

# Specific environment
docker-compose logs -f ignition-dev
```

### Stop All

```bash
docker-compose down
```

### Full Reset

```bash
# Stop and remove everything including volumes
docker-compose down -v

# Restart
docker-compose up -d
```

## Testing

### Smoke Tests

```bash
./scripts/smoke-test.sh dev
./scripts/smoke-test.sh staging
./scripts/smoke-test.sh prod
```

### Manual Testing

Access the gateways at:
- Dev: http://localhost:8088/web/home
- Staging: http://localhost:8188/web/home
- Production: http://localhost:8288/web/home

## Project Development

### Adding a New Project

1. Create project directory:
   ```bash
   mkdir -p projects/my-new-project
   ```

2. Add project files following Ignition structure:
   ```
   projects/my-new-project/
   ├── project.json
   ├── com.inductiveautomation.perspective/
   │   └── views/
   └── ignition/
       └── script-python/
   ```

3. Commit and push:
   ```bash
   git add projects/my-new-project
   git commit -m "Add new project: my-new-project"
   git push
   ```

4. CI pipeline will automatically package and deploy

### Project Structure Guidelines

Follow Ignition 8.3 project structure:
- `project.json`: Project metadata
- `com.inductiveautomation.perspective/`: Perspective views and components
- `ignition/script-python/`: Python script modules
- `ignition/named-query/`: Named queries
- `ignition/tags/`: Tag definitions

## Troubleshooting

### Gateway Not Responding

```bash
# Check container status
docker-compose ps

# View logs
docker-compose logs ignition-dev

# Restart gateway
docker-compose restart ignition-dev
```

### Database Connection Issues

```bash
# Check PostgreSQL is running
docker-compose ps postgres

# Connect to database
docker exec -it ignition-postgres psql -U ignition -d ignition
```

### Deployment Failures

1. Check gateway is healthy:
   ```bash
   curl http://localhost:8088/StatusPing
   ```

2. Verify credentials in config files

3. Check deployment logs in Azure DevOps pipeline

### Migration Failures

```bash
# Check current version
./scripts/db-migrate.sh dev version

# Force to specific version
./scripts/db-migrate.sh dev goto 1
```

## Advanced Configuration

### Custom Deployment Scripts

Modify `config/environments/<env>.yaml` to add custom deployment steps:

```yaml
deployment:
  pre_deploy_scripts:
    - db_migrate
    - custom_validation
  post_deploy_scripts:
    - smoke_test
    - notify_team
```

### Environment-Specific Settings

Each environment has its own configuration file in `config/environments/`:
- Gateway URL and credentials
- Database connection
- Backup retention policy
- Deployment scripts

## Resources

- [Ignition 8.3 Docker Documentation](https://docs.inductiveautomation.com/docs/8.3/platform/docker-image)
- [Ignition Version Control Guide](https://docs.inductiveautomation.com/docs/8.3/tutorials/version-control-guide)
- [Golang Migrate Documentation](https://github.com/golang-migrate/migrate)
- [GitFlow Workflow](https://nvie.com/posts/a-successful-git-branching-model/)

## Support

For issues or questions:
1. Check this README
2. Review Azure DevOps pipeline logs
3. Check container logs: `docker-compose logs`
4. Contact DevOps team
# Testing GitHub Actions CI/CD
