cd ../forgejo
sleep 2
sudo chown -R root:root runner-data

printf "Runner Name: "
read runner_name
[ -z "$runner_name" ] && runner_name=$(hostname)

if [ -e /dev/tty ]; then
  docker exec -it forgejo-runner /bin/forgejo-runner register --name "$runner_name" --labels "docker,$runner_name" </dev/tty >/dev/tty
else
  script -qc "docker exec -it forgejo-runner /bin/forgejo-runner register --name \"$runner_name\" --labels \"docker,$runner_name\"" /dev/null
fi

sudo chown -R root:root runner-data
docker compose restart forgejo-runner

echo "Runner registration complete."