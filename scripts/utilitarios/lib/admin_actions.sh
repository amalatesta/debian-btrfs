#!/usr/bin/env bash

ADMIN_ACTIONS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADMIN_UTIL_DIR="$(cd "${ADMIN_ACTIONS_DIR}/.." && pwd)"

BOOT_CONTEXT_SCRIPT="${ADMIN_UTIL_DIR}/show-boot-context.sh"
BACKUP_HEALTH_SCRIPT="${ADMIN_UTIL_DIR}/backup-health-report.sh"
SNAPPER_RUN_SCRIPT="${ADMIN_UTIL_DIR}/snapper-run-now.sh"
SNAPPER_CONFIG_SCRIPT="${ADMIN_UTIL_DIR}/snapper-show-config.sh"
BTRBK_RUN_SCRIPT="${ADMIN_UTIL_DIR}/btrbk-run-now.sh"
BTRBK_CONFIG_SCRIPT="${ADMIN_UTIL_DIR}/btrbk-show-config.sh"
RECOVERY_SCRIPT="${ADMIN_UTIL_DIR}/recovery-partition.sh"
USB_GOLDEN_SCRIPT="${ADMIN_UTIL_DIR}/usb-golden-snapshot.sh"
SNAPSHOT_COMPARE_SCRIPT="${ADMIN_UTIL_DIR}/snapshot-compare.sh"
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

   for file in "$BOOT_CONTEXT_SCRIPT" "$BACKUP_HEALTH_SCRIPT" "$SNAPPER_RUN_SCRIPT" "$SNAPPER_CONFIG_SCRIPT" "$BTRBK_RUN_SCRIPT" "$BTRBK_CONFIG_SCRIPT" "$RECOVERY_SCRIPT" "$USB_GOLDEN_SCRIPT" "$SNAPSHOT_COMPARE_SCRIPT"; do
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
   admin_run_report "Estado actual del sistema" "$BOOT_CONTEXT_SCRIPT"
}

# Helper: obtiene el filesystem type de un dispositivo de bloque
# Uso: fstype=$(admin_get_usb_fstype /dev/sdb1)
admin_get_usb_fstype() {
   blkid -s TYPE -o value "$1" 2>/dev/null
}

# Helper: verifica que haya espacio libre en el USB para el golden export.
# Monta temporalmente para verificar. Exporta _USB_FREE_HUMAN y _ROOT_USED_HUMAN.
# Retorna: 0=ok, 1=espacio insuficiente, 2=no se pudo montar
admin_check_usb_space() {
   local device="$1"
   local root_used_kb usb_free_kb mounted_here=0

   root_used_kb=$(df -BK / | awk 'NR==2{val=$3; gsub(/K/,"",val); print val+0}')

   mkdir -p /mnt/usb
   if ! mountpoint -q /mnt/usb; then
      if ! mount "$device" /mnt/usb 2>/dev/null; then
         return 2
      fi
      mounted_here=1
   fi

   usb_free_kb=$(df -BK /mnt/usb | awk 'NR==2{val=$4; gsub(/K/,"",val); print val+0}')
   _USB_FREE_HUMAN=$(df -h /mnt/usb | awk 'NR==2{print $4}')
   _ROOT_USED_HUMAN=$(df -h / | awk 'NR==2{print $3}')

   if [[ "$mounted_here" -eq 1 ]]; then
      umount /mnt/usb 2>/dev/null || true
   fi

   (( usb_free_kb >= root_used_kb )) && return 0 || return 1
}

admin_show_snapper_snapshots() {
   local snapper_lines=()
   mapfile -t snapper_lines < <(snapper -c root list)
   ui_show_text_box "Snapper | Ultimos snapshots locales" snapper_lines
}

