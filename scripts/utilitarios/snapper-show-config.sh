#!/usr/bin/env bash
set -u

SNAPPER_CONFIG="/etc/snapper/configs/root"

if [[ ! -f "$SNAPPER_CONFIG" ]]; then
   echo "ERROR: No se encontró configuracion de Snapper: $SNAPPER_CONFIG"
   exit 1
fi

echo "============================================================"
echo " Configuracion de Snapper (Snapshots locales)"
echo "============================================================"
echo

echo "VOLUMEN ASIGNADO:"
grep "^SUBVOLUME=" "$SNAPPER_CONFIG" || echo "  SUBVOLUME: /"
echo

echo "ALMACENAMIENTO:"
grep "^SNAPSHOT_READ_ONLY=" "$SNAPPER_CONFIG" || echo "  SNAPSHOT_READ_ONLY: yes"
echo "  Ruta de almacenamiento: /.snapshots/"
echo

echo "DISPARADORES DE SNAPSHOTS:"
echo "  1. Snapshots manuales (comando: snapper -c root create)"
echo "  2. Pre/Post APT (antes y despues de actualizaciones)"
echo "    Archivo: /etc/apt/apt.conf.d/80snapper"
if [[ -f /etc/apt/apt.conf.d/80snapper ]]; then
   echo "    Estado: ACTIVO"
else
   echo "    Estado: INACTIVO"
fi
echo

echo "LIMPIEZA AUTOMATICA:"
systemctl is-active snapper-cleanup.timer >/dev/null 2>&1 \
   && echo "  snapper-cleanup.timer: ACTIVO" \
   || echo "  snapper-cleanup.timer: INACTIVO"
echo

echo "LIMITES DE RETENCION:"
grep "^NUMBER_LIMIT" "$SNAPPER_CONFIG" | head -2
echo

echo "ULTIMOS SNAPSHOTS LOCALES:"
snapper -c root list | tail -5
echo
