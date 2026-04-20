#!/usr/bin/env bash
# ============================================================
#  setup-runner.sh
#  Installs and starts the GitHub Actions self-hosted runner
#  on the EC2 instance. Safe to run repeatedly (idempotent).
#
#  Required env vars (passed via SSH):
#    REPO       — GitHub repository in "owner/repo" format
#    REG_TOKEN  — Runner registration token (from GitHub API)
#
#  Called by the setup-runner job in deploy.yml via:
#    ssh ubuntu@EC2_HOST "REPO=... REG_TOKEN=... bash -s" < setup-runner.sh
# ============================================================
set -euo pipefail

RUNNER_DIR="$HOME/actions-runner"
RUNNER_NAME="$(hostname -s)-production"

echo "==> Checking runner status..."

# ── Already running? ─────────────────────────────────────────────────────────
# List running systemd services that match the runner pattern.
if systemctl list-units --type=service --state=running 2>/dev/null \
     | grep -q "actions.runner"; then
  echo "    Runner service is already running — nothing to do"
  exit 0
fi

# ── Runner configured but service stopped? ────────────────────────────────────
# If .runner exists, just (re)start the service — no need to re-register.
if [[ -f "$RUNNER_DIR/.runner" ]]; then
  echo "    Runner already configured; starting service..."
  cd "$RUNNER_DIR"
  SVC=$(ls /etc/systemd/system/actions.runner.*.service 2>/dev/null \
        | head -1 | xargs basename 2>/dev/null | sed 's/.service//' || echo "")
  if [[ -n "$SVC" ]]; then
    sudo systemctl start "$SVC"
    echo "    Service '${SVC}' started"
  else
    # Service not installed yet — install then start
    sudo ./svc.sh install ubuntu
    sudo ./svc.sh start
    echo "    Service installed and started"
  fi
  exit 0
fi

# ── Fresh install ─────────────────────────────────────────────────────────────
echo "==> Installing GitHub Actions runner..."
mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

# Find latest runner version
RUNNER_VERSION=$(curl -sf \
  https://api.github.com/repos/actions/runner/releases/latest \
  | grep '"tag_name"' | head -1 | cut -d'"' -f4 | tr -d 'v')
echo "    Downloading runner v${RUNNER_VERSION}..."

curl -sL \
  "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" \
  -o runner.tar.gz
tar xzf runner.tar.gz
rm -f runner.tar.gz
echo "    Runner extracted"

# ── Configure runner ──────────────────────────────────────────────────────────
echo "==> Configuring runner for https://github.com/${REPO}..."
./config.sh \
  --url "https://github.com/${REPO}" \
  --token "${REG_TOKEN}" \
  --name "${RUNNER_NAME}" \
  --labels "self-hosted,linux,x64" \
  --unattended \
  --replace
echo "    Runner configured as '${RUNNER_NAME}'"

# ── Install systemd service ───────────────────────────────────────────────────
echo "==> Installing runner as systemd service..."
sudo ./svc.sh install ubuntu
sudo ./svc.sh start
echo "    Runner service installed and started"

# ── Confirm ───────────────────────────────────────────────────────────────────
systemctl list-units --type=service --state=running 2>/dev/null \
  | grep "actions.runner" || true
echo "==> Self-hosted runner is ready"