admin_show_btrbk_snapshots() {
   local mounted_here=0 backup_lines=() backup_info=()
   
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

admin_run_snapper_now() {
   admin_run_report "Snapper - Realizar snapshot ahora" "$SNAPPER_RUN_SCRIPT"
}

admin_show_snapper_config() {
   admin_run_report "Configuracion - Snapper" "$SNAPPER_CONFIG_SCRIPT"
}

admin_run_btrbk_now() {
   admin_run_report "Btrbk - Realizar snapshot ahora" "$BTRBK_RUN_SCRIPT"
}

admin_show_btrbk_config() {
   admin_run_report "Configuracion - Btrbk" "$BTRBK_CONFIG_SCRIPT"
}

admin_snapper_menu() {
   local snapper_options=(
      "Configuracion actual"
      "Listado de los ultimos snapshots realizados"
      "Realizar snapshot ahora"
      "Exportar snapshot GOLDEN a USB"
      "Comparar snapshots locales"
      "Comparar con USB"
      "Volver"
   )

   while true; do
      ui_run_menu \
         "Admin Tools | Snapper" \
         "Herramientas de Snapper (snapshots locales)" \
         snapper_options \
         "Flechas: mover | ENTER: ejecutar | q/Esc: volver"

      if [[ "$UI_MENU_EVENT" == "QUIT" ]]; then
         return 0
      fi

      case "$UI_MENU_SELECTED" in
         0) admin_show_snapper_config || true ;;
         1) admin_show_snapper_snapshots || true ;;
         2) admin_run_snapper_now || true ;;
         3) admin_usb_golden_export || true ;;
         4) admin_snapper_compare_menu || true ;;
         5) admin_snapper_usb_compare_menu || true ;;
         6) return 0 ;;
      esac
   done
}

admin_btrbk_menu() {
   local btrbk_options=(
      "Configuracion actual"
      "Listado de los ultimos snapshots realizados"
      "Realizar snapshot ahora"
      "Gestion de particion recovery"
      "Comparar snapshots de recovery"
      "Volver"
   )

   while true; do
      ui_run_menu \
         "Admin Tools | Btrbk" \
         "Herramientas de Btrbk (snapshots en recovery)" \
         btrbk_options \
         "Flechas: mover | ENTER: ejecutar | q/Esc: volver"

      if [[ "$UI_MENU_EVENT" == "QUIT" ]]; then
         return 0
      fi

      case "$UI_MENU_SELECTED" in
         0) admin_show_btrbk_config || true ;;
         1) admin_show_btrbk_snapshots || true ;;
         2) admin_run_btrbk_now || true ;;
         3) admin_recovery_partition_menu || true ;;
         4) admin_btrbk_compare_menu || true ;;
         5) return 0 ;;
      esac
   done
}

admin_snapper_compare_menu() {
   local compare_options=(
      "Snapshot local vs estado actual"
      "Comparar dos snapshots locales"
      "Volver"
   )

   while true; do
      ui_run_menu \
         "Snapper | Comparar" \
         "Elegir tipo de comparacion" \
         compare_options \
         "Flechas: mover | ENTER: ejecutar | q/Esc: volver"

      if [[ "$UI_MENU_EVENT" == "QUIT" ]]; then
         return 0
      fi

      case "$UI_MENU_SELECTED" in
         0) admin_compare_snapper_current ;;
         1) admin_compare_snapper_two ;;
         2) return 0 ;;
      esac
   done
}

admin_snapper_usb_compare_menu() {
   local usb_compare_options=(
      "USB Btrfs vs estado actual"
      "USB Stream (.btrfs-stream) vs estado actual"
      "Volver"
   )

   while true; do
      ui_run_menu \
         "Snapper | Comparar con USB" \
         "Elegir tipo de archivo USB" \
         usb_compare_options \
         "Flechas: mover | ENTER: ejecutar | q/Esc: volver"

      if [[ "$UI_MENU_EVENT" == "QUIT" ]]; then
         return 0
      fi

      case "$UI_MENU_SELECTED" in
         0) admin_compare_usb_btrfs_current ;;
         1) admin_compare_usb_stream_current ;;
         2) return 0 ;;
      esac
   done
}

admin_btrbk_compare_menu() {
   local compare_options=(
      "Snapshot de recovery vs estado actual"
      "Volver"
   )

   while true; do
      ui_run_menu \
         "Btrbk | Comparar" \
         "Elegir tipo de comparacion" \
         compare_options \
         "Flechas: mover | ENTER: ejecutar | q/Esc: volver"

      if [[ "$UI_MENU_EVENT" == "QUIT" ]]; then
         return 0
      fi

      case "$UI_MENU_SELECTED" in
         0) admin_compare_btrbk_current ;;
         1) return 0 ;;
      esac
   done
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
   local device fstype mode cleanup_choice description name cmd=()
   local _USB_FREE_HUMAN="" _ROOT_USED_HUMAN=""
   local supported_formats="btrfs exfat vfat ntfs ext4 ext3 ext2 xfs f2fs"
   local mode_options=(
      "Auto detectar (recomendado)"
      "Btrfs send/receive (requiere USB Btrfs)"
      "Stream portable (.btrfs-stream, cualquier filesystem)"
      "Cancelar"
   )
   local cleanup_options=(
      "Conservar export local en /golden-exports"
      "Borrar export local al finalizar"
      "Cancelar"
   )
   local confirm_options=(
      "Confirmar y continuar"
      "Cancelar"
   )

   # 1. Mostrar dispositivos y pedir seleccion
   mapfile -t lsblk_lines < <(lsblk -o NAME,MODEL,TRAN,SIZE,FSTYPE,MOUNTPOINTS,RM -e 7)
   ui_show_text_box "USB Detectados" lsblk_lines "Revisar dispositivo y luego ENTER"

   device="$(ui_prompt_input "Particion USB a usar (ejemplo: /dev/sdb1)" "")"
   if [[ -z "$device" ]]; then
      ui_show_message "USB Golden" "Operacion cancelada: falta dispositivo real."
      return 1
   fi

   # 2. Validar que el dispositivo de bloque exista
   if [[ ! -b "$device" ]]; then
      ui_show_message "USB Golden" "Dispositivo no encontrado: $device
