#!/usr/bin/env bash
set -euo pipefail

# Run remote script via curl/wget without saving; prefer bash to avoid /bin/sh incompatibilities
run_remote() {
  url="$1"
  echo "-> Running: $url"
  if command -v curl >/dev/null 2>&1; then
    downloader="curl -fsSL $url"
  elif command -v wget >/dev/null 2>&1; then
    downloader="wget -qO- $url"
  else
    echo "curl or wget not found; install one first." >&2
    return 1
  fi

  if command -v bash >/dev/null 2>&1; then
    eval "$downloader" | bash -s --
  else
    eval "$downloader" | sh -s --
  fi
}

run_remote "https://raw.githubusercontent.com/DeveloperKubilay/forgejo-installation/refs/heads/main/install_docker.sh"
run_remote "https://raw.githubusercontent.com/DeveloperKubilay/forgejo-installation/refs/heads/main/run_docker.sh"

cat <<'EOF'
Done.
Open http://localhost:3000 in your browser and finish Forgejo setup.
Commands:
  docker compose up -d    # start
  docker compose down     # stop
EOF