# GitHub Actions Workflows

Enterprise-grade CI/CD pipeline for the uservin project.

## Architecture

```
.github/
├── actions/
│   └── shellcheck/        # Reusable composite action
│       └── action.yml
└── workflows/
    ├── pr-checks.yml      # PR validation gate
    ├── auto-build.yml     # Auto-rebuild on merge
    ├── release.yml        # Signed release pipeline
    ├── scheduled.yml      # Weekly cross-version tests
    └── build-openssh.yml  # Manual OpenSSH .deb builder
```

## Workflows

### 1. PR Checks (`pr-checks.yml`)
**Triggers:** Pull requests to `main`/`master`

**Jobs:**
| Job | Purpose | Runner |
|---|---|---|
| `lint` | ShellCheck on all scripts | ubuntu-latest |
| `test` | Test suite across Ubuntu 20.04/22.04/24.04 | Container matrix |
| `build` | Build + syntax/consistency verification | ubuntu-latest |
| `status-check` | Aggregated pass/fail gate | ubuntu-latest |

**Features:** Concurrency cancellation, path filtering, timeout limits, version consistency check

### 2. Auto Build (`auto-build.yml`)
**Triggers:** Push to `main`/`master` when library sources change

**Jobs:**
| Job | Purpose |
|---|---|
| `verify` | Build + lint gate before committing |
| `commit` | Rebuild and auto-commit `uservin.sh` with checksums |

**Features:** Two-stage pipeline (verify then commit), checksum generation, GitHub App token support

### 3. Release (`release.yml`)
**Triggers:** Push of version tags (`v*`)

**Jobs:**
| Job | Purpose |
|---|---|
| `verify` | Tag format validation + version consistency |
| `build` | Build bundle + generate checksums |
| `sign` | Cosign (Sigstore) artifact signing |
| `release` | GitHub Release with changelog + signed artifacts |

**Features:** Artifact signing (cosign/sigstore), auto-generated changelog, prerelease detection, SBOM checksums (SHA-256/SHA-512)

### 4. Scheduled Tests (`scheduled.yml`)
**Triggers:** Weekly (Mondays 06:00 UTC) + manual dispatch

**Jobs:**
| Job | Purpose |
|---|---|
| `test` | Cross-version Ubuntu testing (20.04/22.04/24.04/24.10) |
| `lint` | ShellCheck validation |
| `notify` | Auto-create GitHub issues on failure |

**Features:** Failure notification via auto-created issues, Ubuntu 24.10 added to matrix

### 5. Build OpenSSH .deb (`build-openssh.yml`)
**Triggers:** Manual dispatch only

**Jobs:**
| Job | Purpose |
|---|---|
| `validate` | Input validation + SHA-256 verification config |
| `build` | Compile + package + generate SBOM |
| `sign` | Cosign (Sigstore) package signing |
| `release` | Optional GitHub Release publish |

**Features:** CycloneDX SBOM, cosign artifact signing, SHA-256/512 checksums, optional release toggle, job summary reports

## Composite Actions

### ShellCheck (`.github/actions/shellcheck/`)
Reusable ShellCheck action with configurable severity and error handling. Auto-discovers all `.sh` files in `lib/`, `tests/`, and root.

**Inputs:**
| Input | Default | Description |
|---|---|---|
| `severity` | `warning` | Minimum severity threshold |
| `fail-on-errors` | `true` | Fail workflow on errors |

## Setup

### Required Secrets
| Secret | Used By | Description |
|---|---|---|
| `GITHUB_TOKEN` | All workflows | Auto-provided by GitHub |
| `BOT_APP_ID` | auto-build | GitHub App ID for signed commits (optional) |
| `BOT_PRIVATE_KEY` | auto-build | GitHub App private key (optional) |

### Optional: GitHub App for Auto Build
For bot-authored commits with proper verification, create a GitHub App with `contents: write` permission and configure `BOT_APP_ID` and `BOT_PRIVATE_KEY` as repository secrets. If not configured, the default `GITHUB_TOKEN` is used as fallback.

### Labels
Create these labels for automated issue management:
- `ci-failure` - For scheduled test failure notifications
- `automated` - For auto-created issues

## Badges

```markdown
![PR Checks](https://github.com/YOUR_USERNAME/uservin/workflows/PR%20Checks/badge.svg)
![Auto Build](https://github.com/YOUR_USERNAME/uservin/workflows/Auto%20Build/badge.svg)
![Release](https://github.com/YOUR_USERNAME/uservin/workflows/Release/badge.svg)
![Scheduled Tests](https://github.com/YOUR_USERNAME/uservin/workflows/Scheduled%20Tests/badge.svg)
```
