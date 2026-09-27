#!/usr/bin/env bash
# Run once after cloning: stamp your own git remote into the manifests.
# Argo CD reads the child Applications *from git*, so the URL has to be
# committed - it cannot be patched at apply time like the root app.
set -euo pipefail
REPO_URL="${REPO_URL:-$(git remote get-url origin)}"
REPO_BRANCH="${REPO_BRANCH:-$(git rev-parse --abbrev-ref HEAD)}"
grep -rl -e git@github.com:NilsEckerle/Homelab.git -e main --exclude-dir=.git . \
  | xargs sed -i -e "s|git@github.com:NilsEckerle/Homelab.git|${REPO_URL}|g" -e "s|main|${REPO_BRANCH}|g"
echo "stamped ${REPO_URL} @ ${REPO_BRANCH} - now: git commit -am 'init' && git push"
