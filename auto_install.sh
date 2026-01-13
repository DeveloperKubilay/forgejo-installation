mkdir forgejo-installation
cd forgejo-installation

wget "https://raw.githubusercontent.com/DeveloperKubilay/forgejo-installation/refs/heads/main/install_docker.sh"
wget "https://raw.githubusercontent.com/DeveloperKubilay/forgejo-installation/refs/heads/main/run_docker.sh"

sh install_docker.sh

echo "Which port do you want? (default 3000, press Enter to use default)"
read port
if [ -z "$port" ]; then
  port=3000
fi

echo "Install Actions CI/Runner? (y/n, default n)"
read ci_choice
if [ -z "$ci_choice" ]; then
  ci_choice="n"
fi

sh run_docker.sh "$port" "$ci_choice"

cd ..
rm -rf forgejo-installation

localip=$(hostname -I 2>/dev/null | awk '{print $1}')
ip=$(curl -fsS https://ifconfig.me 2>/dev/null || echo "")

cat <<EOF
Done.
Open in your browser and finish Forgejo setup.
Local URL address: http://$localip:$port
Public URL address: http://$ip:$port
Commands:
  docker compose up -d    # start
  docker compose down     # stop
EOF