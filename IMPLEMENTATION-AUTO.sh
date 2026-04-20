#!/usr/bin/env bash
# ============================================================
#  IMPLEMENTATION-AUTO.sh
#  Three-Tier Health Tracker — Full Server Setup
#  Target OS : Ubuntu 24.04 LTS (AWS EC2 or any VPS)
#  Stack     : Node.js 20 + PostgreSQL + Nginx (+ optional SSL)
#
#  Usage:
#    chmod +x IMPLEMENTATION-AUTO.sh
#
#    # IP-only access (no domain):
#    sudo ./IMPLEMENTATION-AUTO.sh
#
#    # With custom domain + Let's Encrypt SSL:
#    sudo ./IMPLEMENTATION-AUTO.sh -d bmi.ostaddevops.click -e admin@bmi.ostaddevops.click
#
#  Re-deploy (run again on an existing server):
#    sudo ./IMPLEMENTATION-AUTO.sh [-d domain -e email]
#    → Detects existing backend/.env → runs git pull → rebuilds app
#    → Skips apt installs, DB provisioning, Nginx config, UFW
#    → Preserves DB password  → PM2 zero-downtime reload
#
#  Options:
#    -d | --domain   Your domain name (must resolve to this server's IP)
#    -e | --email    Email for Let's Encrypt registration (required with -d)
#    -h | --help     Show this help
# ============================================================
set -euo pipefail
IFS=$'\n\t'

# ── Colour helpers ───────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()  { echo -e "${BLUE}[·]${NC} $*"; }
ok()    { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
step()  { echo -e "\n${CYAN}${BOLD}▶  $*${NC}"; }
die()   { echo -e "\n${RED}${BOLD}[✗] ERROR: $*${NC}" >&2; exit 1; }

# ── Argument parsing ─────────────────────────────────────────
DOMAIN=""
EMAIL=""
USE_SSL=false

usage() {
  echo "Usage: sudo $0 [-d domain.com -e admin@domain.com]"
  echo "  -d | --domain   Domain name for Nginx + SSL"
  echo "  -e | --email    Email for Let's Encrypt (required with -d)"
  echo "  -h | --help     Show this help"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--domain) DOMAIN="${2:-}"; shift 2 ;;
    -e|--email)  EMAIL="${2:-}";  shift 2 ;;
    -h|--help)   usage ;;
    *) die "Unknown argument: $1  →  Use -h for help." ;;
  esac
done

[[ $EUID -ne 0 ]] && die "Must run as root: sudo ./IMPLEMENTATION-AUTO.sh"

if [[ -n "$DOMAIN" ]]; then
  [[ -z "$EMAIL" ]] && die "--email is required with --domain (used for Let's Encrypt)"
  [[ "$DOMAIN" =~ ^[a-zA-Z0-9._-]+\.[a-zA-Z]{2,}$ ]] || die "Invalid domain: $DOMAIN"
  USE_SSL=true
fi

# ── Resolve paths ────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$SCRIPT_DIR/backend"
FRONTEND_DIR="$SCRIPT_DIR/frontend"
MIGRATIONS_DIR="$BACKEND_DIR/migrations"
FRONTEND_DIST="$FRONTEND_DIR/dist"
# Web root served by nginx — outside /home so www-data never needs chmod hacks
SERVE_DIR="/var/www/html/bmi-health-tracker"

[[ -d "$BACKEND_DIR" ]]    || die "backend/ not found — run from the repo root."
[[ -d "$FRONTEND_DIR" ]]   || die "frontend/ not found — run from the repo root."
[[ -d "$MIGRATIONS_DIR" ]] || die "backend/migrations/ not found."

# Non-root user who cloned the repo
CURRENT_USER="${SUDO_USER:-ubuntu}"
USER_HOME=$(getent passwd "$CURRENT_USER" | cut -d: -f6)

# ── Detect re-deploy vs fresh install ───────────────────────
# A re-deploy is any run where backend/.env already exists.
REDEPLOY=false
[[ -f "$BACKEND_DIR/.env" ]] && REDEPLOY=true

