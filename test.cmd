sudo chown -R 1001:1001 runner-data
docker run --rm -it --network forgejo_forgejo -v "$(pwd)/runner-data:/data" --user root data.forgejo.org/forgejo/runner:11 /bin/forgejo-runner register
sudo chown -R 1001:1001 runner-data





