#!/usr/bin/env bash
# Run once on a fresh machine that already has docker + git.
#   REPO_URL=git@github.com:you/homelab.git ./bootstrap.sh
# Before running, place the age PRIVATE key at ~/.config/sops/age/keys.txt.
#   --no-schedule   skip installing the cron job (used by the test box)
set -euo pipefail
REPO_URL=${REPO_URL:?set REPO_URL}
TARGET=${TARGET:-/opt/homelab}
KEY=${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}

command -v docker >/dev/null || { echo "docker missing" >&2; exit 1; }
command -v git    >/dev/null || { echo "git missing" >&2; exit 1; }
[ -f "$KEY" ] || { echo "age key missing at $KEY (restore it from your password manager)" >&2; exit 1; }

[ -d "$TARGET/.git" ] || git clone "$REPO_URL" "$TARGET"
"$TARGET/install-tools.sh"

schedule() {
  if [ -d /run/systemd/system ]; then          # systemd: timer (Arch, Debian, ...)
    cat > /etc/systemd/system/homelab.service <<EOT
[Unit]
Description=homelab gitops reconcile
[Service]
Type=oneshot
Environment=HOME=/root
ExecStart=$TARGET/reconcile.sh
EOT
    cat > /etc/systemd/system/homelab.timer <<EOT
[Unit]
Description=run homelab reconcile every 5 minutes
[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
[Install]
WantedBy=timers.target
EOT
    systemctl daemon-reload
    systemctl enable --now homelab.timer
  else                                          # no systemd: root crontab
    command -v crontab >/dev/null || { echo "no systemd and no crontab, schedule $TARGET/reconcile.sh yourself" >&2; return; }
    { crontab -l 2>/dev/null | grep -v "$TARGET/reconcile.sh" || true
      echo "*/5 * * * * $TARGET/reconcile.sh >> /var/log/homelab.log 2>&1"
    } | crontab -
  fi
}

[ "${1:-}" = "--no-schedule" ] || schedule

"$TARGET/reconcile.sh"
