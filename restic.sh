#!/usr/bin/env bash
# Run any restic command against the backup repo using the encrypted secrets.
#   ./restic.sh snapshots
#   ./restic.sh ls latest
#   ./restic.sh check
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
export SOPS_AGE_KEY_FILE=${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}
envfile=$(mktemp -p /dev/shm 2>/dev/null || mktemp)
trap 'rm -f "$envfile"' EXIT
sops -d --input-type dotenv --output-type dotenv stacks/backup/secrets.enc.env > "$envfile"
docker compose -p backup --project-directory stacks/backup -f stacks/backup/compose.yaml \
  --env-file "$envfile" --profile restore run --rm restore restic "$@"
