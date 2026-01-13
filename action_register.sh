cd ../forgejo
sleep 2
sudo chown -R 1001:1001 runner-data

if [ -t 0 ]; then
  docker exec -it forgejo-runner /bin/forgejo-runner register
else
  if command -v script >/dev/null 2>&1; then
    script -qc "docker exec -it forgejo-runner /bin/forgejo-runner register" /dev/null
  else
    docker exec -i forgejo-runner /bin/forgejo-runner register
  fi
fi

sudo chown -R 1001:1001 runner-data
docker compose restart forgejo-runner

echo "Runner registration complete."