mkdir -p forgejo-installation
cd forgejo-installation

wget "https://raw.githubusercontent.com/DeveloperKubilay/forgejo-installation/refs/heads/main/install_docker.sh"
wget "https://raw.githubusercontent.com/DeveloperKubilay/forgejo-installation/refs/heads/main/run_docker.sh"
wget "https://raw.githubusercontent.com/DeveloperKubilay/forgejo-installation/refs/heads/main/action_register.sh"

sed -i 's/\r$//' install_docker.sh
sed -i 's/\r$//' run_docker.sh
sed -i 's/\r$//' action_register.sh

bash install_docker.sh

prompt() {
  msg="$1"
  def="$2"
  if [ -t 0 ]; then
    printf "%s" "$msg"
    read ans
  elif [ -e /dev/tty ]; then
    printf "%s" "$msg" > /dev/tty
    read ans < /dev/tty
  else
    echo "No interactive terminal available. Run the script interactively." >&2
    exit 1
  fi
  if [ -z "$ans" ]; then
    ans="$def"
  fi
  echo "$ans"
}

port=$(prompt "Which port do you want? (default 3000, press Enter to use default) " 3000)
ci_choice=$(prompt "Install type? (server/runner/both, default both) " both)

if [ "$ci_choice" = "both" ]; then ci_choice="y"; fi
if [ "$ci_choice" = "server" ]; then ci_choice="n"; fi
if [ "$ci_choice" = "runner" ]; then ci_choice="only"; fi

bash run_docker.sh "$port" "$ci_choice"

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

if [ "$ci_choice" = "y" ] || [ "$ci_choice" = "Y" ] || [ "$ci_choice" = "only" ]; then
  echo ""
  echo "Starting runner registration..."
  cat <<EOF
You can obtain the registration token from:
Local URL: http://$localip:$port/user/settings/actions/runners
Public URL: http://$ip:$port/user/settings/actions/runners

The registration script will run now.
EOF
  bash action_register.sh </dev/tty >/dev/tty
fi

cd ..
rm -rf forgejo-installation

echo "Installation script finished."