# ── Database credentials ─────────────────────────────────────
DB_NAME="healthtracker"
DB_USER="ht_user"
if [[ "$REDEPLOY" == true ]]; then
  # Preserve the existing password — rotating it would break the live DB.
  DB_PASS=$(grep '^DATABASE_URL=' "$BACKEND_DIR/.env" \
    | sed 's|.*://[^:]*:\([^@]*\)@.*|\1|')
  [[ -z "$DB_PASS" ]] && die "Could not parse DB password from $BACKEND_DIR/.env"
else
  DB_PASS="$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 28)"
fi
DB_URL="postgresql://${DB_USER}:${DB_PASS}@localhost:5432/${DB_NAME}"

# ── Detect public IP ─────────────────────────────────────────
PUBLIC_IP=$(curl -sf --max-time 5 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null \
         || curl -sf --max-time 5 https://api.ipify.org 2>/dev/null \
         || hostname -I | awk '{print $1}')

FRONTEND_ORIGIN="http://${PUBLIC_IP}"
[[ "$USE_SSL" == true ]] && FRONTEND_ORIGIN="https://${DOMAIN}"

# ── Banner ───────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║       HealthTracker — Automated Setup            ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo ""
if [[ "$REDEPLOY" == true ]]; then
  info "Mode       : RE-DEPLOY  (git pull + rebuild)"
else
  info "Mode       : FRESH INSTALL"
fi
info "Repo root  : $SCRIPT_DIR"
info "OS user    : $CURRENT_USER  (home: $USER_HOME)"
info "Public IP  : $PUBLIC_IP"
info "App URL    : $FRONTEND_ORIGIN"
[[ "$USE_SSL" == true ]] && info "Domain     : $DOMAIN  (SSL via Let's Encrypt)"
echo ""

# ── Git pull on re-deploy (runs before any other step) ───────
if [[ "$REDEPLOY" == true ]]; then
  step "Git pull — fetching latest code"
  su - "$CURRENT_USER" -c "cd '$SCRIPT_DIR' && git pull --ff-only" \
    && ok "Repository updated" \
    || die "git pull failed — resolve merge conflicts manually, then re-run"
fi

# ============================================================
step "1 / 8 — System packages"
# ============================================================
export DEBIAN_FRONTEND=noninteractive
if [[ "$REDEPLOY" == false ]]; then
  apt-get update -qq
  apt-get upgrade -y -qq
  apt-get install -y -qq \
    curl wget git unzip gnupg lsb-release \
    ca-certificates software-properties-common \
    build-essential openssl dnsutils ufw
  ok "Base packages ready"
else
  ok "System packages — skipped (re-deploy)"
fi

# ============================================================
step "2 / 8 — Node.js 20 LTS + PM2"
# ============================================================
if [[ "$REDEPLOY" == false ]]; then
  NODE_MAJOR=20
  if ! command -v node &>/dev/null || \
     [[ "$(node -v | cut -d. -f1 | tr -d 'v')" -lt 18 ]]; then
    info "Installing Node.js ${NODE_MAJOR}..."
    curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - >/dev/null 2>&1
    apt-get install -y -qq nodejs
  fi
  npm install -g pm2 --silent 2>/dev/null || npm install -g pm2
  ok "Node $(node -v)  |  npm $(npm -v)  |  PM2 $(pm2 -v)"
else
  ok "Node.js + PM2 — skipped (re-deploy, already installed)"
fi

# ============================================================
step "3 / 8 — PostgreSQL"
# ============================================================
if [[ "$REDEPLOY" == false ]]; then
  if ! command -v psql &>/dev/null; then
    apt-get install -y -qq postgresql postgresql-contrib
  fi
  systemctl enable postgresql --quiet
  systemctl start postgresql
  ok "PostgreSQL $(psql --version | awk '{print $3}') running"

  info "Provisioning database user and schema..."
  sudo -u postgres psql -v ON_ERROR_STOP=1 <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DB_USER}') THEN
    CREATE ROLE ${DB_USER} LOGIN PASSWORD '${DB_PASS}';
  ELSE
    ALTER ROLE ${DB_USER} WITH PASSWORD '${DB_PASS}';
  END IF;
