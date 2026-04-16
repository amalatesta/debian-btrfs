#!/usr/bin/env bash
set -euo pipefail

ADMIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/admin_ui.sh
source "${ADMIN_DIR}/lib/admin_ui.sh"
# shellcheck source=lib/admin_common.sh
source "${ADMIN_DIR}/lib/admin_common.sh"
# shellcheck source=admin-snapper.sh
source "${ADMIN_DIR}/admin-snapper.sh"
# shellcheck source=admin-btrbk.sh
source "${ADMIN_DIR}/admin-btrbk.sh"
# shellcheck source=admin-grub-btrfs.sh
source "${ADMIN_DIR}/admin-grub-btrfs.sh"

LOCAL_HEALTH_SCRIPT="${ADMIN_DIR}/local-health-check.sh"

admin_tools_show_help() {
   local help_lines=(
      "Administracion modular para Snapper y btrbk con UI de repo."
      ""
      "Menu principal:"
      "- Informar estado actual"
   "- Estado general"
      "- Snapper (incluye export GOLDEN y comparaciones)"
      "- btrbk (incluye comparacion recovery vs actual)"
      "- grub-btrfs (menu GRUB, daemon, filtro, regeneracion)"
      "- Health check local (manual, estado rapido)"
      "- Setups (ejecutan fuera de UI y vuelven al menu)"
      "- Ayuda"
      ""
      "Dentro de Snapper:"
      "- Exportar snapshot a USB"
      "- Ver estado de exportacion USB"
      "- Restaurar desde USB (selectivo)"
      "- Marcar/liberar snapshots importantes (important=yes)"
      ""
      "Comparaciones disponibles:"
      "- Snapper local vs actual"
      "- Snapper entre dos snapshots"
      "- USB Btrfs vs actual"
      "- USB Stream (.btrfs-stream) vs actual"
      "- Recovery btrbk vs actual"
      ""
      "Dentro de grub-btrfs:"
      "- Estado del daemon"
      "- Snapshots visibles en GRUB"
      "- Regeneracion manual de GRUB"
      "- Configuracion y filtro .btrbk_snapshots"
   )
   ui_show_text_box "Ayuda | Administracion" help_lines
}

admin_tools_show_general_status() {
   local lines=()
   local snapper_count="0"
   local recovery_count="0"
   local golden_status="No verificado"
   local backup_mounted_here=0
   local usb_mounted_here=0
   local golden_device=""

   lines+=("Estado de componentes:")
   lines+=("")

   if command -v snapper >/dev/null 2>&1; then
      lines+=("Snapper           : instalado")
      snapper_count="$(snapper -c root list 2>/dev/null | awk 'NR>2 && NF {count++} END {print count+0}')"
      lines+=("Snapshots locales : $snapper_count")
   else
      lines+=("Snapper           : no instalado")
   fi

   if command -v btrbk >/dev/null 2>&1; then
      lines+=("btrbk             : instalado")
   else
      lines+=("btrbk             : no instalado")
   fi

   if systemctl is-enabled btrbk.timer >/dev/null 2>&1; then
      lines+=("btrbk.timer       : habilitado")
   else
      lines+=("btrbk.timer       : no habilitado")
   fi

   if systemctl is-active btrbk.timer >/dev/null 2>&1; then
      lines+=("btrbk.timer act.  : activo")
   else
      lines+=("btrbk.timer act.  : inactivo")
   fi

   if mountpoint -q /mnt/backup; then
      recovery_count="$(find /mnt/backup/snapshots -mindepth 1 -maxdepth 1 -name '@.*' 2>/dev/null | wc -l)"
   elif mount /mnt/backup >/dev/null 2>&1; then
      backup_mounted_here=1
      recovery_count="$(find /mnt/backup/snapshots -mindepth 1 -maxdepth 1 -name '@.*' 2>/dev/null | wc -l)"
   fi
   lines+=("Recovery snapshots: $recovery_count")

   if [[ "$backup_mounted_here" -eq 1 ]]; then
      umount /mnt/backup >/dev/null 2>&1 || true
   fi

   if [[ -f /etc/grub.d/41_snapshots-btrfs ]]; then
      lines+=("grub-btrfs        : instalado")
   else
      lines+=("grub-btrfs        : no instalado")
   fi

   if systemctl is-active grub-btrfsd >/dev/null 2>&1; then
      lines+=("grub-btrfsd       : activo")
   else
      lines+=("grub-btrfsd       : inactivo")
   fi

   lines+=("")
   lines+=("USB GOLDEN:")

   golden_device="$(admin_detect_golden_device 2>/dev/null || true)"
   mkdir -p /mnt/usb
   if [[ -z "$golden_device" ]]; then
      golden_status="USB no configurado o no detectable"
   elif mountpoint -q /mnt/usb || mount "$golden_device" /mnt/usb >/dev/null 2>&1; then
      if ! mountpoint -q /mnt/usb; then
         usb_mounted_here=1
      fi
      if [[ -d /mnt/usb/btrfs-streams ]] && find /mnt/usb/btrfs-streams -maxdepth 1 -name '*.btrfs-stream' | grep -q . 2>/dev/null; then
         golden_status="Presente (stream)"
      elif [[ -d /mnt/usb/snapshots ]] && find /mnt/usb/snapshots -mindepth 1 -maxdepth 1 | grep -q . 2>/dev/null; then
         golden_status="Presente (btrfs)"
      else
         golden_status="Sin copia detectada"
      fi
      if [[ "$usb_mounted_here" -eq 1 ]]; then
         umount /mnt/usb >/dev/null 2>&1 || true
      fi
   else
      golden_status="USB no accesible en ${golden_device}"
   fi

   lines+=("Dispositivo GOLDEN: ${golden_device:-sin definir}")
   lines+=("Estado GOLDEN     : $golden_status")
   lines+=("")
   lines+=("Tip: usa el submenus de Snapper, btrbk y grub-btrfs para detalle operativo.")

   ui_show_text_box "Estado general del sistema" lines
}

