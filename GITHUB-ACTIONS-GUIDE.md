# GitHub Actions — A Complete Engineering Reference

**Stack:** GitHub Actions · AWS EC2 · Node.js · PostgreSQL · Nginx · PM2  
**Audience:** Intermediate to advanced software developers and DevOps engineers

---

## Table of Contents

1. [What is GitHub Actions?](#1-what-is-github-actions)
2. [Why We Use GitHub Actions](#2-why-we-use-github-actions)
3. [Key Features and Facilities](#3-key-features-and-facilities)
4. [How GitHub Actions Makes Engineering Life Easier](#4-how-github-actions-makes-engineering-life-easier)
5. [Pros and Advantages](#5-pros-and-advantages)
6. [Cons and Limitations](#6-cons-and-limitations)
7. [CI and CD Explained](#7-ci-and-cd-explained)
8. [How CI/CD Applies to GitHub Actions](#8-how-cicd-applies-to-github-actions)
9. [What This Workspace Represents](#9-what-this-workspace-represents)
10. [Production Workflow Example](#10-production-workflow-example)
11. [Best Practices](#11-best-practices)
12. [Conclusion](#12-conclusion)

---

## 1. What is GitHub Actions?

GitHub Actions is a **native CI/CD and workflow automation platform** built directly into GitHub. It enables teams to automate any software engineering process — from running tests on every pull request to deploying applications to production — using YAML-defined workflow files stored inside the repository itself.

### Definition

A GitHub Actions **workflow** is a YAML file placed in `.github/workflows/`. It defines:

- **When** to run (the trigger event)
- **What** to run (the jobs and steps)
- **Where** to run it (the runner environment)

```
.github/
  workflows/
    deploy.yml     ← triggered on push to main
    rollback.yml   ← triggered manually
```

### Core Purpose

GitHub Actions sits at the intersection of source control and automation. Its core purpose is to eliminate the gap between writing code and that code being tested, validated, and delivered — by automating every step of that journey without requiring a separate CI/CD server.

### How It Fits Into Modern DevOps

In a modern engineering organization, code has to travel through a defined pipeline before reaching users:

```
Code Commit → Review → Build → Test → Security Scan → Deploy → Monitor
```

Every step in that pipeline is a candidate for automation. GitHub Actions provides the mechanism to define, version-control, and execute that automation directly alongside application code — no external system to configure, no plugin ecosystem to manage, no webhook setup between separate tools.

---

## 2. Why We Use GitHub Actions

### Problems It Solves

**Manual deployments are a risk.** When humans run deployment commands, they introduce inconsistency, skip steps under pressure, and create incidents. GitHub Actions replaces human-executed runbooks with repeatable, auditable automated pipelines.

**Context switching kills velocity.** Developers switching between their editor, a Jenkins dashboard, a deployment script, and a Slack channel to release software introduces friction. GitHub Actions keeps the entire workflow in one place — the repository.

**Onboarding takes too long.** Without standardized automation, new engineers spend weeks learning "how we deploy here." When the process lives in `.github/workflows/`, onboarding is reading a YAML file.

**Testing is inconsistently applied.** Without automated triggers, tests are optional. With GitHub Actions, tests run on every push and every pull request — there is no path to merge that bypasses them.

### Why Teams Adopt It

- Zero infrastructure to provision to get started (GitHub-hosted runners are free for public repos)
- Workflow-as-code means pipelines are versioned, reviewed, and auditable like application code
- Native integration with GitHub pull requests, branch protection rules, and deployment environments
- The Actions Marketplace provides thousands of pre-built integrations for common tools

### Common Industry Use Cases

| Use Case | Trigger | Example |
|---|---|---|
| Run tests on PR | `pull_request` | Jest, pytest, Go test |
| Deploy to staging | `push` to `develop` | Deploy to staging server |
| Deploy to production | `push` to `main` | Deploy to AWS EC2 |
| Publish npm package | `release` created | `npm publish` |
| Scheduled security scan | `schedule` (cron) | Trivy, Snyk, OWASP |
| Notify on failure | `workflow_run` | Slack, email, PagerDuty |
| Infrastructure provisioning | `workflow_dispatch` | Terraform apply |

---

## 3. Key Features and Facilities

### Workflows

A workflow is the top-level unit in GitHub Actions. It is a YAML file in `.github/workflows/` that defines everything GitHub needs to execute automation. A repository can have multiple workflows for different purposes.

```yaml
name: CI Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]
```

### Events

Events are the triggers that cause a workflow to run. GitHub supports over 35 event types.

| Event | When it fires |
|---|---|
| `push` | Code is pushed to a branch or tag |
| `pull_request` | PR is opened, synchronized, or reopened |
| `release` | A GitHub release is published |
| `schedule` | Cron-based schedule (e.g. nightly builds) |
| `workflow_dispatch` | Manual trigger from the Actions UI or API |
| `workflow_run` | After another workflow completes |
| `repository_dispatch` | External webhook payload |

```yaml
on:
  schedule:
    - cron: '0 2 * * 1'  # Every Monday at 02:00 UTC
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        default: 'staging'
```

### Jobs

Jobs are isolated units of execution within a workflow. By default, all jobs in a workflow run in parallel. Dependencies between jobs are declared with `needs`.

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps: [...]

  build:
    needs: test          # runs only if test passes
    runs-on: ubuntu-latest
    steps: [...]

  deploy:
    needs: [test, build] # runs only if both pass
    runs-on: ubuntu-latest
    steps: [...]
```

### Steps

Steps are the individual commands or action invocations within a job. They run sequentially. Each step either runs a shell command (`run:`) or invokes a pre-built action (`uses:`).

```yaml
steps:
  - name: Checkout repository
    uses: actions/checkout@v4

  - name: Install dependencies
    run: npm ci

  - name: Run tests
    run: npm test

  - name: Upload test results
    uses: actions/upload-artifact@v4
    with:
      name: test-results
      path: coverage/
```

### Runners

**GitHub-hosted runners** are ephemeral virtual machines provisioned and managed by GitHub. They are clean on every run, pre-installed with common tools, and available in three operating systems:

| OS | Label | Notes |
|---|---|---|
| Ubuntu 24.04 | `ubuntu-latest` | Most common for CI |
| Windows Server | `windows-latest` | .NET, PowerShell workflows |
| macOS | `macos-latest` | iOS/macOS builds |

**Self-hosted runners** are machines you manage. They can be EC2 instances, on-premise servers, Raspberry Pis, or any Linux/macOS/Windows machine. Self-hosted runners are ideal when:

- You need access to internal networks or resources
- You need persistent state between runs (installed dependencies, Docker layer cache)
- You need specific hardware (GPU, ARM, large memory)
- You want to avoid GitHub-hosted runner minute quotas

```yaml
jobs:
  deploy:
    runs-on: [self-hosted, linux, x64]
```

### Actions Marketplace

The Actions Marketplace (`https://github.com/marketplace?type=actions`) contains over 20,000 reusable community and vendor-built actions. Common examples:

```yaml
- uses: actions/checkout@v4                        # Clone the repo
- uses: actions/setup-node@v4                      # Install Node.js
- uses: docker/build-push-action@v5                # Build and push Docker image
- uses: aws-actions/configure-aws-credentials@v4   # Configure AWS CLI
- uses: hashicorp/setup-terraform@v3               # Install Terraform
```

### Secrets and Environment Variables

Secrets are encrypted at rest and injected into workflows at runtime. They never appear in logs.

```yaml
# Referenced in workflow
env:
  DATABASE_URL: ${{ secrets.DATABASE_URL }}

steps:
  - name: Deploy
    env:
      SSH_KEY: ${{ secrets.EC2_SSH_KEY }}
    run: |
      echo "$SSH_KEY" > ~/.ssh/id_rsa
      chmod 600 ~/.ssh/id_rsa
```

Secrets can be scoped at three levels:
- **Repository** — available to all workflows in the repo
- **Environment** — only available when a job targets that environment
- **Organization** — shared across multiple repositories

### Matrix Builds

Matrix builds run a single job definition across multiple combinations of variables simultaneously:

```yaml
strategy:
  matrix:
    node-version: [18, 20, 22]
    os: [ubuntu-latest, windows-latest]

runs-on: ${{ matrix.os }}
steps:
  - uses: actions/setup-node@v4
    with:
      node-version: ${{ matrix.node-version }}
  - run: npm test
```

This generates 6 parallel jobs (3 Node versions × 2 operating systems) from a single job definition.

### Reusable Workflows

Workflows can call other workflows, enabling DRY (Don't Repeat Yourself) pipeline design across repositories:

```yaml
# In the consuming workflow:
jobs:
  deploy:
    uses: my-org/.github/.github/workflows/deploy-template.yml@main
    with:
      environment: production
    secrets: inherit
```

### Artifacts and Caching

**Artifacts** persist files between jobs or after a workflow completes:

```yaml
- uses: actions/upload-artifact@v4
  with:
    name: build-output
    path: dist/

# In a later job:
- uses: actions/download-artifact@v4
  with:
    name: build-output
```

**Caching** speeds up workflows by persisting and restoring dependency directories:

```yaml
- uses: actions/cache@v4
  with:
    path: ~/.npm
    key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
    restore-keys: |
      ${{ runner.os }}-node-
```

### Deployment Environments

Environments allow you to define deployment targets with protection rules:

```yaml
jobs:
  deploy-production:
    environment:
      name: production
      url: https://bmi.ostaddevops.click
    runs-on: ubuntu-latest
```

Environment-level features:
- Required reviewers (manual approval gate before deployment proceeds)
- Environment-specific secrets (production DB URL never available in non-production jobs)
- Deployment history per environment
- Branch restrictions (only `main` can deploy to production)

---

## 4. How GitHub Actions Makes Engineering Life Easier

### Automation of Repetitive Tasks

Every task that a developer or operator runs manually more than once is a candidate for automation. GitHub Actions handles:

- Linting and formatting checks on every commit
- Running the test suite on every pull request
- Building and tagging Docker images on every merge
- Deploying to staging when a feature branch is merged
- Deploying to production when `main` is updated
- Rotating credentials on a schedule
- Generating and publishing release notes

### Faster Feedback Loops

Without automation, a developer might push code and not know it broke until it reaches staging — hours later. With GitHub Actions, the test suite runs within seconds of the push. A red check on the pull request tells the developer immediately, before the code is even reviewed.

### Improved Code Quality

When tests and linting are optional (run manually), they are inconsistently applied. When they are enforced by automation on every pull request, they become unavoidable. GitHub branch protection rules can require a passing workflow before a PR can be merged.

### Reduced Manual Deployment Effort

A manual deployment process involves: SSH access, running commands in order, checking logs, verifying the application is healthy. GitHub Actions automates the entire sequence, including health checks and automatic rollback if the deployment fails — as demonstrated in this workspace.

### Better Team Collaboration

Pull request workflows make quality gates visible to every reviewer. When a CI check is red, the PR cannot merge. The team sees the same signal simultaneously. There are no manual steps hidden in someone's local environment.

### Standardized Engineering Processes

When pipelines are defined in YAML in the repository, they become part of the codebase:
- Changes to the pipeline go through code review
- The pipeline has history — `git log .github/workflows/`
- Any engineer can understand the full deployment process without asking anyone

---

## 5. Pros and Advantages

**Native GitHub integration** — No webhook configuration, no OAuth token setup, no external service accounts. The pipeline is first-class inside GitHub. Status checks, PR annotations, deployment tracking, and environment protection rules are all built in.

**Strong ecosystem** — 20,000+ marketplace actions mean most integrations (Docker Hub, AWS, Slack, Terraform, npm, PyPI) are one `uses:` line. The community maintains them and GitHub certifies verified creators.

**Easy onboarding** — A new engineer who knows YAML and has a GitHub account can write a functional workflow in an hour. There is no server to administer, no plugin manager, no agent installation required for GitHub-hosted runners.

**Scalability** — GitHub-hosted runners scale automatically. There is no queue management when 20 developers push simultaneously. Self-hosted runner groups allow organizations to scale their own infrastructure.

**Infrastructure automation** — GitHub Actions is not limited to application code. It runs Terraform, Ansible, AWS CDK, `kubectl`, and any other infrastructure tool. The same workflow triggers both application deployment and infrastructure changes.

**Audit trail** — Every workflow run is logged with the triggering commit, the actor, every step's output, and the outcome. This audit trail satisfies compliance requirements for regulated industries.

---

## 6. Cons and Limitations

### Pricing Considerations

GitHub-hosted runners are billed per minute. Free tiers apply to public repositories and limited private repository minutes. For private repositories on large teams, CI costs can be significant. Self-hosted runners eliminate minute-based billing but introduce infrastructure and maintenance overhead.

| Plan | Monthly minutes (private repos) |
|---|---|
| Free | 2,000 |
| Team | 3,000 |
| Enterprise | 50,000 |

### YAML Complexity

Simple workflows are readable. Complex workflows with conditional steps, matrix builds, reusable workflows, dynamic expressions, and context access become difficult to maintain. YAML has no type safety, no IDE debugger, and errors surface only at runtime.

```yaml
# This is valid YAML but hard to read at scale
if: |
  github.event_name == 'push' &&
  github.ref == 'refs/heads/main' &&
  !contains(github.event.head_commit.message, '[skip ci]')
```

### Debugging Challenges

There is no local runner that precisely replicates the GitHub-hosted environment. The common debugging loop is: push → wait for runner to start → see failure → fix one line → push again → wait. The `act` tool (https://github.com/nektos/act) provides local execution but does not fully match GitHub's environment.

### Vendor Lock-In

GitHub Actions YAML syntax is GitHub-specific. Migrating to GitLab CI/CD, CircleCI, or Jenkins requires rewriting all workflows. The logic is portable, but the syntax and primitives are not.

### Runtime Limitations

GitHub-hosted runners have hard limits:
- 6-hour maximum job duration
- 500 MB artifact storage per run
- 10 GB artifact storage per repository
- 256 GB SSD, 16 vCPU, 64 GB RAM (4-core, 16 GB RAM for standard)

Long-running jobs (e.g., ML training, large video processing) do not fit within these limits.

### Self-Hosted Runner Maintenance

Self-hosted runners require the team to manage OS patching, runner software updates, scaling, and availability. A runner that goes offline silently blocks all deployments. This is operational overhead that GitHub-hosted runners eliminate.

### Security Risks from Third-Party Actions

Using a community action is executing code from a third party on your runner. A compromised or malicious action can exfiltrate secrets. Mitigation requires pinning actions to a full commit SHA rather than a floating tag:

```yaml
# Vulnerable — the tag can be overwritten
- uses: some-action/tool@v2

# Safe — SHA is immutable
- uses: some-action/tool@a8b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9
```

---

## 7. CI and CD Explained

### Continuous Integration (CI)

CI is the practice of automatically integrating code changes from multiple developers into a shared repository frequently — typically multiple times per day. Each integration is verified by an automated build and test sequence that runs immediately after the push.

**Core principle:** catch integration problems early, when they are cheap to fix.

A CI pipeline typically includes:
1. Code checkout
2. Dependency installation
3. Linting / static analysis
4. Unit tests
5. Integration tests
6. Code coverage reporting
7. Build artifact creation

### Continuous Delivery (CD)

CD extends CI by ensuring the software can be released to production at any time. Every change that passes CI is automatically deployed to a staging environment and is ready — but not necessarily automatically released — to production.

**Core principle:** always have a production-ready artifact.

### Continuous Deployment

Continuous Deployment goes one step further: every change that passes all automated tests is automatically deployed to production without human approval.

| Practice | Automation level | Human gate |
|---|---|---|
| CI | Build + Test | Code review (PR) |
| Continuous Delivery | Build + Test + Deploy to staging | Manual production release |
| Continuous Deployment | Build + Test + Deploy to production | None |

### Why They Matter

Without CI/CD:
- Integration problems accumulate over weeks
- Deployments are rare, large, and risky
- The time between writing code and users seeing it is measured in weeks or months

With CI/CD:
- Integration problems are caught within minutes
- Deployments are frequent, small, and low-risk
- The time between writing code and users seeing it can be measured in minutes

---

## 8. How CI/CD Applies to GitHub Actions

### How GitHub Actions Implements CI

Every `push` or `pull_request` event triggers the test workflow. Steps run in a clean environment. Results are reported back as commit status checks visible on the pull request.

```yaml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: npm test
      - run: npm run lint
```

### How GitHub Actions Implements CD

On merge to `main`, the deploy workflow triggers. It builds the application, runs a final smoke test, and deploys to the production environment. If the health check fails, an auto-rollback step restores the previous commit.

```yaml
name: CD

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: [self-hosted, linux, x64]
    environment:
      name: production
      url: https://example.com
    steps:
      - uses: actions/checkout@v4
      - name: Deploy
        run: ./deploy.sh
      - name: Health check
        run: curl -sf https://example.com/health
```

### Real-World Pipeline

```
Developer → git push → GitHub
  │
  ├── CI: run tests (ubuntu-latest, ~2 min)
  │     Passes → PR gets green check
  │     Fails  → PR blocked, developer notified
  │
  └── CD (merge to main):
        ├── setup-runner → SSH to EC2 → start self-hosted runner
        └── deploy (self-hosted runner on EC2)
              ├── npm install (backend)
              ├── Vite build (frontend)
              ├── PM2 reload (zero-downtime)
              ├── Nginx reload
              ├── Health check → curl /health
              └── Auto-rollback if health check fails
```

---

## 9. What This Workspace Represents

This repository is a **production-grade three-tier web application** with a fully automated CI/CD pipeline. It demonstrates a complete end-to-end DevOps implementation on AWS.

### Application Stack

| Layer | Technology | Purpose |
|---|---|---|
| Frontend | React 18 + Vite 5 | Single-page application served as static files |
| Backend | Node.js 20 + Express 4 | REST API, business logic |
| Database | PostgreSQL 16 | Persistent data storage |
| Process Manager | PM2 | Zero-downtime reload, cluster mode, systemd integration |
| Web Server | Nginx 1.24 | Reverse proxy, SSL termination, static file serving |
| SSL | Let's Encrypt (Certbot) | Automated TLS certificate issuance and renewal |
| Firewall | UFW | Allow SSH, HTTP, HTTPS; deny everything else |

### Infrastructure

| Component | Technology | Notes |
|---|---|---|
| Cloud Provider | AWS | EC2 instance (Ubuntu 24.04 LTS) |
| DNS | Route 53 / external | `bmi.ostaddevops.click` |
| Web Root | `/var/www/html/bmi-health-tracker` | `www-data` owned, no chmod hacks |
| Static Files | Vite production build | Served directly by Nginx |

### CI/CD Pipeline

The `.github/workflows/` directory contains two workflows:

**`deploy.yml`** — triggered on every `push` to `main`:

```
Job 1: setup-runner (GitHub-hosted ubuntu-latest)
  ├── Validate secrets
  ├── Configure SSH
  ├── Test SSH connectivity
  ├── Get runner registration token (GH_PAT)
  └── SSH to EC2 → run setup-runner.sh (idempotent)

Job 2: deploy (self-hosted runner on EC2)
  ├── Record pre-deploy commit SHA (rollback target)
  ├── Checkout (clean: false → preserves .env)
  ├── Detect mode: FRESH INSTALL or RE-DEPLOY
  ├── 1/8 System packages (fresh only)
  ├── 2/8 Node.js 20 + PM2 (fresh only)
  ├── 3/8 PostgreSQL install + provision + migrations (always)
  ├── 4/8 Backend: npm install, .env, ecosystem.config.js, PM2 start/reload
  ├── 5/8 Frontend: Vite build → copy to /var/www
  ├── 6/8 Nginx: config write (fresh) or reload (re-deploy)
  ├── 7/8 UFW: allow SSH + Nginx Full (fresh only)
  ├── 8/8 Certbot: issue cert (if not valid) + enable renewal timer
  ├── Smoke test: curl --resolve (hairpin NAT bypass)
  └── Auto-rollback: git checkout <pre-sha> → rebuild → re-verify
```

**`rollback.yml`** — manually triggered from GitHub UI:

```
Input: commit_sha (optional, defaults to HEAD~1)
  ├── Resolve target SHA
  ├── Read DB credentials from existing .env
  ├── Checkout target commit
  ├── Restore backend (npm install + PM2 reload)
  ├── Restore frontend (Vite build + copy to /var/www)
  ├── Reload Nginx
  └── Health check
```

### Key Design Decisions

**Self-hosted runner on the same EC2 instance:** The runner has direct access to the application files, PM2, Nginx, and PostgreSQL without any SSH jumping from the runner to a separate deployment target. This is the correct pattern for a single-server deployment.

**`clean: false` on checkout:** Preserves the gitignored `backend/.env` file across runs. If checkout cleaned the workspace, the deploy script would see no `.env` and run a full fresh install on every push, generating a new random database password and breaking the live database connection.

**`--resolve` in health check curl:** AWS EC2 instances cannot connect to their own public IP (no hairpin NAT). The `--resolve ${DOMAIN}:443:127.0.0.1` flag forces the health check curl to connect via loopback, bypassing the NAT issue.

**Frontend served from `/var/www`:** Ubuntu 24.04 home directories are permission `750`. Nginx running as `www-data` cannot read files in `/home/ubuntu`. Serving from `/var/www/html/bmi-health-tracker` (owned by `www-data`) eliminates all permission issues permanently.

**Idempotent deployments:** The deploy script detects whether `backend/.env` exists to determine fresh install vs re-deploy. Infrastructure steps (apt, Node.js, PostgreSQL provisioning, Nginx config, UFW, Certbot) are skipped on re-deploy. Only the application layer is rebuilt, making re-deployments fast.

---

## 10. Production Workflow Example

Below is a simplified but production-representative workflow combining CI (test) and CD (deploy) for a Node.js + React application deployed to AWS EC2 with a self-hosted runner:

```yaml
# .github/workflows/deploy.yml
name: Deploy to Production

on:
  push:
    branches: [main]

permissions:
  contents: read

concurrency:
  group: production-deploy
  cancel-in-progress: false

env:
  NODE_VERSION: '20'
  SERVE_DIR: /var/www/html/my-app

jobs:

  # ── Job 1: CI — runs on GitHub cloud ──────────────────────────────────────
  test:
    name: Run tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: npm
          cache-dependency-path: backend/package-lock.json

      - name: Install dependencies
        run: npm ci --prefix backend

      - name: Run unit tests
        run: npm test --prefix backend

      - name: Run linter
        run: npm run lint --prefix backend

  # ── Job 2: Setup self-hosted runner on EC2 ────────────────────────────────
  setup-runner:
    name: Setup runner on EC2
    runs-on: ubuntu-latest
    needs: test   # only proceed if tests pass
    env:
      FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true
    steps:
      - uses: actions/checkout@v4

      - name: Configure SSH
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.EC2_SSH_KEY }}" > ~/.ssh/ec2.pem
          chmod 600 ~/.ssh/ec2.pem
          ssh-keyscan -H "${{ secrets.EC2_HOST }}" >> ~/.ssh/known_hosts 2>/dev/null || true

      - name: Get runner registration token
        id: reg-token
        run: |
          TOKEN=$(curl -sf -X POST \
            -H "Authorization: Bearer ${{ secrets.GH_PAT }}" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/repos/${{ github.repository }}/actions/runners/registration-token" \
            | jq -r '.token // empty')
          echo "::add-mask::${TOKEN}"
          echo "token=${TOKEN}" >> "$GITHUB_OUTPUT"

      - name: Install and start runner (idempotent)
        run: |
          ssh -i ~/.ssh/ec2.pem -o StrictHostKeyChecking=no \
            ubuntu@${{ secrets.EC2_HOST }} \
            "REPO='${{ github.repository }}' REG_TOKEN='${{ steps.reg-token.outputs.token }}' bash -s" \
            < .github/scripts/setup-runner.sh

      - name: Cleanup
        if: always()
        run: rm -f ~/.ssh/ec2.pem

  # ── Job 3: Deploy — runs on the self-hosted runner on EC2 ─────────────────
  deploy:
    name: Deploy to EC2
    needs: setup-runner
    runs-on: [self-hosted, linux, x64]
    environment:
      name: production
      url: https://${{ secrets.DEPLOY_DOMAIN }}

    env:
      DOMAIN: ${{ secrets.DEPLOY_DOMAIN }}

    steps:
      - name: Record pre-deploy SHA (rollback target)
        id: pre
        run: |
          SHA=$(git rev-parse HEAD 2>/dev/null || echo "")
          echo "sha=${SHA}" >> "$GITHUB_OUTPUT"

      - name: Checkout
        uses: actions/checkout@v4
        with:
          clean: false  # preserve backend/.env

      - name: Install backend dependencies
        run: npm ci --prefix "$GITHUB_WORKSPACE/backend" --omit=dev

      - name: Build frontend
        run: |
          cd "$GITHUB_WORKSPACE/frontend"
          npm ci
          npm run build

      - name: Deploy frontend to web root
        run: |
          sudo rm -rf "${SERVE_DIR:?}/"*
          sudo cp -a "$GITHUB_WORKSPACE/frontend/dist/." "${SERVE_DIR}/"
          sudo chown -R www-data:www-data "${SERVE_DIR}"

      - name: Reload application
        run: |
          pm2 reload "$GITHUB_WORKSPACE/backend/ecosystem.config.js" --update-env
          sudo nginx -t && sudo systemctl reload-or-restart nginx

      - name: Health check
        run: |
          sleep 3
          STATUS=$(curl -sk --resolve "${DOMAIN}:443:127.0.0.1" \
            --max-time 15 -o /dev/null -w "%{http_code}" \
            "https://${DOMAIN}/health" || true)
          echo "Health check: HTTP ${STATUS}"
          [[ "$STATUS" == "200" ]] || { echo "::error::Health check failed"; exit 1; }

      - name: Auto-rollback on failure
        if: failure() && steps.pre.outputs.sha != ''
        run: |
          git checkout "${{ steps.pre.outputs.sha }}"
          # Rebuild and reload at previous commit
          npm ci --prefix "$GITHUB_WORKSPACE/backend" --omit=dev
          cd "$GITHUB_WORKSPACE/frontend" && npm ci && npm run build
          sudo rm -rf "${SERVE_DIR:?}/"*
          sudo cp -a "$GITHUB_WORKSPACE/frontend/dist/." "${SERVE_DIR}/"
          sudo chown -R www-data:www-data "${SERVE_DIR}"
          pm2 reload "$GITHUB_WORKSPACE/backend/ecosystem.config.js" --update-env
          sudo systemctl reload-or-restart nginx
          echo "::notice::Rolled back to ${{ steps.pre.outputs.sha }}"

      - name: Summary
        if: success()
        run: |
          COMMIT=$(git rev-parse --short HEAD)
          echo "### Deploy successful — \`${COMMIT}\`" >> "$GITHUB_STEP_SUMMARY"
          echo "URL: https://${DOMAIN}" >> "$GITHUB_STEP_SUMMARY"
```

---

## 11. Best Practices

### Pin Action Versions to Full Commit SHAs

Floating tags (`@v4`) can be overwritten by the action author or a compromised account. For production workflows, pin to an immutable SHA:

```yaml
# Floating tag — can change at any time
- uses: actions/checkout@v4

# Pinned SHA — immutable
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
```

### Use Least Privilege on GITHUB_TOKEN

Grant only the permissions the workflow actually needs:

```yaml
permissions:
  contents: read      # checkout
  packages: write     # push to GitHub Container Registry
  # everything else defaults to none
```

### Never Use `pull_request_target` with Untrusted Code

`pull_request_target` runs in the context of the base branch with full secrets access. Using it with code from a fork allows a malicious PR to access production secrets. Use `pull_request` for code from forks.

### Cache Dependencies

Always cache dependency managers to reduce build time:

```yaml
- uses: actions/cache@v4
  with:
    path: |
      ~/.npm
      ${{ github.workspace }}/frontend/node_modules
    key: ${{ runner.os }}-npm-${{ hashFiles('**/package-lock.json') }}
```

### Use Environment Protection Rules for Production

Configure the `production` environment with:
- Required reviewers (1–2 engineers must approve)
- Wait timer (minimum 5 minutes after merge before deployment)
- Branch restriction (`main` only)

### Fail Fast — Validate Secrets Early

Check for required secrets at the beginning of the job rather than failing deep into a deployment:

```yaml
- name: Validate required secrets
  run: |
    MISSING=""
    [[ -z "${{ secrets.EC2_HOST }}"    ]] && MISSING="${MISSING} EC2_HOST"
    [[ -z "${{ secrets.EC2_SSH_KEY }}" ]] && MISSING="${MISSING} EC2_SSH_KEY"
    [[ -n "$MISSING" ]] && { echo "Missing:${MISSING}"; exit 1; }
```

### Use Concurrency Groups to Prevent Overlapping Deployments

```yaml
concurrency:
  group: production-deploy
  cancel-in-progress: false  # queue, never cancel a running deploy
```

### Add `if: always()` to Cleanup Steps

Critical cleanup steps (removing SSH keys, removing temporary credentials) must run even if earlier steps fail:

```yaml
- name: Cleanup SSH key
  if: always()
  run: rm -f ~/.ssh/ec2.pem
```

### Separate CI and CD Workflows

Keep CI (test, lint, build) in one file and CD (deploy) in another. This makes it possible to run CI on every branch and PR while keeping production deployments restricted to `main`.

### Use Job Summaries for Visibility

Write deployment summaries to `$GITHUB_STEP_SUMMARY` so engineers see key information without opening individual logs:

```yaml
- run: |
    echo "### Deploy: \`$(git rev-parse --short HEAD)\`" >> "$GITHUB_STEP_SUMMARY"
    echo "- Environment: production" >> "$GITHUB_STEP_SUMMARY"
    echo "- URL: https://${DOMAIN}" >> "$GITHUB_STEP_SUMMARY"
```

---

## 12. Conclusion

### Why GitHub Actions Is Important for Modern DevOps Teams

GitHub Actions reduces the operational distance between writing code and delivering value to users. By automating the integration, testing, building, and deployment pipeline — and by keeping that automation in the same repository as the application code — it eliminates the class of failures that come from inconsistent manual processes.

For teams already using GitHub as their source control system, GitHub Actions is the lowest-friction path to a mature CI/CD practice. There is no separate infrastructure to provision, no third-party account to manage, and no context switch required.

For organizations, GitHub Actions provides an auditable, reviewable, versioned record of every deployment decision. The pipeline is not owned by one engineer; it is owned by the team, reviewed by the team, and improved through the same pull request process as the application itself.

### When to Use GitHub Actions vs Alternatives

| Criteria | GitHub Actions | Jenkins | GitLab CI/CD | CircleCI |
|---|---|---|---|---|
| Source control | GitHub | Any | GitLab | Any |
| Infrastructure required | None (hosted) | Yes (server) | None (hosted) | None (hosted) |
| Self-hosted runners | Yes | Yes | Yes | Yes |
| YAML complexity | Medium | High (Groovy) | Medium | Medium |
| Marketplace ecosystem | Excellent | Good (plugins) | Good | Good |
| Enterprise control | Good | Excellent | Excellent | Good |
| Cost (private repos) | Metered minutes | Infrastructure cost | Metered minutes | Metered minutes |
| Vendor lock-in | Medium | Low | Medium | Medium |

**Choose GitHub Actions** when your source control is GitHub, you want zero infrastructure overhead to get started, and you benefit from tight GitHub integration (PR checks, deployment environments, branch protection).

**Choose Jenkins** when you need maximum flexibility, full control over your pipeline infrastructure, or have complex enterprise requirements that GitHub Actions cannot accommodate.

**Choose GitLab CI/CD** when your team is fully on GitLab or you require the tighter GitLab-native security scanning, dependency scanning, and compliance features.

**Choose CircleCI** when you need the most performance optimization options for large monorepos with complex pipeline graphs.

For most teams shipping web applications on GitHub, GitHub Actions is the right default — it is well-documented, has a strong community, integrates deeply with the platform you are already using, and can be adopted incrementally starting with a single two-step workflow on day one.

---

*This document reflects the architecture implemented in the `github-actions-ci-cd` workspace: a three-tier Node.js + React + PostgreSQL application deployed to AWS EC2 Ubuntu 24.04 via a self-hosted GitHub Actions runner, with automated SSL, zero-downtime PM2 reloads, and automatic rollback on health check failure.*

---

## Author

**MD Sarowar Alam**  
Lead DevOps Engineer, WPP Production  
📧 Email: [sarowar@hotmail.com](mailto:sarowar@hotmail.com)  
🔗 LinkedIn: https://www.linkedin.com/in/sarowar/
