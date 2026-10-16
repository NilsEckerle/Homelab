#!/usr/bin/env bash
set -euo pipefail
step() { echo; echo "=== $*"; }
fail() { echo "FAIL: $*"; docker ps -a; exit 1; }
wait_for() { # wait_for <seconds> <description> <cmd...>
  local t=$1 d=$2; shift 2
  for _ in $(seq "$t"); do "$@" >/dev/null 2>&1 && return 0; sleep 1; done
  fail "timeout: $d"
}
git_t() { git -c user.name=test -c user.email=test@test "$@"; }

step "1. prepare: tools, throw-away age key, fake storage box keys, bare remote"
/src/install-tools.sh
mkdir -p ~/.config/sops/age /opt/testlab/sftp/upload /remote
age-keygen -o ~/.config/sops/age/keys.txt 2>/dev/null
pub=$(age-keygen -y ~/.config/sops/age/keys.txt)
ssh-keygen -q -t ed25519 -N "" -f /opt/testlab/sftp/ssh_host_ed25519_key
ssh-keygen -q -t ed25519 -N "" -f /opt/testlab/sftp/client
chown 1001:100 /opt/testlab/sftp/upload

work=/tmp/work
mkdir -p $work && cp -r /src/. $work/ && cd $work && rm -rf .git test
# own sops config + no real secrets, whatever the repo under test contains
rm -f stacks/backup/secrets.enc.env
# own Caddyfile: the real one names a public host, and failed Let's Encrypt
# validations from this offline box would count against that hostname
printf 'http://hello.lan {\n\treverse_proxy hello:80\n}\n' > stacks/proxy/caddy/Caddyfile
printf 'creation_rules:\n  - path_regex: secrets(\\.enc)?\\.env$\n    age: %s\n' "$pub" > .sops.yaml
hostkey=$(cut -d' ' -f1,2 /opt/testlab/sftp/ssh_host_ed25519_key.pub)
cat > stacks/backup/secrets.env <<EOT
RESTIC_PASSWORD=test-password
SB_USER=backup
SB_HOST=host.docker.internal
SB_PORT=2222
SB_PATH=/upload/restic
SB_SSH_KEY_B64=$(base64 -w0 /opt/testlab/sftp/client)
SB_KNOWN_HOSTS_B64=$(echo "[host.docker.internal]:2222 $hostkey" | base64 -w0)
BACKUP_INTERVAL=3600
EOT
sops -e stacks/backup/secrets.env > stacks/backup/secrets.enc.env
rm stacks/backup/secrets.env
grep -q test-password stacks/backup/secrets.enc.env && fail "secret is not encrypted"
git init -q -b main && git_t add -A && git_t commit -qm "test repo"
git clone -q --bare . /remote/homelab.git

step "2. bootstrap (clone, install, first reconcile) with data to protect"
mkdir -p /srv/data/demo && echo hello > /srv/data/demo/hello.txt
REPO_URL=/remote/homelab.git TARGET=/opt/homelab /src/bootstrap.sh --no-schedule
wait_for 60 "whoami on :8080" curl -fs localhost:8080
echo "whoami answers on :8080"
wait_for 60 "hello.lan via proxy" curl -fs -H 'Host: hello.lan' localhost:80
echo "proxy routes hello.lan"

step "3. backup reaches the (fake) storage box"
wait_for 90 "restic snapshot on storage box" bash -c 'ls /opt/testlab/sftp/upload/restic/snapshots/* 2>/dev/null | grep -q .'
echo "snapshot exists"

step "4. disaster: wipe data, redeploy, expect restore"
docker compose -p backup stop
rm -rf /srv/data/*
FORCE=1 /opt/homelab/reconcile.sh
[ "$(cat /srv/data/demo/hello.txt)" = hello ] || fail "hello.txt was not restored"
echo "hello.txt restored"

step "5. gitops: push a change, plain reconcile picks it up"
git clone -q /remote/homelab.git /tmp/edit && cd /tmp/edit
sed -i 's/8080:80/8081:80/' stacks/whoami/compose.yaml
git_t commit -qam "whoami on 8081" && git push -q origin main
/opt/homelab/reconcile.sh
wait_for 30 "whoami on :8081" curl -fs localhost:8081
echo "change deployed"

echo; echo "PASS"
