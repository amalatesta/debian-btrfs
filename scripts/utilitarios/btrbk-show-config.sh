#!/usr/bin/env bash
set -u

BTRBK_CONFIG="/etc/btrbk/btrbk.conf"

if [[ ! -f "$BTRBK_CONFIG" ]]; then
   echo "ERROR: No se encontró configuracion de Btrbk: $BTRBK_CONFIG"
   exit 1
fi

echo "============================================================"
echo " Configuracion de Btrbk (Snapshots en recovery)"
echo "============================================================"
echo

echo "VOLUMEN ORIGEN:"
echo "  Subvolumen: @"
echo "  Ruta: /mnt/btrfs-root/@"
echo

echo "DESTINO DE BACKUPS:"
echo "  Particion: /mnt/backup (recovery partition)"
echo "  Ruta de almacenamiento: /mnt/backup/snapshots/"
echo "  Estado de montaje: noauto (solo monta cuando es necesario)"
echo

echo "FORMATO DE NOMBRES:"
grep "^snapshot_name_format" "$BTRBK_CONFIG" || echo "  Formato: @.YYYYMMDDTHHMMSS"
echo

echo "DISPARADORES DE BACKUPS:"
echo "  1. Snapshots manuales (durante sesion interactiva)"
echo "  2. Post APT (despues de actualizaciones exitosas)"
echo "    Archivo: /etc/apt/apt.conf.d/81btrbk-trigger"
if [[ -f /etc/apt/apt.conf.d/81btrbk-trigger ]]; then
   echo "    Estado: ACTIVO"
else
   echo "    Estado: INACTIVO"
fi
echo "  3. Timer diario (respaldo periodico)"
systemctl is-active btrbk.timer >/dev/null 2>&1 \
   && echo "    btrbk.timer: ACTIVO" \
   || echo "    btrbk.timer: INACTIVO"
echo

echo "POLITICA DE RETENCION:"
grep "^snapshot_preserve\|^target_preserve" "$BTRBK_CONFIG"
echo

echo "CONFIGURACION DE COMPRESION:"
grep "^stream_compress" "$BTRBK_CONFIG" || echo "  stream_compress: zstd"
echo

echo "ESTADO DE LA PARTICION RECOVERY:"
if mountpoint -q /mnt/backup; then
   echo "  /mnt/backup: MONTADA"
   df -h /mnt/backup | tail -1
else
   echo "  /mnt/backup: DESMONTADA (protegida)"
fi
echo

echo "ULTIMOS SNAPSHOTS EN RECOVERY:"
mounted_here=0
if ! mountpoint -q /mnt/backup; then
   mount /mnt/backup 2>/dev/null || true
   mounted_here=1
fi

if mountpoint -q /mnt/backup && [[ -d /mnt/backup/snapshots ]]; then
   ls -lt /mnt/backup/snapshots 2>/dev/null | head -5 || echo "  (sin snapshots aun)"
else
   echo "  (no se pudo acceder a /mnt/backup/snapshots)"
fi

if [[ "$mounted_here" -eq 1 ]]; then
   umount /mnt/backup 2>/dev/null || true
fi
echo