END\$\$;

SELECT 'CREATE DATABASE ${DB_NAME} OWNER ${DB_USER}'
  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${DB_NAME}')\gexec

GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};
SQL

# PostgreSQL 15+ requires explicit schema grant
sudo -u postgres psql -d "${DB_NAME}" \
  -c "GRANT ALL ON SCHEMA public TO ${DB_USER};" >/dev/null 2>&1 || true

  ok "Database '${DB_NAME}' + user '${DB_USER}' ready"
else
  # Ensure PostgreSQL is running before migrations
  systemctl start postgresql >/dev/null 2>&1 || true
  ok "PostgreSQL provisioning — skipped (re-deploy)"
fi

info "Running migrations in order..."
while IFS= read -r MIGRATION; do
  MNAME="$(basename "$MIGRATION")"
  if PGPASSWORD="$DB_PASS" psql -h 127.0.0.1 -U "$DB_USER" -d "$DB_NAME" \
       -f "$MIGRATION" -q 2>&1; then
    ok "  ✓ $MNAME"
  else
    warn "  ↷ $MNAME — may already be applied, continuing"
  fi
done < <(find "$MIGRATIONS_DIR" -maxdepth 1 -name '*.sql' | sort)

# ============================================================
step "4 / 8 — Backend (Node.js / Express)"
# ============================================================
cd "$BACKEND_DIR"
npm install --omit=dev --silent
ok "Backend npm packages installed"

# Write .env (fresh install only — preserve existing creds on re-deploy)
if [[ "$REDEPLOY" == false ]]; then
  cat > "$BACKEND_DIR/.env" <<ENV
PORT=3000
DATABASE_URL=${DB_URL}
NODE_ENV=production
FRONTEND_URL=${FRONTEND_ORIGIN}
ENV
  chmod 600 "$BACKEND_DIR/.env"
  chown "$CURRENT_USER:$CURRENT_USER" "$BACKEND_DIR/.env"
  ok ".env written (DB password auto-generated)"
else
  ok ".env — kept existing (re-deploy)"
fi

# Create log directory
mkdir -p "$BACKEND_DIR/logs"
chown -R "$CURRENT_USER:$CURRENT_USER" "$BACKEND_DIR/logs"

# Rewrite ecosystem.config.js with real absolute paths
cat > "$BACKEND_DIR/ecosystem.config.js" <<ECOSYSTEM
module.exports = {
  apps: [{
    name: 'ht-backend',
    script: './src/server.js',
    cwd: '${BACKEND_DIR}',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '500M',
    env_file: '${BACKEND_DIR}/.env',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    error_file: '${BACKEND_DIR}/logs/err.log',
    out_file:   '${BACKEND_DIR}/logs/out.log',
    log_file:   '${BACKEND_DIR}/logs/combined.log',
    time: true,
    merge_logs: true,
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z'
  }]
};
ECOSYSTEM
chmod 644 "$BACKEND_DIR/ecosystem.config.js"
chown "$CURRENT_USER:$CURRENT_USER" "$BACKEND_DIR/ecosystem.config.js"
ok "ecosystem.config.js updated with absolute paths"

# Register PM2 as a systemd service
pm2 startup systemd -u "$CURRENT_USER" --hp "$USER_HOME" >/dev/null 2>&1 || true

info "Starting backend via PM2..."
if [[ "$REDEPLOY" == true ]]; then
  # reload ecosystem.config.js so any config changes (env, paths) are applied;
  # --update-env passes the updated env block; falls back to start if not running
  su - "$CURRENT_USER" -c "
    cd '$BACKEND_DIR'
    pm2 reload ecosystem.config.js --update-env 2>/dev/null \
      || pm2 start ecosystem.config.js
    pm2 save --force
  "
