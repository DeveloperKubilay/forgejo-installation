mkdir forgejo-installation
cd forgejo-installation

wget "https://raw.githubusercontent.com/DeveloperKubilay/forgejo-installation/refs/heads/main/install_docker.sh"
wget "https://raw.githubusercontent.com/DeveloperKubilay/forgejo-installation/refs/heads/main/run_docker.sh"

sh install_docker.sh
sh run_docker.sh

cd ..
rm -rf forgejo-installation

cat <<'EOF'
Done.
Open http://localhost:3000 in your browser and finish Forgejo setup.
Commands:
  docker compose up -d    # start
  docker compose down     # stop
EOF