#!/bin/sh
set -e
cd .. && mkdir -p forgejo && cd forgejo

wget https://raw.githubusercontent.com/DeveloperKubilay/forgejo-installation/refs/heads/main/docker-compose.yml

fetch_tag() {
	api_url=$1
	if command -v jq >/dev/null 2>&1; then
		curl -s "$api_url" | jq -r .name 2>/dev/null | sed 's/^v//'
	else
		curl -s "$api_url" | sed -n 's/.*"name":[[:space:]]*"\([^\"]*\)".*/\1/p' | sed 's/^v//'
	fi
}

update_image() {
	image_prefix=$1
	tag=$2
	if [ -n "$tag" ]; then
		sed -i -E "s#(image:[[:space:]]*$image_prefix)(:[^[:space:]]*)?#\\1:$tag#g" docker-compose.yml
		echo "Güncellendi: $image_prefix -> :$tag"
	else
		echo "Tag bulunamadı: $image_prefix" >&2
	fi
}

RUNNER_TAG=$(fetch_tag "https://data.forgejo.org/api/v1/repos/forgejo/runner/releases/latest")
update_image "data.forgejo.org/forgejo/runner" "$RUNNER_TAG"

SERVER_TAG=$(fetch_tag "https://codeberg.org/api/v1/repos/forgejo/forgejo/releases/latest")
update_image "codeberg.org/forgejo/forgejo" "$SERVER_TAG"

docker compose up -d