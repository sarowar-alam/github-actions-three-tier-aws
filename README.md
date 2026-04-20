# BMI Health Tracker ||| Test Deployment || 2nd 

A production-ready, three-tier web application for tracking BMI, BMR, and daily calorie requirements over time. The full deployment lifecycle — from code commit to live production — is automated via GitHub Actions with a self-hosted runner on AWS EC2.

**Live URL:** `https://bmi.ostaddevops.click`  
**Health endpoint:** `https://bmi.ostaddevops.click/health`

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Architecture Overview](#2-architecture-overview)
3. [Tech Stack](#3-tech-stack)
4. [Folder Structure](#4-folder-structure)
5. [Application Workflow](#5-application-workflow)
6. [CI/CD Pipeline Overview](#6-cicd-pipeline-overview)
7. [GitHub Actions Workflow Explanation](#7-github-actions-workflow-explanation)
8. [Self-Hosted Runner Setup](#8-self-hosted-runner-setup)
9. [Deployment Process](#9-deployment-process)
10. [Environment Variables](#10-environment-variables)
11. [Prerequisites](#11-prerequisites)
12. [Local Development Setup](#12-local-development-setup)
13. [Build and Run Instructions](#13-build-and-run-instructions)
14. [Testing Instructions](#14-testing-instructions)
15. [Production Deployment Steps](#15-production-deployment-steps)
16. [Monitoring and Logging](#16-monitoring-and-logging)
17. [Security Practices](#17-security-practices)
18. [Troubleshooting](#18-troubleshooting)
19. [Future Improvements](#19-future-improvements)
20. [Contributing](#20-contributing)
21. [License](#21-license)

---

## 1. Project Overview

BMI Health Tracker is a single-user health dashboard that allows users to:

- Set a persistent profile (height, age, sex, activity level)
- Log daily weight measurements
- Automatically compute BMI, BMR, and daily calorie targets on every measurement
- Visualise 30-day BMI and weight trends via an interactive chart

All computation (BMI, BMR via the Mifflin–St Jeor equation, and calorie targets) is performed server-side on each submission. Measurements are persisted in PostgreSQL and returned in reverse-chronological order.

---

## 2. Architecture Overview

The application follows a classic **three-tier architecture**:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              CLIENT (Browser)                               │
│                     React 18 SPA  ·  Vite build output                      │
└───────────────────────────────────┬─────────────────────────────────────────┘
                                    │ HTTPS :443
┌───────────────────────────────────▼─────────────────────────────────────────┐
│                         PRESENTATION LAYER — Nginx                          │
│  Static file serving  ·  SSL termination (Let's Encrypt)  ·  Gzip           │
│  Reverse proxy:  /api/* → 127.0.0.1:3000  ·  /health → 127.0.0.1:3000       │
│  SPA routing:  try_files $uri $uri/ /index.html                             │
└───────────────────────────────────┬─────────────────────────────────────────┘
                                    │ HTTP :3000 (internal only)
┌───────────────────────────────────▼─────────────────────────────────────────┐
│                          APPLICATION LAYER — Express                        │
│  Node.js 20 · Express 4.18 · PM2 (process management + systemd)             │
│  REST API  ·  BMI/BMR calculations  ·  Input validation  ·  CORS            │
└───────────────────────────────────┬─────────────────────────────────────────┘
                                    │ TCP :5432 (localhost)
┌───────────────────────────────────▼─────────────────────────────────────────┐
│                            DATA LAYER — PostgreSQL                          │
│  PostgreSQL 16  ·  Connection pool (pg)  ·  SQL migrations                  │
│  Tables: measurements, user_profile                                         │
└─────────────────────────────────────────────────────────────────────────────┘
```

All three tiers run on a single AWS EC2 instance (Ubuntu 24.04 LTS). Nginx is the sole publicly-exposed process; the Express API and PostgreSQL are only reachable via localhost.

---

## 3. Tech Stack

### Frontend

| Technology | Version | Purpose |
|---|---|---|
| React | 18.2 | UI component framework |
| Vite | 5.0 | Build tool and development server |
| Axios | 1.4 | HTTP client for API calls |
| Chart.js | 4.4 | Trend chart rendering |
| react-chartjs-2 | 5.2 | React wrapper for Chart.js |

### Backend

| Technology | Version | Purpose |
|---|---|---|
| Node.js | 20 LTS | JavaScript runtime |
| Express | 4.18 | HTTP server and router |
| pg | 8.10 | PostgreSQL client (connection pool) |
| dotenv | 16.0 | Environment variable loading |
| cors | 2.8 | CORS policy middleware |
| body-parser | 1.20 | JSON request body parsing |
| nodemon | 3.0 | Dev auto-restart (dev only) |

### Database

| Technology | Version | Purpose |
|---|---|---|
| PostgreSQL | 16 | Relational data store |

### Infrastructure

| Component | Technology | Notes |
|---|---|---|
| Cloud | AWS EC2 | Ubuntu 24.04 LTS, ap-south-1 region |
| Web server | Nginx 1.24 | Reverse proxy, SSL termination, static files |
| SSL | Let's Encrypt (Certbot) | Auto-issued and auto-renewed TLS certificate |
| Process manager | PM2 | Zero-downtime reload, systemd integration |
| Firewall | UFW | Allows SSH (22), HTTP (80), HTTPS (443) only |
| CI/CD | GitHub Actions | Self-hosted runner on EC2 |

---

## 4. Folder Structure

```
github-actions-ci-cd/
├── .github/
│   ├── nginx-healthtracker.conf    # Nginx server block template (sed-substituted at deploy time)
│   ├── scripts/
│   │   └── setup-runner.sh         # Idempotent self-hosted runner install script
│   └── workflows/
│       ├── deploy.yml              # Push-to-main CI/CD pipeline with auto-rollback
│       └── rollback.yml            # Manual rollback via workflow_dispatch
├── backend/
│   ├── ecosystem.config.js         # PM2 process configuration (overwritten at deploy time)
│   ├── package.json
│   ├── migrations/
│   │   ├── 001_create_measurements.sql   # Creates measurements table and indexes
│   │   ├── 002_add_measurement_date.sql  # Adds measurement_date column (idempotent)
│   │   └── 003_create_user_profile.sql   # Creates user_profile singleton table for form pre-fill
│   └── src/
│       ├── calculations.js         # BMI, BMR (Mifflin–St Jeor), calorie calculations
│       ├── db.js                   # PostgreSQL connection pool
│       ├── routes.js               # All API route handlers
│       └── server.js               # Express app bootstrap and health endpoint
├── database/
│   └── setup-database.sh           # Standalone DB setup script (manual use)
├── frontend/
│   ├── index.html
│   ├── package.json
│   ├── vite.config.js              # Vite config with /api proxy for local dev
│   └── src/
│       ├── api.js                  # Axios instance with interceptors
│       ├── App.jsx                 # Root component — profile, measurements, trends
│       ├── index.css
│       ├── main.jsx
│       └── components/
│           ├── MeasurementForm.jsx # Weight entry form
│           ├── TrendChart.jsx      # 30-day BMI/weight trend chart
│           └── ProfileForm.jsx     # User profile setup/edit
├── GITHUB-ACTIONS-GUIDE.md         # Full GitHub Actions engineering reference
├── IMPLEMENTATION-AUTO.sh          # Standalone bash deployment script (manual use)
└── README.md
```

---

## 5. Application Workflow

### Data Flow — Submitting a Measurement

```
User enters weight (kg) in MeasurementForm
  ↓
POST /api/measurements  { weightKg, heightCm, age, sex, activity, measurementDate }
  ↓
Express validates required fields and positive-number constraints
  ↓
calculations.js computes:
  BMI               = weight / (height_m)²
  BMR (Mifflin–St Jeor):
    Male   = 10·W + 6.25·H - 5·A + 5
    Female = 10·W + 6.25·H - 5·A - 161
  Daily calories    = BMR × activity multiplier
  BMI category      = Underweight / Normal / Overweight / Obese
  ↓
INSERT INTO measurements (...) RETURNING *
  ↓
201 JSON response → UI updates table and triggers chart reload
```

### API Endpoints

| Method | Path | Description |
|---|---|---|
| `GET` | `/health` | Health check — returns `{ status: "ok", environment: "production" }` |
| `POST` | `/api/measurements` | Create measurement; calculates BMI/BMR server-side |
| `GET` | `/api/measurements` | All measurements, ordered by date descending |
| `GET` | `/api/measurements/trends` | 30-day daily averages (BMI + weight) for chart |
| `GET` | `/api/profile` | Fetch singleton user profile |
| `PUT` | `/api/profile` | Create or update user profile |

---

## 6. CI/CD Pipeline Overview

```
git push → main branch
    │
    ├── Job 1: setup-runner  (GitHub-hosted ubuntu-latest)
    │     ├── Validate EC2_HOST and EC2_SSH_KEY secrets
    │     ├── Write and verify PEM key
    │     ├── Test SSH connectivity to EC2
    │     ├── Call GitHub API → get runner registration token (GH_PAT)
    │     └── SSH to EC2 → pipe setup-runner.sh (idempotent)
    │
    └── Job 2: deploy  (self-hosted runner on EC2)  [needs: setup-runner]
          ├── Record pre-deploy SHA (rollback target)
          ├── git checkout (clean: false — preserves .env)
          ├── Detect mode: FRESH INSTALL or RE-DEPLOY
          │
          ├── 1/8  System packages         (apt-get — fresh only)
          ├── 2/8  Node.js 20 + PM2        (fresh only)
          ├── 3/8  PostgreSQL install + user/DB provision + migrations
          ├── 4/8  Backend: npm install, .env, ecosystem.config.js, PM2
          ├── 5/8  Frontend: Vite build → copy to /var/www/html/bmi-health-tracker
          ├── 6/8  Nginx: full config (fresh) or reload (re-deploy)
          ├── 7/8  UFW: allow SSH + Nginx Full (fresh only)
          ├── 8/8  Certbot: issue cert (skip if valid) + enable renewal timer
          │
          ├── Smoke test: curl --resolve (hairpin NAT bypass)
          │     pass → Deployment summary written to GITHUB_STEP_SUMMARY
          └──   fail → Auto-rollback to pre-deploy SHA → verify → exit

Manual trigger (workflow_dispatch):
  rollback.yml → checkout target SHA → rebuild → reload → health check
```

**Deploy mode detection:** The deploy job checks for the existence of `backend/.env` in the workspace. If the file exists, it is a re-deploy (infrastructure steps are skipped). If not, it is a fresh install and all 8 steps run in full.

---

## 7. GitHub Actions Workflow Explanation

### `deploy.yml`

**Trigger:** `push` to `main` branch  
**Concurrency:** `production-deploy` group, `cancel-in-progress: false` (queued, never cancelled)  
**Permissions:** `contents: read` only

#### Job 1 — `setup-runner`

Runs on `ubuntu-latest`. Ensures the self-hosted runner on EC2 is installed and active before the deploy job attempts to use it.

| Step | What it does |
|---|---|
| Validate secrets | Fails fast if `EC2_HOST` or `EC2_SSH_KEY` are missing |
| Configure SSH | Writes PEM key, validates it with `ssh-keygen -l`, adds host to `known_hosts` |
| Test SSH connectivity | Runs `echo` over SSH — fails with actionable error messages if unreachable |
| Get registration token | Calls GitHub REST API using `GH_PAT`; masks the token immediately |
| Install/start runner | Pipes `setup-runner.sh` to EC2 over SSH — idempotent |
| Cleanup | Removes PEM key from runner (`if: always()`) |

#### Job 2 — `deploy`

Runs on `[self-hosted, linux, x64]` (the EC2 instance). Executes the full 8-step deployment inline.

**Environment variables set at job level:**

```yaml
DOMAIN:    ${{ secrets.DEPLOY_DOMAIN }}
EMAIL:     ${{ secrets.DEPLOY_EMAIL }}
SERVE_DIR: /var/www/html/bmi-health-tracker
DB_NAME:   healthtracker
DB_USER:   ht_user
```

`DB_PASS` is resolved at runtime — either extracted from the existing `.env` (re-deploy) or generated via `openssl rand` (fresh install). It is immediately masked with `::add-mask::`.

### `rollback.yml`

**Trigger:** `workflow_dispatch`  
**Input:** `commit_sha` — optional; defaults to `HEAD~1`  
**Concurrency:** Same `production-deploy` group — cannot run in parallel with a deploy

Rollback only restores application code (backend + frontend). It does not touch packages, database, Nginx config, UFW, or Certbot. It reads database credentials from the existing `backend/.env` so no credentials need to be provided as input.

---

## 8. Self-Hosted Runner Setup

The runner is installed on the same EC2 instance that hosts the application, at `~/actions-runner`.

### How It Works

`.github/scripts/setup-runner.sh` is piped over SSH by the `setup-runner` job on every push to `main`. The script is fully idempotent:

1. If the `actions.runner.*` systemd service is **running** → exit 0
2. If `~/.runner` config file exists but service is stopped → `systemctl start` and exit 0
3. Otherwise → download the latest runner binary, configure it against the repository, install as a systemd service, and start it

### Runner Properties

| Property | Value |
|---|---|
| Install path | `~/actions-runner` |
| Runner name | `$(hostname -s)-production` |
| Labels | `self-hosted,linux,x64` |
| Service | `actions.runner.<repo>.<name>.service` (systemd) |
| Managed by | `setup-runner` job on every push |

### Required PAT for Registration

Runner registration cannot use the built-in `GITHUB_TOKEN`. A separate PAT is required:

| PAT type | Required scope |
|---|---|
| Classic PAT | `repo` + `Administration` |
| Fine-grained PAT | Self-hosted runners: Read and write |

Store the PAT as the `GH_PAT` repository secret.

---

## 9. Deployment Process

### Automated (GitHub Actions — Recommended)

Push to `main`. The pipeline handles everything automatically.

```bash
git add .
git commit -m "feat: your change"
git push origin main
```

Monitor progress at: `https://github.com/<owner>/<repo>/actions`

### Manual Rollback

1. Go to **Actions** → **Rollback Production** → **Run workflow**
2. Enter the target commit SHA (or leave blank for the previous commit)
3. Click **Run workflow**

### Standalone Script (Emergency Use)

`IMPLEMENTATION-AUTO.sh` is a standalone bash script for manual deployment or disaster recovery without GitHub Actions. It performs the same 8-step process.

```bash
# Fresh install
sudo bash IMPLEMENTATION-AUTO.sh

# Re-deploy (skip git pull — useful if already at the right commit)
sudo bash IMPLEMENTATION-AUTO.sh --skip-pull
```

---

## 10. Environment Variables

### Backend — `backend/.env`

This file is **gitignored** and created automatically by the deploy pipeline. Never commit it.

| Variable | Example Value | Description |
|---|---|---|
| `PORT` | `3000` | Express listening port |
| `DATABASE_URL` | `postgresql://ht_user:PASSWORD@localhost:5432/healthtracker` | PostgreSQL connection string |
| `NODE_ENV` | `production` | Runtime environment |
| `FRONTEND_URL` | `https://bmi.ostaddevops.click` | Allowed CORS origin in production |

### GitHub Repository Secrets

Set at **Settings → Secrets and variables → Actions**:

| Secret | Required | Description |
|---|---|---|
| `EC2_HOST` | Yes | Public IP or DNS hostname of the EC2 instance |
| `EC2_SSH_KEY` | Yes | Full contents of the `.pem` private key file |
| `DEPLOY_DOMAIN` | Yes | Domain name, e.g. `bmi.ostaddevops.click` |
| `DEPLOY_EMAIL` | Yes | Email for Let's Encrypt certificate registration |
| `GH_PAT` | Yes | Personal Access Token for runner registration |

---

## 11. Prerequisites

### For Local Development

- **Node.js 20 LTS** — [nodejs.org](https://nodejs.org)
- **npm 9+** — bundled with Node.js
- **PostgreSQL 14+** — running locally with a user and database created
- **Git**

### For Production Deployment

- AWS EC2 instance running **Ubuntu 24.04 LTS**
- EC2 security group allowing inbound: **port 22** (SSH), **port 80** (HTTP), **port 443** (HTTPS)
- A domain name with an **A record** pointing to the EC2 public IP
- A GitHub repository with the five secrets configured (see [Section 10](#10-environment-variables))

---

## 12. Local Development Setup

### 1. Clone the repository

```bash
git clone https://github.com/sarowar-alam/github-actions-three-tier-aws.git
cd github-actions-three-tier-aws
```

### 2. Create a local PostgreSQL database

```bash
psql -U postgres
```

```sql
CREATE USER ht_user WITH PASSWORD 'localpassword';
CREATE DATABASE healthtracker OWNER ht_user;
GRANT ALL PRIVILEGES ON DATABASE healthtracker TO ht_user;
-- PostgreSQL 15+:
\c healthtracker
GRANT ALL ON SCHEMA public TO ht_user;
\q
```

### 3. Run database migrations

```bash
PGPASSWORD=localpassword psql -h 127.0.0.1 -U ht_user -d healthtracker \
  -f backend/migrations/001_create_measurements.sql
PGPASSWORD=localpassword psql -h 127.0.0.1 -U ht_user -d healthtracker \
  -f backend/migrations/002_add_measurement_date.sql
PGPASSWORD=localpassword psql -h 127.0.0.1 -U ht_user -d healthtracker \
  -f backend/migrations/003_create_user_profile.sql
```

### 4. Configure the backend

```bash
cat > backend/.env <<EOF
PORT=3000
DATABASE_URL=postgresql://ht_user:localpassword@localhost:5432/healthtracker
NODE_ENV=development
FRONTEND_URL=http://localhost:5173
EOF
```

### 5. Install dependencies

```bash
# Backend
cd backend && npm install && cd ..

# Frontend
cd frontend && npm install && cd ..
```

### 6. Start both servers

```bash
# Terminal 1 — Backend (with auto-restart via nodemon)
cd backend && npm run dev

# Terminal 2 — Frontend (Vite dev server with /api proxy)
cd frontend && npm run dev
```

The frontend is available at `http://localhost:5173`. API calls to `/api/*` are proxied to `http://localhost:3000` by Vite.

---

## 13. Build and Run Instructions

### Backend — Production Start

```bash
cd backend
npm install --omit=dev
node src/server.js
```

Or via PM2:

```bash
pm2 start backend/ecosystem.config.js
pm2 save
```

### Frontend — Production Build

```bash
cd frontend
npm install
npm run build
# Output: frontend/dist/
```

Serve the `dist/` directory with any static file server. In production, Nginx serves it directly from `/var/www/html/bmi-health-tracker`.

---

## 14. Testing Instructions

The project does not currently have an automated test suite. Manual verification steps:

### Backend API — curl

```bash
# Health check
curl http://localhost:3000/health

# Create a measurement
curl -s -X POST http://localhost:3000/api/measurements \
  -H "Content-Type: application/json" \
  -d '{"weightKg":75,"heightCm":175,"age":30,"sex":"male","activity":"moderate"}' \
  | jq .

# Get all measurements
curl -s http://localhost:3000/api/measurements | jq .

# Get trends
curl -s http://localhost:3000/api/measurements/trends | jq .
```

### Frontend — Manual

1. Open `http://localhost:5173`
2. Complete the profile form (height, age, sex, activity level)
3. Log a weight measurement
4. Verify BMI, BMR, and calorie values appear in the measurement table
5. Log additional measurements on different dates and verify the trend chart updates

### Production Smoke Test

```bash
# From your local machine
curl -s https://bmi.ostaddevops.click/health

# Expected response:
# {"status":"ok","environment":"production"}
```

---

## 15. Production Deployment Steps

### Initial Setup (One Time)

1. **Launch an EC2 instance** — Ubuntu 24.04 LTS, t2.micro or larger
2. **Configure security group** — inbound TCP 22, 80, 443 from `0.0.0.0/0`
3. **Point DNS** — create an A record: `bmi.ostaddevops.click` → EC2 public IP
4. **Add GitHub secrets** — see [Section 10](#10-environment-variables)
5. **Push to `main`** — the pipeline handles everything else

### Deploy (Every Subsequent Push)

```bash
git push origin main
```

The deploy job detects the existing `backend/.env` and runs in **RE-DEPLOY mode**, which:
- Skips system package installation, Node.js setup, PostgreSQL provisioning, and Nginx config rewrite
- Installs updated npm dependencies
- Rebuilds the frontend with Vite
- Runs any new database migrations
- Reloads PM2 with `--update-env` (zero-downtime)
- Reloads Nginx
- Skips Certbot if the current certificate is valid with more than 24 hours remaining

Typical re-deploy time: **60–90 seconds**.

### Verify Deployment

After a successful pipeline run:

```bash
curl -s https://bmi.ostaddevops.click/health
# {"status":"ok","environment":"production"}
```

The **Actions** tab shows a deployment summary with the deployed commit SHA and the live URL.

---

## 16. Monitoring and Logging

### PM2 Process Monitoring

The backend runs as the `ht-backend` PM2 process.

```bash
# Live status
pm2 status

# Live logs (tail)
pm2 logs ht-backend

# Last 100 lines
pm2 logs ht-backend --lines 100

# CPU and memory usage
pm2 monit
```

### PM2 Log Files

| File | Location |
|---|---|
| stdout | `<WORKSPACE>/backend/logs/out.log` |
| stderr | `<WORKSPACE>/backend/logs/err.log` |
| Combined | `<WORKSPACE>/backend/logs/combined.log` |

Log entries include timestamps in `YYYY-MM-DD HH:mm:ss Z` format.

### Nginx Access and Error Logs

```bash
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

### PostgreSQL Logs

```bash
sudo tail -f /var/log/postgresql/postgresql-*.log
```

### Systemd Service Status

```bash
sudo systemctl status nginx
sudo systemctl status postgresql
sudo systemctl status pm2-ubuntu
sudo systemctl status certbot.timer    # SSL auto-renewal
```

### GitHub Actions Run Logs

Every pipeline run is fully logged at:  
`https://github.com/<owner>/<repo>/actions`

---

## 17. Security Practices

### Secrets Management

- All credentials (database password, SSH key, domain) are stored as GitHub encrypted secrets — never in code or workflow YAML
- Database password is generated with `openssl rand -base64 32` on fresh install (28 random alphanumeric characters)
- Database password is masked with `::add-mask::` immediately after being read or generated — it never appears in workflow logs
- `backend/.env` has `chmod 600` permissions — readable only by the owner

### Network Exposure

- Port 3000 (Express) is bound to `127.0.0.1` only — not publicly accessible
- Port 5432 (PostgreSQL) is bound to `127.0.0.1` only — not publicly accessible
- UFW drops all traffic except SSH (22), HTTP (80), and HTTPS (443)

### TLS

- Let's Encrypt certificate issued via Certbot with auto-renewal (systemd timer)
- HTTP is redirected to HTTPS by Certbot's Nginx configuration
- Certbot is skipped on re-deploy if the certificate has more than 24 hours of validity remaining

### HTTP Security Headers

The Nginx config sets the following response headers:

```
X-Frame-Options:        SAMEORIGIN
X-Content-Type-Options: nosniff
X-XSS-Protection:       1; mode=block
Referrer-Policy:        no-referrer-when-downgrade
```

### CORS

In production, CORS is restricted to the `FRONTEND_URL` origin. The API rejects requests from unexpected origins.

### Database

- A dedicated database user `ht_user` is used — not `postgres`
- `ht_user` has privileges on `healthtracker` database only
- Input validation rejects non-positive numbers and enforces allowed values for `sex` and `activity_level` via PostgreSQL `CHECK` constraints

### Nginx

- Hidden files and directories (`location ~ /\.`) are denied
- Static assets are served with `Cache-Control: public, immutable` and a 1-year expiry
- `access_log off` on `/health` to reduce log noise

### GitHub Actions

- `permissions: contents: read` is the only GITHUB_TOKEN permission granted — minimum required for checkout
- The SSH key is written to a temporary file, used, and deleted in a `if: always()` cleanup step
- Runner registration token is masked immediately after retrieval

---

## 18. Troubleshooting

### Setup-runner job fails with "Cannot SSH into EC2"

- Verify `EC2_HOST` contains the correct public IP (it changes on instance restart unless you use an Elastic IP)
- Verify the EC2 security group allows inbound TCP port 22 from `0.0.0.0/0`
- Verify `EC2_SSH_KEY` contains the full PEM file contents including the `-----BEGIN RSA PRIVATE KEY-----` header and footer

### Setup-runner job fails with "Registration token is empty"

- `GH_PAT` must be a **classic** PAT with the **Administration** scope (or a fine-grained PAT with **Self-hosted runners: Read and write**)
- Classic PATs with only `repo` scope are insufficient — `Administration` is required separately

### Deploy job fails with "No runners matching the required labels were found"

The `setup-runner` job succeeded but the runner may not have started in time, or the runner was already configured with different labels. SSH into EC2 and check:

```bash
sudo systemctl status "actions.runner.*"
~/actions-runner/run.sh --check
```

### Backend health check fails after deploy ("waited 45s, no response on :3000")

```bash
# On EC2 — check PM2 status and logs
pm2 status
pm2 logs ht-backend --lines 50

# Common causes:
# 1. DATABASE_URL in .env is wrong (wrong password after re-provision)
# 2. Port 3000 is already bound by another process
# 3. Node.js syntax error in new code

# Check what is using port 3000
sudo ss -tlnp | grep :3000
```

### Frontend shows blank page or 404 on refresh

This is an SPA routing issue. Verify the Nginx `try_files` directive is in place:

```bash
sudo grep -n "try_files" /etc/nginx/sites-available/healthtracker
# Expected: try_files $uri $uri/ /index.html;
```

### Certbot fails with "DNS did not propagate"

The domain A record must resolve to the EC2 public IP **before** Certbot runs. DNS propagation can take up to 48 hours with some registrars. To check:

```bash
host bmi.ostaddevops.click
# Should return the EC2 public IP
```

### Smoke test returns "000" (not "200")

- The application may not have started within the poll window. Check PM2 and Nginx logs.
- On EC2, you cannot curl your own public IP (AWS hairpin NAT). The workflow uses `--resolve ${DOMAIN}:443:127.0.0.1` to bypass this — if you test manually, use the same flag:

```bash
curl -sk --resolve bmi.ostaddevops.click:443:127.0.0.1 \
  https://bmi.ostaddevops.click/health
```

### Auto-rollback fails

If the rollback health check also fails, the workflow exits with a non-zero code and the step summary shows "manual intervention required". SSH into EC2 and investigate:

```bash
pm2 status
pm2 logs ht-backend --lines 100
sudo nginx -t
sudo systemctl status nginx
```

---

## 19. Future Improvements

- **Automated tests** — Add Jest unit tests for `calculations.js` and `routes.js`; run them in a CI job before the deploy job is allowed to proceed
- **Multi-environment support** — Add a `staging` environment with its own EC2 instance; deploy on `push` to `develop`, deploy to production on `push` to `main`
- **Docker containerisation** — Package the backend into a Docker image, store it in ECR, and deploy via `docker pull` + `docker compose up -d`
- **Database** — Migrate from a local PostgreSQL installation to AWS RDS for managed backups, point-in-time recovery, and Multi-AZ failover
- **Secrets rotation** — Automate database password rotation on a schedule using a GitHub Actions workflow and AWS Secrets Manager
- **Observability** — Integrate structured logging (Winston or Pino) and ship logs to CloudWatch Logs or a managed logging service
- **CDN** — Serve the Vite-built static assets via CloudFront instead of Nginx for global edge caching
- **Terraform** — Replace manual EC2 and security group setup with Infrastructure as Code (Terraform) committed to the repository
- **Dependabot** — Enable GitHub Dependabot for automated dependency version updates with automatic PR creation
- **Branch protection** — Require a passing CI check before any PR can merge to `main`

---

## 20. Contributing

### Branch Strategy

```
main        Production — every push triggers a deployment
develop     Integration — PRs merge here first (when multi-env is added)
feature/*   Individual feature branches
fix/*       Bug fix branches
```

### Development Workflow

1. Fork the repository (external contributors) or create a branch (team members)
2. Make changes in a `feature/your-feature-name` branch
3. Test locally using the instructions in [Section 12](#12-local-development-setup)
4. Open a pull request targeting `main`
5. Ensure all checks pass before requesting review
6. Squash and merge after approval

### Commit Message Convention

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add weekly summary email
fix: correct BMR formula for female sex value
chore: update Node.js to 22 LTS
ci: add test job before deploy
docs: update troubleshooting section
```

### Code Style

- JavaScript — no linter is configured yet; follow the existing style (single quotes, semicolons, 2-space indent)
- YAML — 2-space indent, no trailing spaces
- SQL — uppercase keywords, snake_case identifiers

---

## 21. License

This project is released under the [MIT License](https://opensource.org/licenses/MIT).

```
MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
```

---

*Generated from the actual source code, workflow files, and infrastructure configuration in this repository.*

---

## Author

**MD Sarowar Alam**  
Lead DevOps Engineer, WPP Production  
📧 Email: [sarowar@hotmail.com](mailto:sarowar@hotmail.com)  
🔗 LinkedIn: https://www.linkedin.com/in/sarowar/
