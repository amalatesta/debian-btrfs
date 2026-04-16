#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADMIN_STATE_FILE="${SCRIPT_DIR}/.admin-tools.conf"

status_ok=0
status_warn=0
status_fail=0

declare -a lines=()

add_ok() {
   lines+=("[OK]   $1")
   status_ok=$((status_ok + 1))
}

add_warn() {
   lines+=("[WARN] $1")
   status_warn=$((status_warn + 1))
}

add_fail() {
   lines+=("[FAIL] $1")
   status_fail=$((status_fail + 1))
}

count_snapshots_local() {
   snapper -c root list 2>/dev/null |
      awk -F'|' 'NR>2{gsub(/^[ \t]+|[ \t]+$/, "", $1); if($1 ~ /^[0-9]+$/) c++} END{print c+0}'
}

count_snapshots_important() {
   snapper -c root list 2>/dev/null |
      awk -F'|' 'NR>2{u=$8; gsub(/^[ \t]+|[ \t]+$/, "", u); if(u ~ /important=yes/) c++} END{print c+0}'
}

count_snapshots_in_grub() {
   if [[ ! -f /boot/grub/grub-btrfs.cfg ]]; then
      echo 0
      return
   fi

   grep -oE '@/\.snapshots/[0-9]+/snapshot' /boot/grub/grub-btrfs.cfg 2>/dev/null |
      sed -E 's#@/\.snapshots/([0-9]+)/snapshot#\1#' |
      sort -n -u |
      wc -l
}

lines+=("Health Check Local | $(date '+%Y-%m-%d %H:%M:%S')")
lines+=("")

if command -v snapper >/dev/null 2>&1; then
   local_count="$(count_snapshots_local || echo 0)"
   important_count="$(count_snapshots_important || echo 0)"
   add_ok "Snapper disponible | snapshots locales=$local_count | importantes=$important_count"
else
   add_fail "Snapper no disponible"
fi

if command -v btrbk >/dev/null 2>&1; then
   add_ok "btrbk disponible"
else
   add_warn "btrbk no disponible"
fi

if systemctl is-enabled btrbk.timer >/dev/null 2>&1; then
   add_ok "btrbk.timer habilitado"
else
   add_warn "btrbk.timer no habilitado"
fi

if systemctl is-active btrbk.timer >/dev/null 2>&1; then
   add_ok "btrbk.timer activo"
else
   add_warn "btrbk.timer inactivo"
fi

if systemctl is-active grub-btrfsd >/dev/null 2>&1; then
   add_ok "grub-btrfsd activo"
else
   add_warn "grub-btrfsd inactivo"
fi

grub_limit="$(awk -F'=' '/^GRUB_BTRFS_LIMIT=/{gsub(/"/,"",$2); print $2}' /etc/default/grub-btrfs/config 2>/dev/null | tail -1)"
if [[ -n "$grub_limit" ]]; then
   add_ok "GRUB_BTRFS_LIMIT configurado en $grub_limit"
else
   add_warn "No se pudo leer GRUB_BTRFS_LIMIT"
fi

grub_count="$(count_snapshots_in_grub || echo 0)"
if [[ "${local_count:-0}" =~ ^[0-9]+$ ]] && [[ "$grub_count" =~ ^[0-9]+$ ]]; then
   add_ok "Snapshots visibles en GRUB=$grub_count"
   if (( local_count > 0 && grub_count == 0 )); then
      add_warn "Hay snapshots locales pero no aparecen en GRUB"
   fi
fi

root_avail_pct="$(df -P / | awk 'NR==2{gsub(/%/,"",$5); print 100-$5}')"
if [[ "$root_avail_pct" =~ ^[0-9]+$ ]]; then
   if (( root_avail_pct < 10 )); then
      add_fail "Espacio libre en / critico (${root_avail_pct}%)"
   elif (( root_avail_pct < 20 )); then
      add_warn "Espacio libre en / bajo (${root_avail_pct}%)"
   else
      add_ok "Espacio libre en / adecuado (${root_avail_pct}%)"
   fi
fi

golden_device=""
if [[ -f "$ADMIN_STATE_FILE" ]]; then
   golden_device="$(awk -F= '/^GOLDEN_USB_DEVICE=/{print $2}' "$ADMIN_STATE_FILE" | tail -1)"
fi

if [[ -n "$golden_device" ]]; then
   if [[ -b "$golden_device" ]]; then
      add_ok "Dispositivo USB GOLDEN configurado y presente ($golden_device)"
   else
      add_warn "Dispositivo USB GOLDEN configurado pero ausente ($golden_device)"
   fi
else
   add_warn "Sin dispositivo USB GOLDEN configurado"
fi

lines+=("")
lines+=("Resumen:")
lines+=("- OK   : $status_ok")
lines+=("- WARN : $status_warn")
lines+=("- FAIL : $status_fail")

printf '%s\n' "${lines[@]}"

if (( status_fail > 0 )); then
   exit 2
fi
if (( status_warn > 0 )); then
   exit 1
fi
exit 0