else
  su - "$CURRENT_USER" -c "
    cd '$BACKEND_DIR'
    pm2 delete ht-backend 2>/dev/null || true
    pm2 start ecosystem.config.js
    pm2 save --force
  "
fi

systemctl enable "pm2-${CURRENT_USER}" >/dev/null 2>&1 || true
systemctl start  "pm2-${CURRENT_USER}" >/dev/null 2>&1 || true

# Wait for backend to be ready
info "Waiting for backend to respond on :3000..."
for i in {1..15}; do
  if curl -sf http://127.0.0.1:3000/health >/dev/null 2>&1; then
    ok "Backend API is up on :3000"
    break
  fi
  [[ $i -eq 15 ]] && die "Backend did not start within 45s.\nCheck logs:\n  su - $CURRENT_USER -c 'pm2 logs ht-backend --lines 50'"
  sleep 3
done

# ============================================================
step "5 / 8 — Frontend (React / Vite build)"
# ============================================================
chown -R "$CURRENT_USER:$CURRENT_USER" "$FRONTEND_DIR"
su - "$CURRENT_USER" -c "
  cd '$FRONTEND_DIR'
  npm install --silent
  npm run build
"
[[ -d "$FRONTEND_DIST" ]] || die "Vite build failed — $FRONTEND_DIST not found."
ok "Frontend built → $FRONTEND_DIST"

# Copy build output to /var/www — www-data owns this tree by default.
# This avoids all /home/ubuntu permission issues entirely.
mkdir -p "$SERVE_DIR"
rm -rf "${SERVE_DIR:?}/"*
cp -a "$FRONTEND_DIST/." "$SERVE_DIR/"
chown -R www-data:www-data "$SERVE_DIR"
chmod -R 755 "$SERVE_DIR"
ok "Frontend deployed → $SERVE_DIR"

# ============================================================
step "6 / 8 — Nginx"
# ============================================================
if [[ "$REDEPLOY" == false ]]; then
  apt-get install -y -qq nginx
  systemctl enable nginx --quiet

# server_name: _ catches all IPs; replace with domain if provided
SERVER_NAME="_"
[[ "$USE_SSL" == true ]] && SERVER_NAME="$DOMAIN www.$DOMAIN"

NGINX_CONF="/etc/nginx/sites-available/healthtracker"
cat > "$NGINX_CONF" <<NGINX
# HealthTracker — generated by IMPLEMENTATION-AUTO.sh on $(date)

server {
    listen 80;
    listen [::]:80;
    server_name ${SERVER_NAME};

    root ${SERVE_DIR};
    index index.html;

    # ── Gzip compression ──────────────────────────────
    gzip on;
    gzip_vary on;
    gzip_comp_level 6;
    gzip_types
        text/plain text/css text/xml text/javascript
        application/json application/javascript application/xml+rss
        image/svg+xml;
    gzip_min_length 1024;

    # ── Security headers ──────────────────────────────
    add_header X-Frame-Options          "SAMEORIGIN"                always;
    add_header X-Content-Type-Options   "nosniff"                   always;
    add_header X-XSS-Protection         "1; mode=block"             always;
    add_header Referrer-Policy          "no-referrer-when-downgrade" always;

    # ── Backend API proxy ─────────────────────────────
    location /api/ {
        proxy_pass          http://127.0.0.1:3000;
        proxy_http_version  1.1;
        proxy_set_header    Host              \$host;
        proxy_set_header    X-Real-IP         \$remote_addr;
        proxy_set_header    X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header    X-Forwarded-Proto \$scheme;
        proxy_read_timeout  30s;
        proxy_connect_timeout 5s;
    }

    # ── Health check proxy ────────────────────────────
    location /health {
        proxy_pass         http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header   Host \$host;
        access_log off;
    }

    # ── React SPA — client-side routing ──────────────
    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # ── Cache static assets 1 year ────────────────────
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # ── Block hidden files ────────────────────────────
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    # ── Silence favicon 404 log noise ─────────────────
    location = /favicon.ico {
        try_files \$uri =204;
        access_log off;
        log_not_found off;
    }
}
NGINX