Conecta el USB e intenta de nuevo."
      return 1
   fi

   # 3. Validar formato del filesystem
   fstype="$(admin_get_usb_fstype "$device")"
   if [[ -z "$fstype" ]]; then
      ui_show_message "USB Golden" "No se pudo determinar el filesystem de $device.
Verifica que el USB este correctamente formateado."
      return 1
   fi
   if [[ " $supported_formats " != *" $fstype "* ]]; then
      ui_show_message "USB Golden" "Filesystem no soportado: $fstype
Formatos validos: btrfs, exfat, vfat, ntfs, ext4, xfs."
      return 1
   fi

   # 4. Verificar espacio disponible
   local space_rc
   admin_check_usb_space "$device"; space_rc=$?
   if [[ "$space_rc" -eq 2 ]]; then
      ui_show_message "USB Golden" "No se pudo montar $device para verificar espacio.
Verifica que el filesystem sea compatible."
      return 1
   fi
   if [[ "$space_rc" -eq 1 ]]; then
      ui_show_message "USB Golden" "Espacio insuficiente en el USB.
  Libre en USB : $_USB_FREE_HUMAN
  Usado en /   : $_ROOT_USED_HUMAN
Libera espacio en el USB e intenta de nuevo."
      return 1
   fi

   # 5. Elegir modo, descripcion, nombre, cleanup
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

   # 6. Mostrar resumen y pedir confirmacion final
   local summary_lines=(
      "Resumen de la operacion:"
      ""
      "  Dispositivo  : $device"
      "  Filesystem   : $fstype"
      "  Libre en USB : $_USB_FREE_HUMAN"
      "  Usado en /   : $_ROOT_USED_HUMAN"
      "  Modo         : $mode"
      "  Descripcion  : $description"
      "  Nombre       : $name"
      "  Export local : $cleanup_choice"
      ""
      "Esta operacion creara un snapshot Snapper y lo exportara al USB."
   )
   ui_show_text_box "USB Golden | Confirmacion" summary_lines "ENTER para continuar"

   ui_run_menu \
      "USB Golden | Confirmacion" \
      "¿Proceder con la exportacion GOLDEN?" \
      confirm_options \
      "Flechas: mover | ENTER: confirmar | q/Esc: cancelar"

   if [[ "$UI_MENU_EVENT" == "QUIT" || "$UI_MENU_SELECTED" -eq 1 ]]; then
      ui_show_message "USB Golden" "Operacion cancelada por el usuario."
      return 1
   fi

   # 7. Ejecutar
   cmd=("$USB_GOLDEN_SCRIPT" "--device" "$device" "--mode" "$mode" "--description" "$description" "--name" "$name")
   if [[ "$cleanup_choice" == "delete" ]]; then
      cmd+=("--cleanup-local-export")
   fi

   admin_run_report "USB Golden Export" "${cmd[@]}"
}

admin_compare_snapper_current() {
   local snapper_lines=()
   local from_id show_diff_options=(
      "Solo resumen (snapper status)"
      "Resumen + diff detallado"
      "Cancelar"
   )
   local cmd=()

   mapfile -t snapper_lines < <(snapper -c root list)
   ui_show_text_box "Snapper | Snapshots" snapper_lines "Elegir ID y luego ENTER"

   from_id="$(ui_prompt_input "ID del snapshot base a comparar contra el estado actual" "")"
   if [[ -z "$from_id" ]]; then
      ui_show_message "Comparar Snapper" "Operacion cancelada: falta ID origen."
      return 1
   fi

   ui_run_menu \
      "Snapper | Modo" \
      "Elegir nivel de detalle" \
      show_diff_options \
      "Flechas: mover | ENTER: confirmar | q/Esc: cancelar"

   if [[ "$UI_MENU_EVENT" == "QUIT" || "$UI_MENU_SELECTED" -eq 2 ]]; then
      return 1
   fi

   cmd=("$SNAPSHOT_COMPARE_SCRIPT" "--mode" "snapper" "--from" "$from_id")
   if [[ "$UI_MENU_SELECTED" -eq 1 ]]; then
      cmd+=("--show-diff")
   fi

   admin_run_report "Comparar Snapper vs Actual" "${cmd[@]}"
}

