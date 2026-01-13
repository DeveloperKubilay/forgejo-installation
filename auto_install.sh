#!/bin/sh
set -e


run_remote() {
  url="$1"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" | sh -s --
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$url" | sh -s --
  else
    echo "curl veya wget bulunamadı. Önce curl ya da wget kur." >&2
    return 1
  fi
}

run_remote "https://raw.githubusercontent.com/DeveloperKubilay/forgejo-installation/refs/heads/main/install_docker.sh"
run_remote "https://raw.githubusercontent.com/DeveloperKubilay/forgejo-installation/refs/heads/main/run_docker.sh"

echo "Hepsi bitti."
echo "Tarayıcında http://localhost:3000 adresine git ve Forgejo kurulumunu tamamla.\n"
echo "Docker'i çalıştırmak istersen komut: docker compose up -d"
echo "Docker konteynerlerini durdurmak istersen komut: docker compose down"