# Enable site, disable default
ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/healthtracker
rm -f /etc/nginx/sites-enabled/default

  nginx -t || die "Nginx config test failed — check $NGINX_CONF"
  systemctl restart nginx
  ok "Nginx configured and running"
else
  # On re-deploy, update the root path in the nginx config (certbot may have
  # rewritten it) and reload nginx. reload-or-restart handles a stopped nginx.
  sed -i "s|root /[^;]*/frontend/dist;|root ${SERVE_DIR};|g" /etc/nginx/sites-available/healthtracker 2>/dev/null || true
  nginx -t || die "Nginx config test failed — run: sudo nginx -t"
  systemctl reload-or-restart nginx
  ok "Nginx reloaded — serving new frontend build from $SERVE_DIR"
fi

# ============================================================
step "7 / 8 — UFW firewall"
# ============================================================
if [[ "$REDEPLOY" == false ]]; then
  ufw allow OpenSSH      >/dev/null 2>&1
  ufw allow 'Nginx Full' >/dev/null 2>&1
  ufw --force enable     >/dev/null 2>&1
  ok "UFW: SSH + HTTP + HTTPS allowed"
else
  ok "UFW firewall — skipped (re-deploy)"
fi

# ============================================================
step "8 / 8 — SSL via Let's Encrypt (Certbot)"
# ============================================================
if [[ "$USE_SSL" == true ]]; then
  apt-get install -y -qq certbot python3-certbot-nginx

  # ── Check if a valid certificate already exists ───────────
  CERT_FILE="/etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
  CERT_SKIP=false
  if [[ -f "$CERT_FILE" ]]; then
    # openssl returns exit 0 if the cert is still valid, non-zero if expired
    if openssl x509 -checkend 86400 -noout -in "$CERT_FILE" 2>/dev/null; then
      EXPIRY=$(openssl x509 -noout -enddate -in "$CERT_FILE" 2>/dev/null | cut -d= -f2)
      ok "Valid certificate already exists for $DOMAIN (expires: $EXPIRY) — skipping certbot"
      CERT_SKIP=true
    else
      warn "Certificate for $DOMAIN exists but expires within 24 h — renewing..."
    fi
  fi

  if [[ "$CERT_SKIP" == false ]]; then
    # DNS pre-flight check
    info "Checking DNS resolution for $DOMAIN..."
    RESOLVED_IP=$(host -t A "$DOMAIN" 2>/dev/null \
      | grep "has address" | head -1 | awk '{print $NF}' || echo "")

    if [[ -z "$RESOLVED_IP" ]]; then
      warn "Could not resolve $DOMAIN — DNS may not have propagated yet."
      warn "Certbot will fail if $DOMAIN does not point to $PUBLIC_IP"
    elif [[ "$RESOLVED_IP" != "$PUBLIC_IP" ]]; then
      warn "DNS mismatch:"
      warn "  $DOMAIN resolves to : $RESOLVED_IP"
      warn "  This server's IP    : $PUBLIC_IP"
      warn "Fix your A record in Route53 (or DNS provider) before running again."
      warn "Attempting certbot anyway..."
    else
      ok "DNS OK — $DOMAIN → $RESOLVED_IP"
    fi

    # --nginx plugin: edits Nginx config, installs cert, redirects HTTP→HTTPS
    certbot --nginx \
      -d "$DOMAIN" \
      --email "$EMAIL" \
      --agree-tos \
      --non-interactive \
      --redirect \
      && ok "SSL certificate issued — Nginx updated for https://${DOMAIN}" \
      || die "Certbot failed.\n  → Ensure $DOMAIN points to $PUBLIC_IP\n  → Ensure port 80 is open in your AWS security group"
  fi

  # Enable auto-renewal timer (idempotent)
  systemctl enable certbot.timer >/dev/null 2>&1 || true
  systemctl start  certbot.timer >/dev/null 2>&1 || true
  ok "certbot.timer enabled — auto-renewal every 12 hours"

  FRONTEND_ORIGIN="https://${DOMAIN}"
