# GitHub Actions Quick Start Guide

This guide will walk you through setting up the complete CI/CD pipeline in GitHub Actions in under 10 minutes.

## Current Status

✅ Code pushed to GitHub (main branch)
✅ GitHub Actions workflows created
⏳ Repository secrets and environments need to be configured

## Prerequisites

- GitHub account with access to: https://github.com/Mustry-Solutions/ignition-83-cicd
- Repository already contains `.github/workflows/ci-cd.yml` and `.github/workflows/promote-release.yml`
- Admin access to repository settings

## Step 1: Create Environments (3 minutes)

1. **Navigate to Environments**
   - Go to: https://github.com/Mustry-Solutions/ignition-83-cicd/settings/environments
   - Click "New environment"

2. **Create Development Environment**
   - Name: `development`
   - Click "Configure environment"
   - No protection rules needed for development
   - Click "Save protection rules"

3. **Create Staging Environment**
   - Name: `staging`
   - Click "Configure environment"
   - (Optional) Add required reviewers if you want approval for staging
   - Click "Save protection rules"

4. **Create Production Environment**
   - Name: `production`
   - Click "Configure environment"
   - **Enable "Required reviewers"**
   - Add yourself (and other team members) as reviewers
   - **Enable "Wait timer"** (optional): 5 minutes
   - Click "Save protection rules"

## Step 2: Configure Repository Secrets (3 minutes)

1. **Navigate to Secrets**
   - Go to: https://github.com/Mustry-Solutions/ignition-83-cicd/settings/secrets/actions
   - Click "New repository secret" for each secret below

2. **Add Required Secrets** (for local Docker setup)

   | Secret Name | Value | Notes |
   |------------|-------|-------|
   | `DEV_GATEWAY_URL` | `http://localhost:8088` | Development gateway URL |
   | `DEV_GATEWAY_USER` | `admin` | Development admin username |
   | `DEV_GATEWAY_PASS` | `dev-password` | Development admin password |
   | `STAGING_GATEWAY_URL` | `http://localhost:8188` | Staging gateway URL |
   | `STAGING_GATEWAY_USER` | `admin` | Staging admin username |
   | `STAGING_GATEWAY_PASS` | `staging-password` | Staging admin password |
   | `STAGING_DB_URL` | `postgresql://ignition:ignition-db-password@localhost:5432/ignition?sslmode=disable` | Staging database URL |
   | `PROD_GATEWAY_URL` | `http://localhost:8288` | Production gateway URL |
   | `PROD_GATEWAY_USER` | `admin` | Production admin username |
   | `PROD_GATEWAY_PASS` | `prod-password` | Production admin password |
   | `PROD_DB_URL` | `postgresql://ignition:ignition-db-password@localhost:5432/ignition?sslmode=disable` | Production database URL |

   **Important**: All these values are automatically marked as secrets and will be masked in logs!

3. **Save Secrets**
   - Click "Add secret" for each one
   - Verify all secrets are added by checking the secrets list

## Step 3: Configure Branch Protection Rules (2 minutes)

1. **Navigate to Branch Settings**
   - Go to: https://github.com/Mustry-Solutions/ignition-83-cicd/settings/branches
   - Click "Add branch protection rule"

2. **Protect Main Branch**
   - Branch name pattern: `main`
   - Enable the following:
     - ☑ "Require a pull request before merging"
       - Required approvals: 1
     - ☑ "Require status checks to pass before merging"
       - Search and select: "Build and Validate"
     - ☑ "Require branches to be up to date before merging"
     - ☑ "Do not allow bypassing the above settings"
   - Click "Create"

3. **Protect Develop Branch**
   - Click "Add branch protection rule" again
   - Branch name pattern: `develop`
   - Enable the same settings as main (or lighter rules if preferred)
   - Click "Create"

4. **Protect Release Branches**
   - Click "Add branch protection rule" again
   - Branch name pattern: `release/*`
   - Enable basic protection:
     - ☑ "Require a pull request before merging"
     - ☑ "Require status checks to pass before merging"
   - Click "Create"

## Step 4: Test the Pipeline (2 minutes)

### Test Auto-Deploy to Development

1. Create a develop branch and make a small change:
   ```bash
   git checkout -b develop
   echo "# Test deployment" >> README.md
   git add README.md
   git commit -m "Test auto-deployment to Development"
   git push origin develop
   ```

2. Watch the workflow run:
   - Go to: https://github.com/Mustry-Solutions/ignition-83-cicd/actions
   - You should see a new workflow run triggered by the push to develop
   - It should automatically deploy to the development environment

### Test Release Flow to Staging

