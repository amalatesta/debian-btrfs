#!/usr/bin/env bash

ADMIN_ACTIONS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADMIN_UTIL_DIR="$(cd "${ADMIN_ACTIONS_DIR}/.." && pwd)"

BOOT_CONTEXT_SCRIPT="${ADMIN_UTIL_DIR}/show-boot-context.sh"
BACKUP_HEALTH_SCRIPT="${ADMIN_UTIL_DIR}/backup-health-report.sh"
BTRBK_RUN_SCRIPT="${ADMIN_UTIL_DIR}/btrbk-run-now.sh"
RECOVERY_SCRIPT="${ADMIN_UTIL_DIR}/recovery-partition.sh"
USB_GOLDEN_SCRIPT="${ADMIN_UTIL_DIR}/usb-golden-snapshot.sh"
UTIL_README_FILE="${ADMIN_UTIL_DIR}/README.md"

admin_require_root() {
   if [[ "${EUID}" -ne 0 ]]; then
      echo "ERROR: ejecutar con sudo: sudo ${ADMIN_UTIL_DIR}/admin-tools.sh"
      exit 1
   fi
}

admin_require_scripts() {
   local missing=0
   local file

   for file in "$BOOT_CONTEXT_SCRIPT" "$BACKUP_HEALTH_SCRIPT" "$BTRBK_RUN_SCRIPT" "$RECOVERY_SCRIPT" "$USB_GOLDEN_SCRIPT"; do
      if [[ ! -x "$file" ]]; then
         echo "Falta script ejecutable: $file"
         missing=1
      fi
   done

   if [[ "$missing" -ne 0 ]]; then
      exit 1
   fi
}

admin_run_report() {
   local title="$1"
   shift
   local log_file rc lines=()

   log_file="$(mktemp)"
   "$@" >"$log_file" 2>&1
   rc=$?

   mapfile -t lines < "$log_file"
   rm -f "$log_file"

   if (( ${#lines[@]} == 0 )); then
      lines=("Sin salida generada.")
   fi

   if [[ "$rc" -eq 0 ]]; then
      lines=("Resultado: OK" "" "${lines[@]}")
   else
      lines=("Resultado: ERROR (codigo $rc)" "" "${lines[@]}")
   fi

   ui_show_text_box "$title" lines
   return "$rc"
}

admin_show_boot_context() {
   admin_run_report "Boot Context" "$BOOT_CONTEXT_SCRIPT"
}

admin_show_backup_health() {
   admin_run_report "Backup Health Report" "$BACKUP_HEALTH_SCRIPT"
}

admin_run_btrbk_now() {
   admin_run_report "btrbk.service" "$BTRBK_RUN_SCRIPT"
}

admin_recovery_partition_menu() {
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
         "Admin Tools | Recovery" \
         "Gestion manual de la particion de recovery" \
         recovery_options \
         "Flechas: mover | ENTER: ejecutar | q/Esc: volver"

      if [[ "$UI_MENU_EVENT" == "QUIT" ]]; then
         return 0
      fi

      case "$UI_MENU_SELECTED" in
         0) admin_run_report "Recovery Status" "$RECOVERY_SCRIPT" status ;;
         1) admin_run_report "Mount Recovery" "$RECOVERY_SCRIPT" mount ;;
         2) admin_run_report "Unmount Recovery" "$RECOVERY_SCRIPT" umount ;;
         3) admin_run_report "Recovery Read-Only" "$RECOVERY_SCRIPT" ro ;;
         4) admin_run_report "Recovery Read-Write" "$RECOVERY_SCRIPT" rw ;;
         5) return 0 ;;
      esac
   done
}

admin_usb_golden_export() {
   local lsblk_lines=()
   local device mode cleanup_choice description name cmd=()
   local mode_options=(
      "Auto detectar filesystem del USB"
      "Forzar Btrfs (send/receive)"
      "Forzar stream portable (.btrfs-stream)"
      "Cancelar"
   )
   local cleanup_options=(
      "Conservar export local en /golden-exports"
      "Borrar export local al finalizar"
      "Cancelar"
   )

   mapfile -t lsblk_lines < <(lsblk -o NAME,MODEL,TRAN,SIZE,FSTYPE,MOUNTPOINTS,RM -e 7)
   ui_show_text_box "USB Detectados" lsblk_lines "Revisar dispositivo y luego ENTER"

   device="$(ui_prompt_input "Particion USB a usar (ejemplo: /dev/sdb1)" "/dev/sdX1")"
   if [[ -z "$device" || "$device" == "/dev/sdX1" ]]; then
      ui_show_message "USB Golden" "Operacion cancelada: falta dispositivo real."
      return 1
   fi

   ui_run_menu \
      "USB Golden | Modo" \
      "Elegir modo de exportacion" \
      mode_options \
      "Flechas: mover | ENTER: confirmar | q/Esc: cancelar"

   if [[ "$UI_MENU_EVENT" == "QUIT" ]]; then
      return 1
   fi

   case "$UI_MENU_SELECTED" in
      0) mode="auto" ;;
      1) mode="btrfs" ;;
      2) mode="stream" ;;
      *) return 1 ;;
   esac

   description="$(ui_prompt_input "Descripcion snapper" "GOLDEN antes de cambios")"
   name="$(ui_prompt_input "Nombre de exportacion" "golden-$(date +%Y%m%d-%H%M)")"

   ui_run_menu \
      "USB Golden | Export local" \
      "Que hacer con /golden-exports/<nombre> al terminar" \
      cleanup_options \
      "Flechas: mover | ENTER: confirmar | q/Esc: cancelar"

   if [[ "$UI_MENU_EVENT" == "QUIT" ]]; then
      return 1
   fi

   case "$UI_MENU_SELECTED" in
      0) cleanup_choice="keep" ;;
      1) cleanup_choice="delete" ;;
      *) return 1 ;;
   esac

   cmd=("$USB_GOLDEN_SCRIPT" "--device" "$device" "--mode" "$mode" "--description" "$description" "--name" "$name")
   if [[ "$cleanup_choice" == "delete" ]]; then
      cmd+=("--cleanup-local-export")
   fi

   admin_run_report "USB Golden Export" "${cmd[@]}"
}

admin_show_help() {
   local help_lines=(
      "Admin Tools centraliza los utilitarios de mantenimiento del proyecto."
      ""
      "Acciones disponibles:"
      "- Ver contexto de arranque"
      "- Generar reporte de salud Snapper + btrbk"
      "- Ejecutar btrbk.service en el flujo seguro"
      "- Gestionar /mnt/backup manualmente"
      "- Exportar snapshot GOLDEN a USB"
      "- Ver este README tecnico dentro de la UI"
      ""
      "Diseno modular:"
      "- admin-tools.sh: launcher y menu principal"
      "- lib/admin_ui.sh: motor de interfaz tput"
      "- lib/admin_actions.sh: acciones que llaman a utilitarios"
      "- utilitarios/*.sh: scripts ejecutores reales"
      ""
      "Recomendacion: ejecutar siempre como root con sudo."
   )

   ui_show_text_box "Ayuda | Admin Tools" help_lines
}

admin_show_utilitarios_readme() {
   local readme_lines=()

   if [[ ! -f "$UTIL_README_FILE" ]]; then
      ui_show_message "README | Utilitarios" "No se encontro: $UTIL_README_FILE"
      return 1
   fi

   mapfile -t readme_lines < "$UTIL_README_FILE"
   ui_show_text_box "README | Utilitarios" readme_lines
}
