cd ../forgejo
sleep 2
sudo chown -R root:root runner-data

if [ -e /dev/tty ]; then
  docker exec -it forgejo-runner /bin/forgejo-runner register </dev/tty >/dev/tty
else
  script -qc "docker exec -it forgejo-runner /bin/forgejo-runner register" /dev/null
fi

sudo chown -R root:root runner-data
docker compose restart forgejo-runner

echo "Runner registration complete."