#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  exec sudo "$0" "$@"
fi

if command -v snapcfg >/dev/null 2>&1; then
  snapcfg "Baseline antes de instalar KDE Plasma" --replicate
fi

echo 'sddm shared/default-x-display-manager select sddm' | debconf-set-selections
DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends kde-plasma-desktop sddm

systemctl enable sddm
systemctl set-default graphical.target

echo
echo 'Instalacion base completada.'
echo 'Siguientes pasos:'
echo '  1. Reiniciar la VM'
echo '  2. Iniciar sesion en KDE Plasma'
echo '  3. Aplicar los ajustes visuales de escritorios/KDE_Windows/README.md'