admin_tools_setup_menu() {
   local setup_options=(
      "Setup general"
      "Setup Snapper"
      "Setup btrbk"
      "Setup grub-btrfs"
      "Volver"
   )

   while true; do
      ui_run_menu \
         "Administracion | Setups" \
         "Ejecutar scripts de instalacion/configuracion fuera de la UI" \
         setup_options \
         "Flechas: mover | ENTER: ejecutar | q/Esc: volver"

      if [[ "$UI_MENU_EVENT" == "QUIT" ]]; then
         return 0
      fi

      case "$UI_MENU_SELECTED" in
         0) admin_run_external_setup "Setup general" "$SETUP_GENERAL_SCRIPT" || true ;;
         1) admin_run_external_setup "Setup Snapper" "$SETUP_SNAPPER_SCRIPT" || true ;;
         2) admin_run_external_setup "Setup btrbk" "$SETUP_BTRBK_SCRIPT" || true ;;
         3) admin_run_external_setup "Setup grub-btrfs" "$SETUP_GRUB_BTRFS_SCRIPT" || true ;;
         4) return 0 ;;
      esac
   done
}

admin_tools_run_local_health_check() {
   if [[ ! -x "$LOCAL_HEALTH_SCRIPT" ]]; then
      ui_show_message "Health Check" "No se encontro script ejecutable:\n$LOCAL_HEALTH_SCRIPT"
      return 1
   fi

   admin_run_report "Health Check Local" "$LOCAL_HEALTH_SCRIPT"
}

admin_tools_main_menu() {
   local main_options=(
      "Informar estado actual"
      "Estado general"
      "Snapper"
      "btrbk"
      "grub-btrfs"
      "Health check local"
      "Setups"
      "Ayuda"
      "Salir"
   )

   while true; do
      ui_run_menu \
         "Debian Pasos Btrfs | Administracion" \
         "Selecciona una herramienta administrativa" \
         main_options \
         "Flechas: mover | ENTER: ejecutar | q/Esc: salir"

      if [[ "$UI_MENU_EVENT" == "QUIT" ]]; then
         break
      fi

      case "$UI_MENU_SELECTED" in
         0) admin_show_boot_context || true ;;
         1) admin_tools_show_general_status || true ;;
         2) admin_snapper_main || true ;;
         3) admin_btrbk_main || true ;;
         4) admin_grub_btrfs_main || true ;;
         5) admin_tools_run_local_health_check || true ;;
         6) admin_tools_setup_menu || true ;;
         7) admin_tools_show_help || true ;;
         8) break ;;
      esac
   done
}

main() {
   ui_require_tty
   admin_require_root
   admin_require_scripts
   ui_init_theme
   ui_setup_terminal
   trap ui_cleanup EXIT INT TERM
   admin_tools_main_menu
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
   main "$@"
fi
