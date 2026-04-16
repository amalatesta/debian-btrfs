#!/usr/bin/env bash
set -euo pipefail

ADMIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/admin_ui.sh
source "${ADMIN_DIR}/lib/admin_ui.sh"
# shellcheck source=lib/admin_common.sh
source "${ADMIN_DIR}/lib/admin_common.sh"

require_grub_btrfs() {
   if ! command -v grub-btrfs >/dev/null 2>&1 && [[ ! -f /etc/grub.d/41_snapshots-btrfs ]]; then
      ui_show_message "grub-btrfs" "grub-btrfs no esta instalado o no se detecto /etc/grub.d/41_snapshots-btrfs."
      return 1
   fi
   return 0
}

show_grub_btrfs_daemon_status() {
   local lines=()

   if systemctl is-enabled grub-btrfsd >/dev/null 2>&1; then
      lines+=("Habilitado : si")
   else
      lines+=("Habilitado : no")
   fi

   if systemctl is-active grub-btrfsd >/dev/null 2>&1; then
      lines+=("Activo     : si")
   else
      lines+=("Activo     : no")
   fi

   lines+=("")
   mapfile -t -O ${#lines[@]} lines < <(systemctl status grub-btrfsd --no-pager 2>&1 | head -20)
   ui_show_text_box "grub-btrfs | Estado daemon" lines
}

show_grub_snapshots_in_menu() {
   local lines=()
   local grub_cfg="/boot/grub/grub-btrfs.cfg"
   local count=0
   local snapshot_ids=()
   local raw_id raw_date raw_type raw_desc raw_userdata
   local idx snap_id
   declare -A snap_date=()
   declare -A snap_type=()
   declare -A snap_desc=()
   declare -A snap_imp=()

   if [[ ! -f "$grub_cfg" ]]; then
      ui_show_message "grub-btrfs" "No se encontro $grub_cfg. Regenera GRUB primero."
      return 1
   fi

   mapfile -t snapshot_ids < <(
      grep -oE '@/\.snapshots/[0-9]+/snapshot' "$grub_cfg" 2>/dev/null |
         sed -E 's#@/\.snapshots/([0-9]+)/snapshot#\1#' |
         sort -n -u
   )

   while IFS='|' read -r raw_id raw_date raw_type raw_desc raw_userdata; do
      [[ -z "$raw_id" ]] && continue
      snap_date["$raw_id"]="$raw_date"
      snap_type["$raw_id"]="$raw_type"
      snap_desc["$raw_id"]="$raw_desc"
      if [[ "$raw_userdata" == *"important=yes"* ]]; then
         snap_imp["$raw_id"]="Y"
      else
         snap_imp["$raw_id"]="N"
      fi
   done < <(
      snapper -c root list 2>/dev/null |
         awk -F'|' '
            NR > 2 {
               id = $1; type = $2; date = $4; desc = $7; userdata = $8;
               gsub(/^[ \t]+|[ \t]+$/, "", id);
               gsub(/^[ \t]+|[ \t]+$/, "", type);
               gsub(/^[ \t]+|[ \t]+$/, "", date);
               gsub(/^[ \t]+|[ \t]+$/, "", desc);
               gsub(/^[ \t]+|[ \t]+$/, "", userdata);
               if (id ~ /^[0-9]+$/) {
                  print id "|" date "|" type "|" desc "|" userdata;
               }
            }
         '
   )

   count="${#snapshot_ids[@]}"
   lines+=("Total de snapshots en menu: $count")
   lines+=("")
   lines+=("Snapshots detectados:")
   lines+=("N | ID  | Imp | Fecha | Tipo | Descripcion")
   if (( count > 0 )); then
      for idx in "${!snapshot_ids[@]}"; do
         snap_id="${snapshot_ids[$idx]}"
         if [[ -n "${snap_date[$snap_id]:-}" ]]; then
            lines+=("$((idx + 1)) | #$snap_id | ${snap_imp[$snap_id]:-N} | ${snap_date[$snap_id]} | ${snap_type[$snap_id]} | ${snap_desc[$snap_id]:-(sin descripcion)}")
         else
            lines+=("$((idx + 1)) | #$snap_id | ? | (sin metadata local en snapper)")
         fi
      done
   else
      lines+=("(sin snapshots de Snapper detectados en grub-btrfs.cfg)")
   fi
   lines+=("")
   if grep -q '.btrbk_snapshots' "$grub_cfg" 2>/dev/null; then
      lines+=("Filtro .btrbk_snapshots: ERROR, hay referencias")
   else
      lines+=("Filtro .btrbk_snapshots: OK, no hay referencias")
   fi

   ui_show_text_box "grub-btrfs | Snapshots en GRUB" lines
}

regenerate_grub_config() {
   local confirm_options=(
      "Confirmar y regenerar"
      "Cancelar"
   )

   ui_run_menu \
      "grub-btrfs | Regenerar GRUB" \
      "Regenerar /boot/grub/grub.cfg manualmente" \
      confirm_options \
      "Flechas: mover | ENTER: confirmar | q/Esc: cancelar"

   if [[ "$UI_MENU_EVENT" == "QUIT" || "$UI_MENU_SELECTED" -eq 1 ]]; then
      return 1
   fi

   admin_run_report "grub-btrfs | Regenerar GRUB" grub-mkconfig -o /boot/grub/grub.cfg
}

show_grub_btrfs_config() {
   local config_file="/etc/default/grub-btrfs/config"
   local lines=()

   if [[ ! -f "$config_file" ]]; then
      ui_show_message "grub-btrfs" "No se encontro $config_file"
      return 1
   fi

   mapfile -t lines < "$config_file"
   ui_show_text_box "grub-btrfs | Configuracion" lines
}

edit_grub_btrfs_config() {
   local config_file="/etc/default/grub-btrfs/config"
   local editor_cmd

   if [[ ! -f "$config_file" ]]; then
      ui_show_message "grub-btrfs" "No se encontro $config_file"
      return 1
   fi

   editor_cmd="${EDITOR:-nano}"
   ui_restore_terminal
   clear > /dev/tty
   "$editor_cmd" "$config_file" < /dev/tty > /dev/tty
   ui_setup_terminal
   ui_show_message "grub-btrfs" "Configuracion guardada. Si cambiaste algo relevante, regenera GRUB."
}

show_grub_filter_info() {
   local lines=(
      "El filtro GRUB_BTRFS_IGNORE_PREFIX_PATH oculta snapshots tecnicos."
      ""
      "Snapper visible:"
      "- Ubicacion: @/.snapshots/N/snapshot"
      "- Aparece en submenu Debian snapshots"
      ""
      "btrbk oculto:"
      "- Ubicacion local: @/.btrbk_snapshots/..."
      "- Replicado: /mnt/backup/snapshots/@.DATETIME"
      "- No debe aparecer en Debian snapshots"
      ""
      "Si agregas otras carpetas tecnicas, sumalas al filtro."
   )
   ui_show_text_box "grub-btrfs | Filtro .btrbk_snapshots" lines
}

restart_grub_btrfs_daemon() {
   local confirm_options=(
      "Confirmar reinicio"
      "Cancelar"
   )

   ui_run_menu \
      "grub-btrfs | Reiniciar daemon" \
      "Reiniciar grub-btrfsd" \
      confirm_options \
      "Flechas: mover | ENTER: confirmar | q/Esc: cancelar"

   if [[ "$UI_MENU_EVENT" == "QUIT" || "$UI_MENU_SELECTED" -eq 1 ]]; then
      return 1
   fi

   admin_run_report "grub-btrfs | Reiniciar daemon" systemctl restart grub-btrfsd
}

admin_grub_btrfs_main() {
   local options=(
      "Ver estado del daemon grub-btrfsd"
      "Ver snapshots listados en GRUB"
      "Regenerar configuracion GRUB manualmente"
      "Ver configuracion actual"
      "Editar configuracion"
      "Info: filtro .btrbk_snapshots"
      "Reiniciar daemon grub-btrfsd"
      "Volver"
   )

   if ! require_grub_btrfs; then
      return 1
   fi

   while true; do
      ui_run_menu \
         "Administracion | grub-btrfs" \
         "Herramientas de integracion con menu GRUB" \
         options \
         "Flechas: mover | ENTER: ejecutar | q/Esc: volver"

      if [[ "$UI_MENU_EVENT" == "QUIT" ]]; then
         return 0
      fi

      case "$UI_MENU_SELECTED" in
         0) show_grub_btrfs_daemon_status || true ;;
         1) show_grub_snapshots_in_menu || true ;;
         2) regenerate_grub_config || true ;;
         3) show_grub_btrfs_config || true ;;
         4) edit_grub_btrfs_config || true ;;
         5) show_grub_filter_info || true ;;
         6) restart_grub_btrfs_daemon || true ;;
         7) return 0 ;;
      esac
   done
}

main() {
   ui_require_tty
   admin_require_root
   ui_init_theme
   ui_setup_terminal
   trap ui_cleanup EXIT INT TERM
   admin_grub_btrfs_main
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
   main "$@"
fi
