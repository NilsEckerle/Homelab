#!/usr/bin/env bash
set -euo pipefail
dockerd-entrypoint.sh >/var/log/dockerd.log 2>&1 &
for i in $(seq 60); do docker info >/dev/null 2>&1 && break; sleep 1; done
docker info >/dev/null 2>&1 || { cat /var/log/dockerd.log; echo "dockerd did not start"; exit 1; }
exec /test/scenario.sh
