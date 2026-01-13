#!/bin/sh
set -e
cd .. && mkdir -p forgejo && cd forgejo

wget https://raw.githubusercontent.com/DeveloperKubilay/forgejo-installation/refs/heads/main/docker-compose.yml

# Allow port override via arg or env var
PORT_ARG="$1"
if [ -n "$PORT_ARG" ]; then
	PORT="$PORT_ARG"
fi
PORT="${PORT:-3000}"
if ! echo "$PORT" | grep -Eq '^[0-9]+$'; then
	PORT=3000
fi
if [ "$PORT" != "3000" ]; then
	sed -i -E "s/3000:3000/${PORT}:3000/g" docker-compose.yml || true
	echo "Host HTTP port set to: $PORT"
fi

# CI/Actions choice: second arg (y/n)
CI_ARG="$2"
CI_ARG="${CI_ARG:-n}"
CI_ARG_LOWER=$(echo "$CI_ARG" | tr '[:upper:]' '[:lower:]')
if [ "$CI_ARG_LOWER" != "y" ] && [ "$CI_ARG_LOWER" != "yes" ]; then
	# remove the forgejo-runner service block from docker-compose.yml
	awk 'BEGIN{skip=0} /^  forgejo-runner:/{skip=1} /^volumes:/{if(skip){skip=0}} {if(!skip) print}' docker-compose.yml > docker-compose.tmp && mv docker-compose.tmp docker-compose.yml
	echo "Runner service removed from docker-compose.yml"
	# remove trailing top-level volumes: block (runner-data) if present
	awk 'BEGIN{skip=0} /^volumes:$/ {skip=1; next} { if(skip){ if($0 ~ /^[^[:space:]]/){ skip=0; print } } else print }' docker-compose.yml > docker-compose.tmp && mv docker-compose.tmp docker-compose.yml || true
	# remove local runner-data dir if created
	if [ -d "runner-data" ]; then
		rm -rf runner-data
		echo "Removed local runner-data directory"
	fi
	# remove any dangling docker volume named runner-data
	if command -v docker >/dev/null 2>&1; then
		VOL_TO_RM=$(docker volume ls -q | grep 'runner-data' || true)
		if [ -n "$VOL_TO_RM" ]; then
			echo "$VOL_TO_RM" | xargs -r docker volume rm || true
			echo "Removed docker volume(s): $VOL_TO_RM"
		fi
	fi
	RUNNER_WANTED=0
else
	RUNNER_WANTED=1
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

if [ "${RUNNER_WANTED:-0}" -eq 1 ]; then
		echo "Waiting, registering runner..."
	sleep 5
	if [ -f ../action_register.sh ]; then
			sh ../action_register.sh || echo "action_register.sh failed to run"
	else
			echo "../action_register.sh not found; runner registration must be done manually"
	fi
fi