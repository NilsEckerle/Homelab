#!/usr/bin/env bash
# Pull the repo, then make the machine match it. Safe to run every few minutes.
#   FORCE=1          redeploy even if the commit was already applied
#   HOMELAB_HOST=x   pick hosts/x.txt instead of hosts/$(hostname).txt
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"
STATE_DIR=${STATE_DIR:-/var/lib/homelab}
HOST=${HOMELAB_HOST:-$(hostname)}
export SOPS_AGE_KEY_FILE=${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}

mkdir -p "$STATE_DIR"
exec 9>"$STATE_DIR/lock"
flock -n 9 || { echo "another run is active"; exit 0; }

log() { echo "[$(date '+%Y-%m-%dT%H:%M:%S%z')] $*"; }
die() { log "ERROR: $*"; exit 1; }

# 1. pull (fast-forward only: a diverged history fails loudly instead of merging)
git fetch -q origin
git merge -q --ff-only '@{u}'
head=$(git rev-parse HEAD)
applied=$(cat "$STATE_DIR/applied" 2>/dev/null || true)
if [ "$head" = "$applied" ] && [ -z "${FORCE:-}" ]; then
  exit 0
fi

hostfile="hosts/$HOST.txt"
[ -f "$hostfile" ] || die "no $hostfile"
mapfile -t wanted < <(grep -vE '^\s*(#|$)' "$hostfile")

# 2. stop stacks that were deployed before but are no longer wanted (no -v: data stays)
touch "$STATE_DIR/stacks"
while read -r old; do
  [ -z "$old" ] && continue
  if ! printf '%s\n' "${wanted[@]}" | grep -qx "$old"; then
    log "removing stack $old"
    docker compose -p "$old" down --remove-orphans || true
  fi
done < "$STATE_DIR/stacks"

# 3. deploy wanted stacks in file order
failed=0
for stack in "${wanted[@]}"; do
  dir="stacks/$stack"
  [ -f "$dir/compose.yaml" ] || { log "missing $dir/compose.yaml"; failed=1; continue; }
  if [ -f "$dir/secrets.example.env" ] && [ ! -f "$dir/secrets.enc.env" ]; then
    log "stack $stack FAILED: needs $dir/secrets.enc.env (see secrets.example.env)"
    failed=1; continue
  fi
  log "stack $stack"
  envfile=$(mktemp -p /dev/shm 2>/dev/null || mktemp)   # RAM-backed when available
  (
    trap 'rm -f "$envfile"' EXIT
    if [ -f "$dir/secrets.enc.env" ]; then
      sops -d --input-type dotenv --output-type dotenv "$dir/secrets.enc.env" > "$envfile"
    fi
    dc=(docker compose -p "$stack" --project-directory "$dir" -f "$dir/compose.yaml" --env-file "$envfile")
    if "${dc[@]}" --profile restore config --services | grep -qx restore; then
      "${dc[@]}" --profile restore run --rm restore
    fi
    "${dc[@]}" up -d --remove-orphans
  ) || { log "stack $stack FAILED"; failed=1; }
done

printf '%s\n' "${wanted[@]}" > "$STATE_DIR/stacks"
if [ "$failed" -eq 0 ]; then
  echo "$head" > "$STATE_DIR/applied"
  log "applied $head"
else
  die "some stacks failed, will retry next run"
fi
