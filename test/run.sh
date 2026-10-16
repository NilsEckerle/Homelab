#!/usr/bin/env bash
# Spins up a throw-away "homelab" (docker-in-docker), bootstraps it from a local
# bare git remote, and checks deploy, backup, restore and a gitops change.
set -euo pipefail
cd "$(dirname "$0")"
status=0
docker compose up --build --abort-on-container-exit --exit-code-from testlab || status=$?
docker compose down -v
exit $status