1. Create a release branch:
   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b release/1.0.0
   git push -u origin release/1.0.0
   ```

2. Watch the workflow:
   - Go to Actions tab
   - Should automatically deploy to staging environment

### Test Production Deploy with Approval

1. Use the promote-release workflow:
   - Go to: https://github.com/Mustry-Solutions/ignition-83-cicd/actions
   - Click "Promote Release" workflow
   - Click "Run workflow"
   - Fill in:
     - Release Branch: `release/1.0.0`
     - Release Tag: `v1.0.0`
     - Merge to main: ☑ (checked)
   - Click "Run workflow"

2. Watch the workflow:
   - The workflow will create a tag which triggers production deployment
   - You'll receive a review notification for production deployment
   - Click "Review pending deployments"
   - Select "production" and click "Approve and deploy"

## Step 5: Verify Everything Works

1. **Check Actions Dashboard**
   - Go to: https://github.com/Mustry-Solutions/ignition-83-cicd/actions
   - All workflow runs should be green ✅

2. **Check Deployed Projects** (if using local Docker)
   - Dev: http://localhost:8088/web/home
   - Staging: http://localhost:8188/web/home
   - Production: http://localhost:8288/web/home

3. **Verify TestProject is loaded** in each gateway:
   - Login with credentials (admin / [env]-password)
   - Navigate to Designer
   - You should see "TestProject" in the project list

## GitFlow Automation Summary

Once setup is complete, the workflows will automatically:

| Branch Pattern | Trigger | Deploys To | Approval Required |
|---------------|---------|------------|-------------------|
| `develop` | Push | Development | No (auto) |
| `release/*` | Push | Staging | No (auto) |
| `main` + tag | Push tag | Production | Yes (manual) |
| `feature/*` | PR to develop | Validation only | N/A |
| `hotfix/*` | PR to main | Validation only | N/A |

## Understanding GitHub Actions Workflows

### Main CI/CD Workflow (`.github/workflows/ci-cd.yml`)

This workflow has 4 jobs:
1. **build**: Validates and packages all Ignition projects
2. **deploy-dev**: Deploys to development (only on develop branch)
3. **deploy-staging**: Deploys to staging (only on release/* branches)
4. **deploy-prod**: Deploys to production (only on v* tags)

### Promote Release Workflow (`.github/workflows/promote-release.yml`)

This manual workflow has 3 jobs:
1. **validate**: Checks that the release branch exists
2. **create-tag**: Creates and pushes the release tag
3. **merge-to-main**: Merges the release branch to main (if selected)

## Troubleshooting

### Workflow fails with "Secret not found"
- Make sure you created all required secrets in Settings → Secrets → Actions
- Secret names are case-sensitive
- Check that secrets are available to the environment being deployed

### Deployment fails with connection error
- Verify Docker containers are running: `docker-compose ps`
- Check gateway URLs are correct in secrets
- For remote deployments, ensure network connectivity from GitHub Actions runners

### Project doesn't appear in Ignition
- Check workflow logs in the Actions tab
- Verify project was packaged correctly in the build job
- Check gateway logs: `docker logs ignition-dev -f`
- Try manual gateway restart: `docker restart ignition-dev`

### Approval notifications not received
- Check your GitHub notification settings
- Go to: https://github.com/settings/notifications
- Enable "Actions" notifications
- Check "Participating" or "Watching" for the repository

### Self-hosted Runner for Local Docker

If deploying to local Docker containers, you'll need a self-hosted runner:

1. **Add Self-hosted Runner**
   - Go to: https://github.com/Mustry-Solutions/ignition-83-cicd/settings/actions/runners
   - Click "New self-hosted runner"
   - Follow instructions for your OS
   - Make sure Docker is accessible from the runner

2. **Update Workflows**
   - Change `runs-on: ubuntu-latest` to `runs-on: self-hosted`
   - Only needed for deploy jobs that need Docker access

## Next Steps

- [ ] Configure self-hosted runner for Docker access (if deploying to local Docker)
- [ ] Update gateway URLs for actual deployment servers
- [ ] Add more Ignition projects to the repository
- [ ] Customize validation rules in `scripts/validate-names.sh`
- [ ] Add database migration scripts in `migrations/`
- [ ] Set up monitoring and alerting
- [ ] Configure GitHub environments with environment-specific secrets
- [ ] Add status badges to README

## Adding Status Badges

Add these to your README.md to show workflow status:

```markdown
[![CI/CD Pipeline](https://github.com/Mustry-Solutions/ignition-83-cicd/actions/workflows/ci-cd.yml/badge.svg)](https://github.com/Mustry-Solutions/ignition-83-cicd/actions/workflows/ci-cd.yml)
```

## Support

For issues or questions:
- Check the main documentation: `README.md`
- Review workflow logs in GitHub Actions
- Check local deployment with: `./scripts/test-full-pipeline.sh`
- Create an issue in the repository

## Useful GitHub Actions Documentation

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [Using Environments](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
- [Encrypted Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)

---

**Last Updated**: 2025-11-17
**Status**: Ready for configuration
**Repository**: https://github.com/Mustry-Solutions/ignition-83-cicd
