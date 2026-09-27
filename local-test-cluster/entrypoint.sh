#!/bin/sh
set -e

# cgroup v2: move into a leaf cgroup and delegate controllers to children
if [ -f /sys/fs/cgroup/cgroup.controllers ]; then
  mkdir -p /sys/fs/cgroup/init
  xargs -rn1 < /sys/fs/cgroup/cgroup.procs > /sys/fs/cgroup/init/cgroup.procs || :
  sed -e 's/ / +/g' -e 's/^/+/' < /sys/fs/cgroup/cgroup.controllers \
    > /sys/fs/cgroup/cgroup.subtree_control
fi

setsid dockerd >/var/log/dockerd.log 2>&1 &

i=0
while ! docker info >/dev/null 2>&1; do
  i=$((i + 1))
  if [ "$i" -ge 60 ]; then
    echo "dockerd did not come up in 60s; last log lines:" >&2
    tail -n 30 /var/log/dockerd.log >&2
    exit 1
  fi
  sleep 1
done

exec "$@"
