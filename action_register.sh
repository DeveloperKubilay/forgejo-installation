sudo chown -R 1001:1001 runner-data
docker exec -it forgejo-runner /bin/forgejo-runner register
sudo chown -R 1001:1001 runner-data

echo "Runner registration complete."
docker compose restart server