admin_compare_snapper_two() {
   local snapper_lines=()
   local from_id to_id show_diff_options=(
      "Solo resumen (snapper status)"
      "Resumen + diff detallado"
      "Cancelar"
   )
   local cmd=()

   mapfile -t snapper_lines < <(snapper -c root list)
   ui_show_text_box "Snapper | Snapshots" snapper_lines "Elegir IDs y luego ENTER"

   from_id="$(ui_prompt_input "ID del snapshot origen" "")"
   to_id="$(ui_prompt_input "ID del snapshot destino" "0")"
   if [[ -z "$from_id" || -z "$to_id" ]]; then
      ui_show_message "Comparar Snapper" "Operacion cancelada: faltan IDs."
      return 1
   fi

   ui_run_menu \
      "Snapper | Modo" \
      "Elegir nivel de detalle" \
      show_diff_options \
      "Flechas: mover | ENTER: confirmar | q/Esc: cancelar"

   if [[ "$UI_MENU_EVENT" == "QUIT" || "$UI_MENU_SELECTED" -eq 2 ]]; then
      return 1
   fi

   cmd=("$SNAPSHOT_COMPARE_SCRIPT" "--mode" "snapper" "--from" "$from_id" "--to" "$to_id")
   if [[ "$UI_MENU_SELECTED" -eq 1 ]]; then
      cmd+=("--show-diff")
   fi

   admin_run_report "Comparar Snapper entre snapshots" "${cmd[@]}"
}

admin_compare_btrbk_current() {
   local mounted_here=0
   local backup_lines=()
   local snapshot_name

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

   ui_show_text_box "btrbk | Snapshots" backup_lines "Elegir nombre y luego ENTER"
   snapshot_name="$(ui_prompt_input "Nombre del snapshot de btrbk a comparar" "")"
   if [[ -z "$snapshot_name" ]]; then
      ui_show_message "Comparar btrbk" "Operacion cancelada: falta nombre de snapshot."
      return 1
   fi

   admin_run_report \
      "Comparar btrbk vs Actual" \
      "$SNAPSHOT_COMPARE_SCRIPT" --mode btrbk --backup-snapshot "$snapshot_name"
}

