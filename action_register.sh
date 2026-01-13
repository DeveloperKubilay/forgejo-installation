#!/bin/sh
cd ../forgejo || exit 1
sleep 2

if command -v chown >/dev/null 2>&1; then
  sudo chown -R 1001:1001 runner-data 2>/dev/null || true
fi

register_in_container() {
  if [ -t 0 ] || [ -e /dev/tty ]; then
    docker exec -it forgejo-runner /bin/forgejo-runner register || docker exec -it -u 0 forgejo-runner /bin/forgejo-runner register
  else
    script -qc "docker exec -u 0 forgejo-runner /bin/forgejo-runner register" /dev/null || docker exec -u 0 forgejo-runner /bin/forgejo-runner register
  fi
}

register_in_container

docker exec -u 0 forgejo-runner sh -c 'chown -R 1001:1001 /runner-data 2>/dev/null || chown -R 1001:1001 /data 2>/dev/null || true' || true

if command -v chown >/dev/null 2>&1; then
  sudo chown -R 1001:1001 runner-data 2>/dev/null || true
fi

docker compose restart forgejo-runner

echo "Runner registration complete."