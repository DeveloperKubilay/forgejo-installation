#!/bin/sh
cd .. && mkdir -p forgejo && cd forgejo

wget https://raw.githubusercontent.com/DeveloperKubilay/forgejo-installation/refs/heads/main/docker-compose.yml

# Port Configuration
port="${1:-3000}"
echo "$port" | grep -Eq '^[0-9]+$' || port=3000

if [ "$port" != "3000" ]; then
	sed -i -E "s/3000:3000/${port}:3000/g" docker-compose.yml
	echo "Port set to: $port"
fi

# CI/Runner selection
ci="${2:-n}"
runner=0
case "$ci" in
	[yY]|[yY][eE][sS]) runner=1 ;;
esac

if [ "$runner" -eq 0 ]; then
	awk 'BEGIN{skip=0} /^[[:space:]]*forgejo-runner:/{skip=1} /^[^[:space:]]/ && skip==1{skip=0} { if(!skip) print }' docker-compose.yml > tmp && mv tmp docker-compose.yml
	sed -i '/^[[:space:]]*runner-data:/d' docker-compose.yml
	sed -i '/^volumes:/d' docker-compose.yml

	[ -d "runner-data" ] && rm -rf runner-data
	docker volume rm $(docker volume ls -q | grep 'runner-data') >/dev/null 2>&1 || true
	echo "Runner removed"
fi

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
		echo "Updated: $image_prefix -> :$tag"
	else
		echo "Tag not found: $image_prefix" >&2
	fi
}

RUNNER_TAG=$(fetch_tag "https://data.forgejo.org/api/v1/repos/forgejo/runner/releases/latest")
update_image "data.forgejo.org/forgejo/runner" "$RUNNER_TAG"

SERVER_TAG=$(fetch_tag "https://codeberg.org/api/v1/repos/forgejo/forgejo/releases/latest")
update_image "codeberg.org/forgejo/forgejo" "$SERVER_TAG"

docker compose up -d

if [ "$runner" -eq 1 ]; then
	echo "Waiting, registering runner..."
	sleep 5
	if [ -f ../action_register.sh ]; then
		sh ../action_register.sh || echo "action_register.sh failed"
	else
		echo "../action_register.sh not found"
	fi
fi