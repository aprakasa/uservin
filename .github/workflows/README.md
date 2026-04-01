# GitHub Actions Workflows

This directory contains GitHub Actions workflows for the uservin project.

## Workflows

### 1. PR Checks (`pr-checks.yml`)
**Triggers:** On pull requests to main/master branch

**What it does:**
- Runs the full test suite
- Runs shellcheck for bash linting
- Builds the bundled script and verifies syntax

**Why:** Catches issues before merging to main

### 2. Auto Build (`auto-build.yml`)
**Triggers:** On push to main/master when lib files change

**What it does:**
- Automatically builds `uservin.sh` from lib files
- Commits the bundled file back to the repo
- Only commits if there are actual changes

**Why:** Ensures the bundled script is always up-to-date with lib changes

### 3. Release (`release.yml`)
**Triggers:** When you push a tag starting with 'v' (e.g., `v1.0.0`)

**What it does:**
- Builds the release bundle
- Creates a GitHub Release
- Attaches `uservin.sh` as a release asset
- Generates installation instructions

**Usage:**
```bash
git tag v1.0.0
git push origin v1.0.0
```

### 4. Scheduled Tests (`scheduled.yml`)
**Triggers:** Every Sunday at midnight UTC (or manually)

**What it does:**
- Runs tests on multiple Ubuntu versions (20.04, 22.04, 24.04)
- Runs shellcheck

**Why:** Catches issues that might appear due to environment changes

## Setup

No setup required! The workflows use GitHub's built-in tokens:
- `GITHUB_TOKEN` - Automatically provided by GitHub

## Manual Triggers

You can manually trigger workflows from the GitHub UI:
1. Go to **Actions** tab
2. Select the workflow
3. Click **Run workflow**

## Badges

Add these to your README.md to show workflow status:

```markdown
![PR Checks](https://github.com/YOUR_USERNAME/uservin/workflows/PR%20Checks/badge.svg)
![Auto Build](https://github.com/YOUR_USERNAME/uservin/workflows/Auto%20Build/badge.svg)
```
