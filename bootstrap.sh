#!/usr/bin/env bash
# Run once on a fresh machine that already has docker + git.
#   REPO_URL=git@github.com:NilsEckerle/homelab.git ./bootstrap.sh
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

if [ "${1:-}" != "--no-schedule" ]; then
  echo "*/5 * * * * root $TARGET/reconcile.sh >> /var/log/homelab.log 2>&1" > /etc/cron.d/homelab
  chmod 644 /etc/cron.d/homelab
fi

"$TARGET/reconcile.sh"