else
  info "SSL skipped — no --domain flag provided (HTTP only)"
fi

# ============================================================
# Save credentials to a local file (fresh install only)
# ============================================================
CREDS_FILE="$SCRIPT_DIR/.setup-credentials"
if [[ "$REDEPLOY" == false ]]; then
  cat > "$CREDS_FILE" <<CREDS
# HealthTracker setup credentials
# Generated: $(date)
# ⚠️  Keep this file safe — add to .gitignore — do NOT commit!

DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASS=${DB_PASS}
DB_URL=${DB_URL}
CREDS
  chmod 600 "$CREDS_FILE"
  chown "$CURRENT_USER:$CURRENT_USER" "$CREDS_FILE"
  ok "Credentials saved to $CREDS_FILE"

  # Add to .gitignore if not already there
  GITIGNORE="$SCRIPT_DIR/.gitignore"
  if [[ -f "$GITIGNORE" ]]; then
    grep -qxF ".setup-credentials" "$GITIGNORE" || echo ".setup-credentials" >> "$GITIGNORE"
  else
    echo ".setup-credentials" > "$GITIGNORE"
  fi
  ok ".setup-credentials added to .gitignore"
else
  ok "Credentials file — skipped (re-deploy, credentials unchanged)"
fi

# ============================================================
# Smoke test
# ============================================================
step "Smoke test"
sleep 2
# After certbot rewrites nginx, the HTTP block returns 404 for requests by IP
# (host != domain), so check via HTTPS when SSL is enabled.
if [[ "$USE_SSL" == true ]]; then
  HEALTH_URL="https://${DOMAIN}/health"
else
  HEALTH_URL="http://127.0.0.1/health"
fi
# curl exits non-zero (code 7) when it can't connect; || true prevents
# set -euo pipefail from killing the script. %{http_code} will be "000".
HTTP_STATUS=$(curl -sk -o /dev/null -w "%{http_code}" "$HEALTH_URL" 2>/dev/null || true)
if [[ "$HTTP_STATUS" == "200" ]]; then
  ok "Health check ($HEALTH_URL): $HTTP_STATUS ✓"
else
  warn "Health check ($HEALTH_URL) returned HTTP $HTTP_STATUS — the app may still be warming up"
fi

# ============================================================
# Done
# ============================================================
echo ""
if [[ "$REDEPLOY" == true ]]; then
  GIT_REF=$(su - "$CURRENT_USER" -c "cd '$SCRIPT_DIR' && git log -1 --format='%h %s'" 2>/dev/null || echo "unknown")
  echo -e "${GREEN}${BOLD}╔════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}${BOLD}║   ✓  Re-Deploy Complete!                               ║${NC}"
  echo -e "${GREEN}${BOLD}╚════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  ${BOLD}Deployed commit :${NC}  $GIT_REF"
else
  echo -e "${GREEN}${BOLD}╔════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}${BOLD}║   ✓  Setup Complete!                                   ║${NC}"
  echo -e "${GREEN}${BOLD}╚════════════════════════════════════════════════════════╝${NC}"
fi
echo ""
if [[ "$USE_SSL" == true ]]; then
  echo -e "  ${BOLD}App URL      :${NC}  https://${DOMAIN}"
else
  echo -e "  ${BOLD}App URL      :${NC}  http://${PUBLIC_IP}"
fi
echo -e "  ${BOLD}Health check :${NC}  http://${PUBLIC_IP}/health"
[[ "$REDEPLOY" == false ]] && echo -e "  ${BOLD}DB creds     :${NC}  $CREDS_FILE"
echo ""
echo -e "  ${BOLD}Useful commands:${NC}"
echo -e "    su - ${CURRENT_USER} -c 'pm2 status'"
echo -e "    su - ${CURRENT_USER} -c 'pm2 logs ht-backend --lines 50'"
echo -e "    sudo nginx -t && sudo systemctl reload nginx"
echo -e "    sudo journalctl -u nginx -f"
echo -e "    sudo tail -f /var/log/nginx/error.log"
echo ""
