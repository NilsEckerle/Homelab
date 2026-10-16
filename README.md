# homelab-gitops

One repo describes the whole homelab. Any machine with Docker + git pulls it
every 5 minutes and makes itself match. Secrets live in the repo, encrypted.

```
bootstrap.sh        once per machine: clone, install sops/age, add cron, first run
reconcile.sh        what cron runs: pull, decrypt, restore-if-empty, compose up
install-tools.sh    pinned sops + age
.sops.yaml          which age PUBLIC keys may decrypt
hosts/<hostname>.txt  stacks this machine runs, in order
stacks/<name>/        compose.yaml (+ secrets.enc.env)
test/               docker-in-docker test box
```

## Keys: who can decrypt?

`.sops.yaml` lists age **public** keys. sops encrypts each file's data key once
per listed key; the owner of any one matching **private** key can decrypt.

```
age-keygen -o ~/.config/sops/age/keys.txt      # prints the public key age1...
```

Put the public key into `.sops.yaml`. Store the private key file in your
password manager AND on paper/USB. Lose every private key = lose every secret.
A second recipient (a backup key) makes that survivable.

## Add or edit a secret

```
cp stacks/backup/secrets.example.env stacks/backup/secrets.env   # fill in
sops -e stacks/backup/secrets.env > stacks/backup/secrets.enc.env
rm stacks/backup/secrets.env
sops stacks/backup/secrets.enc.env                               # edit later
```

## Hetzner Storage Box (backup target)

1. Enable SSH support in Robot, add your public key to the box.
2. `ssh-keygen -t ed25519 -f storagebox_ed25519 -N ""`, install the `.pub`.
3. Fill `secrets.example.env` (port 23, `SB_KNOWN_HOSTS_B64` pins the host key).
4. Data to protect goes under `/srv/data/<stack>/` on the host.

The convention: a stack with a `restore` service (profile `restore`) gets it
run to completion before `up`. The backup stack's restore only acts when
`/srv/data` is empty and a snapshot exists, so a new machine comes up with
its data back before apps start. List `backup` first in `hosts/*.txt`.

## New machine

```
# 1. install docker + git, 2. restore your age key to ~/.config/sops/age/keys.txt
REPO_URL=git@github.com:NilsEckerle/homelab.git ./bootstrap.sh
```

Name the host file after `hostname`, or set `HOMELAB_HOST`.

## Test locally

```
test/run.sh
```
Builds a docker-in-docker box named `testlab`, creates a throw-away age key and
a fake storage box (SFTP container), bootstraps from a local bare remote, then
checks: services up, snapshot written, wiped data restored, and a pushed change
deployed. Needs internet (images, sops/age downloads). It does not touch your
real secrets.

## Known limits

- Not run end to end yet when this was written; expect to fix small things.
- sops/age downloads are version-pinned but not checksum-verified.
- Removing a stack from a host file runs `down` (volumes and /srv/data kept).
- Restore needs the storage box reachable on first boot; otherwise the run
  fails and cron retries.
- One restic repo for all of `/srv/data`. Databases need a dump step (or a
  stop) before backup to be consistent.
