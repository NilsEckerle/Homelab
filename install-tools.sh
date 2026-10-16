#!/usr/bin/env bash
# Installs sops + age if missing. Needs curl and root. Versions are pinned.
set -euo pipefail
SOPS_VERSION=3.13.3
AGE_VERSION=1.3.2

case "$(uname -m)" in
  x86_64)  arch=amd64 ;;
  aarch64) arch=arm64 ;;
  *) echo "unsupported arch $(uname -m)" >&2; exit 1 ;;
esac

if ! command -v sops >/dev/null; then
  curl -fsSL -o /usr/local/bin/sops \
    "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.${arch}"
  chmod +x /usr/local/bin/sops
fi
if ! command -v age >/dev/null; then
  curl -fsSL "https://github.com/FiloSottile/age/releases/download/v${AGE_VERSION}/age-v${AGE_VERSION}-linux-${arch}.tar.gz" \
    | tar -xz -C /usr/local/bin --strip-components=1 age/age age/age-keygen
fi
sops --version | head -1
age --version
