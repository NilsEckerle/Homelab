#!/bin/sh
# restic wrapper. modes: restore (one-shot, only if /data is empty) | loop
set -eu

umask 077
mkdir -p /root/.ssh
echo "$SB_SSH_KEY_B64" | base64 -d > /root/.ssh/id
echo "$SB_KNOWN_HOSTS_B64" | base64 -d > /root/.ssh/known_hosts

export RESTIC_REPOSITORY="sftp:${SB_USER}@${SB_HOST}:${SB_PATH}"
r() {
  restic -o "sftp.command=ssh -p ${SB_PORT} -i /root/.ssh/id -o UserKnownHostsFile=/root/.ssh/known_hosts -o StrictHostKeyChecking=yes ${SB_USER}@${SB_HOST} -s sftp" "$@"
}

ensure_repo() { r cat config >/dev/null 2>&1 || r init; }

case "${1:-}" in
  restore)
    if [ -n "$(ls -A /data 2>/dev/null)" ]; then
      echo "restore: /data not empty, nothing to do"; exit 0
    fi
    ensure_repo
    if r snapshots --tag homelab --json | grep -q '"id"'; then
      echo "restore: /data empty, restoring latest snapshot"
      r restore latest --tag homelab --target /
    else
      echo "restore: no snapshot yet, starting fresh"
    fi
    ;;
  loop)
    ensure_repo
    while true; do
      r backup /data --tag homelab || echo "backup failed, will retry next interval"
      r forget --tag homelab --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune \
        || echo "forget/prune failed"
      sleep "${BACKUP_INTERVAL:-86400}"
    done
    ;;
  *) echo "usage: backup.sh restore|loop" >&2; exit 2 ;;
esac
