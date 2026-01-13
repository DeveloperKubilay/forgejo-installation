cd ../forgejo
sleep 2
sudo chown -R 1001:1001 runner-data

if [ -t 0 ]; then
  docker exec -it forgejo-runner /bin/forgejo-runner register
elif [ -e /dev/tty ]; then
  docker exec -i forgejo-runner /bin/forgejo-runner register < /dev/tty
else
  script -qc "docker exec -it forgejo-runner /bin/forgejo-runner register" /dev/null
fi

sudo chown -R 1001:1001 runner-data
docker compose restart forgejo-runner

echo "Runner registration complete."