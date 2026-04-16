#!/usr/bin/env bash
set -euo pipefail

ADMIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/admin_ui.sh
source "${ADMIN_DIR}/lib/admin_ui.sh"
# shellcheck source=lib/admin_common.sh
source "${ADMIN_DIR}/lib/admin_common.sh"

show_btrbk_snapshots() {
   local mounted_here=0
   local backup_info=()

   backup_info+=("btrbk | Snapshots de recovery")
   backup_info+=("")

   if mountpoint -q /mnt/backup; then
      backup_info+=("Estado: /mnt/backup ya estaba montada")
   else
      backup_info+=("Estado: montando /mnt/backup temporalmente...")
      if ! mount /mnt/backup 2>/dev/null; then
         backup_info+=("ERROR: no se pudo montar /mnt/backup")
         ui_show_text_box "btrbk | Snapshots" backup_info
         return 1
      fi
      mounted_here=1
   fi

   backup_info+=("")
   backup_info+=("============================================================")
   backup_info+=(" Snapshots en /mnt/backup/snapshots")
   backup_info+=("============================================================")
   backup_info+=("")

   if [[ -d /mnt/backup/snapshots ]]; then
      mapfile -t -O ${#backup_info[@]} backup_info < <(ls -lt /mnt/backup/snapshots)
   else
      backup_info+=("Directorio /mnt/backup/snapshots no encontrado")
   fi

   backup_info+=("")
   backup_info+=("============================================================")
   backup_info+=(" Uso de disco en /mnt/backup")
   backup_info+=("============================================================")
   backup_info+=("")
   mapfile -t -O ${#backup_info[@]} backup_info < <(df -h /mnt/backup)

   if [[ "$mounted_here" -eq 1 ]]; then
      umount /mnt/backup 2>/dev/null || true
      backup_info+=("")
      backup_info+=("Nota: /mnt/backup fue desmontada (montaje temporal limpiado)")
   fi

   ui_show_text_box "btrbk | Snapshots de recovery" backup_info
}

run_btrbk_now() {
   admin_run_report "btrbk | Ejecutar ahora" "$BTRBK_RUN_SCRIPT"
}

show_btrbk_config() {
   admin_run_report "btrbk | Configuracion" "$BTRBK_CONFIG_SCRIPT"
}

compare_btrbk_current() {
   local mounted_here=0
   local backup_lines=()
   local snapshot_name
   local selection_options=()

   if ! mountpoint -q /mnt/backup; then
      mount /mnt/backup
      mounted_here=1
   fi

   mapfile -t backup_lines < <(find /mnt/backup/snapshots -mindepth 1 -maxdepth 1 -printf '%f\n' 2>/dev/null | sort)

   if [[ "$mounted_here" -eq 1 ]]; then
      umount /mnt/backup || true
   fi

   if (( ${#backup_lines[@]} == 0 )); then
      ui_show_message "Comparar btrbk" "No se encontraron snapshots en /mnt/backup/snapshots."
      return 1
   fi

   selection_options=("${backup_lines[@]}" "Ingresar nombre manualmente" "Cancelar")
   ui_run_menu \
      "btrbk | Snapshots" \
      "Selecciona un snapshot" \
      selection_options \
      "Flechas: mover | ENTER: seleccionar | q/Esc: cancelar"

   if [[ "$UI_MENU_EVENT" == "QUIT" ]]; then
      return 1
   fi

   if [[ "$UI_MENU_SELECTED" -lt ${#backup_lines[@]} ]]; then
      snapshot_name="${backup_lines[$UI_MENU_SELECTED]}"
   elif [[ "$UI_MENU_SELECTED" -eq ${#backup_lines[@]} ]]; then
      snapshot_name="$(ui_prompt_input "Nombre del snapshot de btrbk" "")"
      if [[ -z "$snapshot_name" ]]; then
         ui_show_message "Comparar btrbk" "Operacion cancelada: falta nombre."
         return 1
      fi
   else
      return 1
   fi

   admin_run_report \
      "Comparar btrbk vs Actual" \
      "$SNAPSHOT_COMPARE_SCRIPT" --mode btrbk --backup-snapshot "$snapshot_name"
}

recovery_partition_menu() {
   local recovery_options=(
      "Ver estado actual"
      "Montar /mnt/backup"
      "Desmontar /mnt/backup"
      "Remontar /mnt/backup en solo lectura"
      "Remontar /mnt/backup en lectura-escritura"
      "Volver"
   )

   while true; do
      ui_run_menu \
         "Administracion | Recovery" \
         "Gestion manual de /mnt/backup" \
         recovery_options \
         "Flechas: mover | ENTER: ejecutar | q/Esc: volver"

      if [[ "$UI_MENU_EVENT" == "QUIT" ]]; then
         return 0
      fi

      case "$UI_MENU_SELECTED" in
         0) admin_run_report "Recovery | Status" "$RECOVERY_SCRIPT" status ;;
         1) admin_run_report "Recovery | Mount" "$RECOVERY_SCRIPT" mount ;;
         2) admin_run_report "Recovery | Unmount" "$RECOVERY_SCRIPT" umount ;;
         3) admin_run_report "Recovery | Read-Only" "$RECOVERY_SCRIPT" ro ;;
         4) admin_run_report "Recovery | Read-Write" "$RECOVERY_SCRIPT" rw ;;
         5) return 0 ;;
      esac
   done
}

btrbk_compare_menu() {
   local compare_options=(
      "Snapshot de recovery vs estado actual"
      "Volver"
   )

   while true; do
      ui_run_menu \
         "btrbk | Comparar" \
         "Elegir tipo de comparacion" \
         compare_options \
         "Flechas: mover | ENTER: ejecutar | q/Esc: volver"

      if [[ "$UI_MENU_EVENT" == "QUIT" ]]; then
         return 0
      fi

      case "$UI_MENU_SELECTED" in
         0) compare_btrbk_current || true ;;
         1) return 0 ;;
      esac
   done
}

admin_btrbk_main() {
   local btrbk_options=(
      "Configuracion actual"
      "Listado de ultimos snapshots"
      "Realizar snapshot ahora"
      "Gestion de particion recovery"
      "Comparar snapshots de recovery"
      "Volver"
   )

   while true; do
      ui_run_menu \
         "Administracion | btrbk" \
         "Herramientas de snapshots en recovery" \
         btrbk_options \
         "Flechas: mover | ENTER: ejecutar | q/Esc: volver"

      if [[ "$UI_MENU_EVENT" == "QUIT" ]]; then
         return 0
      fi

      case "$UI_MENU_SELECTED" in
         0) show_btrbk_config || true ;;
         1) show_btrbk_snapshots || true ;;
         2) run_btrbk_now || true ;;
         3) recovery_partition_menu || true ;;
         4) btrbk_compare_menu || true ;;
         5) return 0 ;;
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
   admin_btrbk_main
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
   main "$@"
fi