admin_compare_usb_btrfs_current() {
   local lsblk_lines=()
   local device mounted_here=0 usb_lines=() snapshot_name

   mapfile -t lsblk_lines < <(lsblk -o NAME,MODEL,TRAN,SIZE,FSTYPE,MOUNTPOINTS,RM -e 7)
   ui_show_text_box "USB Detectados" lsblk_lines "Revisar dispositivo y luego ENTER"

   device="$(ui_prompt_input "Particion USB Btrfs (ejemplo: /dev/sdb1)" "")"
   if [[ -z "$device" ]]; then
      ui_show_message "Comparar USB Btrfs" "Operacion cancelada: falta dispositivo real."
      return 1
   fi
   if [[ ! -b "$device" ]]; then
      ui_show_message "Comparar USB Btrfs" "Dispositivo no encontrado: $device
Conecta el USB e intenta de nuevo."
      return 1
   fi

   # Validar que el filesystem sea Btrfs (necesario para comparar subvolumenes)
   local fstype
   fstype="$(admin_get_usb_fstype "$device")"
   if [[ "$fstype" != "btrfs" ]]; then
      ui_show_message "Comparar USB Btrfs" "El dispositivo $device no es Btrfs (detectado: ${fstype:-desconocido}).
Esta comparacion requiere un USB formateado como Btrfs."
      return 1
   fi

   mkdir -p /mnt/usb
   if ! mountpoint -q /mnt/usb; then
      if ! mount "$device" /mnt/usb 2>/dev/null; then
         ui_show_message "Comparar USB Btrfs" "No se pudo montar $device.\nVerifica que el filesystem sea compatible (Btrfs, ext4, exfat, ntfs)."
         return 1
      fi
      mounted_here=1
   fi
   mapfile -t usb_lines < <(find /mnt/usb/snapshots -mindepth 1 -maxdepth 1 -printf '%f\n' 2>/dev/null | sort)
   if [[ "$mounted_here" -eq 1 ]]; then
      umount /mnt/usb || true
   fi

   if (( ${#usb_lines[@]} == 0 )); then
      ui_show_message "Comparar USB Btrfs" "No se encontraron snapshots en /mnt/usb/snapshots."
      return 1
   fi

   ui_show_text_box "USB Btrfs | Snapshots" usb_lines "Elegir nombre y luego ENTER"
   snapshot_name="$(ui_prompt_input "Nombre del snapshot USB a comparar" "")"
   if [[ -z "$snapshot_name" ]]; then
      ui_show_message "Comparar USB Btrfs" "Operacion cancelada: falta nombre de snapshot."
      return 1
   fi

   admin_run_report \
      "Comparar USB Btrfs vs Actual" \
      "$SNAPSHOT_COMPARE_SCRIPT" --mode usb-btrfs --device "$device" --usb-snapshot "$snapshot_name"
}

admin_compare_usb_stream_current() {
   local lsblk_lines=()
   local device mounted_here=0 usb_lines=() stream_name

   mapfile -t lsblk_lines < <(lsblk -o NAME,MODEL,TRAN,SIZE,FSTYPE,MOUNTPOINTS,RM -e 7)
   ui_show_text_box "USB Detectados" lsblk_lines "Revisar dispositivo y luego ENTER"

   device="$(ui_prompt_input "Particion USB con streams (ejemplo: /dev/sdb1)" "")"
   if [[ -z "$device" ]]; then
      ui_show_message "Comparar USB Stream" "Operacion cancelada: falta dispositivo real."
      return 1
   fi
   if [[ ! -b "$device" ]]; then
      ui_show_message "Comparar USB Stream" "Dispositivo no encontrado: $device\nConecta el USB e intenta de nuevo."
      return 1
   fi

   mkdir -p /mnt/usb
   if ! mountpoint -q /mnt/usb; then
      if ! mount "$device" /mnt/usb 2>/dev/null; then
         ui_show_message "Comparar USB Stream" "No se pudo montar $device.\nVerifica que el filesystem sea compatible (Btrfs, ext4, exfat, ntfs)."
         return 1
      fi
      mounted_here=1
   fi
   mapfile -t usb_lines < <(find /mnt/usb/btrfs-streams -mindepth 1 -maxdepth 1 -name '*.btrfs-stream' -printf '%f\n' 2>/dev/null | sort)
   if [[ "$mounted_here" -eq 1 ]]; then
      umount /mnt/usb || true
   fi

   if (( ${#usb_lines[@]} == 0 )); then
      ui_show_message "Comparar USB Stream" "No se encontraron .btrfs-stream en /mnt/usb/btrfs-streams."
      return 1
   fi

   ui_show_text_box "USB Stream | Archivos" usb_lines "Elegir nombre y luego ENTER"
   stream_name="$(ui_prompt_input "Nombre del archivo .btrfs-stream a comparar" "")"
   if [[ -z "$stream_name" ]]; then
      ui_show_message "Comparar USB Stream" "Operacion cancelada: falta nombre de stream."
      return 1
   fi

   admin_run_report \
      "Comparar USB Stream vs Actual" \
      "$SNAPSHOT_COMPARE_SCRIPT" --mode usb-stream --device "$device" --stream-name "$stream_name"
}

admin_show_help() {
   local help_lines=(
      "Admin Tools centraliza los utilitarios de mantenimiento del proyecto."
      ""
      "Menu principal:"
      "- Informar estado actual: muestra contexto de arranque y sistema"
      "- Snapper: submenú de operaciones de snapshots locales"
      "- Btrbk: submenú de operaciones de snapshots en recovery"
      "- Ver README de utilitarios dentro de la UI"
      "- Ayuda"
      ""
      "Submenú Snapper:"
      "  - Listado de ultimos snapshots"
      "  - Realizar snapshot ahora"
      "  - Exportar snapshot GOLDEN a USB"
      "  - Comparar snapshots locales (vs actual o entre dos)"
      "  - Comparar con USB (Btrfs o Stream)"
      ""
      "Submenú Btrbk:"
      "  - Configuracion actual (disparadores, volumes, retencion)"
      "  - Listado de ultimos snapshots de recovery"
      "  - Realizar snapshot/backup ahora"
      "  - Gestion de /mnt/backup (mount, umount, ro/rw)"
      "  - Comparar snapshots de recovery vs actual"
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
