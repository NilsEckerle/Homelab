#!/bin/sh
# One-shot, idempotent. Generates homeserver.yaml + signing key on first run,
# then (every run) patches it for Postgres and the public URL.
set -e
if [ ! -f /data/homeserver.yaml ]; then
  # Uses SYNAPSE_SERVER_NAME and SYNAPSE_REPORT_STATS from the environment.
  /start.py generate
fi
python /init/patch.py
