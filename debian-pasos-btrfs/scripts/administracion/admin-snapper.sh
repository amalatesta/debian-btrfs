#!/usr/bin/env bash
set -euo pipefail

ADMIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/admin_ui.sh
source "${ADMIN_DIR}/lib/admin_ui.sh"
# shellcheck source=lib/admin_common.sh
source "${ADMIN_DIR}/lib/admin_common.sh"

show_snapper_snapshots() {
   local snapper_lines=()
   mapfile -t snapper_lines < <(build_snapper_list_with_imp)
   ui_show_text_box "Snapper | Ultimos snapshots locales" snapper_lines
}

run_snapper_now() {
   admin_run_report "Snapper | Realizar snapshot ahora" "$SNAPPER_RUN_SCRIPT"
}

show_snapper_config() {
   admin_run_report "Snapper | Configuracion" "$SNAPPER_CONFIG_SCRIPT"
}

build_snapper_list_with_imp() {
   snapper -c root list 2>/dev/null |
      awk -F'|' '
         NR == 1 {
            print " # | Tipo   | Pre numero | Imp | Fecha                    | Usuario | Limpieza | Descripcion                   | Informacion del usuario";
            next;
         }
         NR == 2 {
            print "---+--------+------------+-----+--------------------------+---------+----------+-------------------------------+------------------------";
            next;
         }
         NR > 2 {
            id = $1; type = $2; pre = $3; date = $4; user = $5; cleanup = $6; desc = $7; userdata = $8;
            gsub(/^[ \t]+|[ \t]+$/, "", id);
            gsub(/^[ \t]+|[ \t]+$/, "", type);
            gsub(/^[ \t]+|[ \t]+$/, "", pre);
            gsub(/^[ \t]+|[ \t]+$/, "", date);
            gsub(/^[ \t]+|[ \t]+$/, "", user);
            gsub(/^[ \t]+|[ \t]+$/, "", cleanup);
            gsub(/^[ \t]+|[ \t]+$/, "", desc);
            gsub(/^[ \t]+|[ \t]+$/, "", userdata);

            imp = "N";
            if (userdata ~ /important=yes/) {
               imp = "Y";
            } else if (userdata != "" && userdata !~ /important=/) {
               imp = "?";
            }

            printf "%-2s | %-6s | %-10s | %-3s | %-24s | %-7s | %-8s | %-29s | %s\n", id, type, pre, imp, date, user, cleanup, desc, userdata;
         }
      '
}

show_snapper_important_snapshots() {
   local lines=()
   mapfile -t lines < <(snapper -c root list | awk 'NR<=2 || /important=yes/')

   if (( ${#lines[@]} <= 2 )); then
      lines+=("(sin snapshots marcados como important=yes)")
   fi

   ui_show_text_box "Snapper | Snapshots importantes" lines
}

mark_snapshot_as_important() {
   local snapshot_id=""

   show_snapper_snapshots
   snapshot_id="$(ui_prompt_input "ID snapshot a marcar" "")"

   if [[ ! "$snapshot_id" =~ ^[0-9]+$ ]]; then
      ui_show_message "Snapper | Importante" "ID invalido: ${snapshot_id:-vacío}"
      return 1
   fi

   if ! snapper -c root modify --userdata "important=yes" "$snapshot_id" >/dev/null 2>&1; then
      ui_show_message "Snapper | Importante" "No se pudo marcar snapshot $snapshot_id"
      return 1
   fi

   ui_show_message "Snapper | Importante" "Snapshot $snapshot_id marcado como important=yes"
}

unmark_snapshot_as_important() {
   local snapshot_id=""

   show_snapper_important_snapshots
   snapshot_id="$(ui_prompt_input "ID snapshot a liberar" "")"

   if [[ ! "$snapshot_id" =~ ^[0-9]+$ ]]; then
      ui_show_message "Snapper | Importante" "ID invalido: ${snapshot_id:-vacío}"
      return 1
   fi

   if ! snapper -c root modify --userdata "important=no" "$snapshot_id" >/dev/null 2>&1; then
      ui_show_message "Snapper | Importante" "No se pudo liberar snapshot $snapshot_id"
      return 1
   fi

   ui_show_message "Snapper | Importante" "Snapshot $snapshot_id marcado como important=no"
}

promote_snapshot_for_grub() {
   local snapper_lines=()
   local source_id=""
   local new_id=""
   local description=""
   local output=""
   local daemon_state="inactivo"
   local mark_imp="N"
   local important_options=(
      "Si, marcar nuevo snapshot como importante"
      "No, dejar sin marca importante"
      "Cancelar"
   )
   local refresh_options=(
      "No hacer nada (grub-btrfsd deberia actualizar solo)"
      "Reiniciar daemon grub-btrfsd ahora"
      "Regenerar GRUB manualmente ahora"
      "Reiniciar daemon + regenerar GRUB"
   )

   mapfile -t snapper_lines < <(build_snapper_list_with_imp)
   ui_show_text_box "Snapper | Promover snapshot para GRUB" snapper_lines "Elegir ID origen y luego ENTER"

   source_id="$(ui_prompt_input "ID snapshot origen a clonar" "")"
   if [[ ! "$source_id" =~ ^[0-9]+$ ]]; then
      ui_show_message "Snapper | Promover" "ID invalido: ${source_id:-vacio}"
      return 1
   fi

   description="$(ui_prompt_input "Descripcion snapshot nuevo" "PROMOTE-$(date +%Y%m%d)-from-${source_id}")"
   if [[ -z "$description" ]]; then
      ui_show_message "Snapper | Promover" "Operacion cancelada: falta descripcion."
      return 1
   fi

   ui_run_menu \
      "Snapper | Promover snapshot" \
      "Marcar el snapshot nuevo como importante?" \
      important_options \
      "Flechas: mover | ENTER: seleccionar | q/Esc: cancelar"

   if [[ "$UI_MENU_EVENT" == "QUIT" || "$UI_MENU_SELECTED" -eq 2 ]]; then
      return 1
   fi

   if [[ "$UI_MENU_SELECTED" -eq 0 ]]; then
      mark_imp="Y"
   fi

   if ! output="$(snapper -c root create --from "$source_id" --description "$description" --cleanup-algorithm number --print-number 2>&1)"; then
      ui_show_message "Snapper | Promover" "No se pudo clonar snapshot $source_id\n\n$output"
      return 1
   fi

   new_id="$(printf '%s\n' "$output" | grep -Eo '^[0-9]+' | head -1 || true)"
   if [[ -z "$new_id" || ! "$new_id" =~ ^[0-9]+$ ]]; then
      ui_show_message "Snapper | Promover" "Clon creado, pero no se pudo detectar ID nuevo.\nSalida:\n$output"
      return 0
   fi

   if [[ "$mark_imp" == "Y" ]]; then
      if ! snapper -c root modify --userdata "important=yes" "$new_id" >/dev/null 2>&1; then
         ui_show_message "Snapper | Promover" "Clon creado (#$new_id), pero no se pudo marcar important=yes."
         return 1
      fi
   fi

   if systemctl is-active grub-btrfsd >/dev/null 2>&1; then
      daemon_state="activo"
   fi

   ui_show_message "Snapper | Promover" "Snapshot clonado: #$new_id\nMarca importante: $mark_imp\n\ngrub-btrfsd: $daemon_state\nNormalmente se actualiza solo en pocos segundos.\nSi no aparece en GRUB, puedes forzar actualizacion ahora."

   ui_run_menu \
      "Snapper | Promover snapshot" \
      "Elegir accion de refresco GRUB" \
      refresh_options \
      "Flechas: mover | ENTER: ejecutar | q/Esc: volver"

   if [[ "$UI_MENU_EVENT" == "QUIT" ]]; then
      return 0
   fi

   case "$UI_MENU_SELECTED" in
      0) return 0 ;;
      1) admin_run_report "grub-btrfs | Reiniciar daemon" systemctl restart grub-btrfsd ;;
      2) admin_run_report "grub-btrfs | Regenerar GRUB" grub-mkconfig -o /boot/grub/grub.cfg ;;
      3)
         admin_run_report "grub-btrfs | Reiniciar daemon" systemctl restart grub-btrfsd
         admin_run_report "grub-btrfs | Regenerar GRUB" grub-mkconfig -o /boot/grub/grub.cfg
         ;;
   esac
}

manage_important_snapshots() {
   local important_options=(
      "Listar snapshots importantes"
      "Marcar snapshot como importante"
      "Desmarcar snapshot como importante"
      "Clonar/promover snapshot para GRUB"
      "Volver"
   )

   while true; do
      ui_run_menu \
         "Snapper | Snapshots importantes" \
         "Anclar puntos de restauracion para evitar cleanup automatico" \
         important_options \
         "Flechas: mover | ENTER: ejecutar | q/Esc: volver"

      if [[ "$UI_MENU_EVENT" == "QUIT" ]]; then
         return 0
      fi

      case "$UI_MENU_SELECTED" in
         0) show_snapper_important_snapshots || true ;;
         1) mark_snapshot_as_important || true ;;
         2) unmark_snapshot_as_important || true ;;
         3) promote_snapshot_for_grub || true ;;
         4) return 0 ;;
      esac
   done
}

show_golden_export_status() {
   local status_lines=()

   mapfile -t status_lines < <(
      ps -eo pid,etime,%cpu,%mem,cmd |
         grep -Ei 'usb-golden-snapshot\.sh|btrfs send|btrfs receive|sha256sum' |
         grep -v grep || true
   )

   if (( ${#status_lines[@]} == 0 )); then
      status_lines=(
         "No hay exportaciones GOLDEN ejecutandose ahora."
         ""
         "Procesos monitoreados:"
         "- usb-golden-snapshot.sh"
         "- btrfs send"
         "- btrfs receive"
         "- sha256sum"
         ""
         "Tip: tambien puedes revisar actividad con top o htop."
      )
   else
      status_lines=(
         "Procesos activos relacionados a exportacion GOLDEN:"
         ""
         "PID   ELAPSED   CPU   MEM   CMD"
         "${status_lines[@]}"
         ""
         "Tip: para monitoreo continuo puedes usar top o htop."
      )
   fi

   ui_show_text_box "Snapper | Estado de exportacion USB" status_lines
}

restore_from_usb_selective() {
   local lsblk_lines=()
   local device default_device=""
   local mounted_here=0
   local source_mode=""
   local source_name=""
   local source_path=""
   local stream_path=""
   local sha_path=""
   local receive_parent=""
   local receive_subvol=""
   local restore_path=""
   local rel_path=""
   local src_item=""
   local mode_options=(
      "Usar snapshot USB Btrfs (/snapshots)"
      "Usar archivo stream USB (.btrfs-stream)"
      "Cancelar"
   )
   local confirm_options=(
      "Confirmar restauracion"
      "Cancelar"
   )

   cleanup_restore_tmp() {
      if [[ -n "$receive_subvol" && -d "$receive_subvol" ]]; then
         btrfs subvolume delete "$receive_subvol" >/dev/null 2>&1 || true
      fi
      if [[ -n "$receive_parent" && -d "$receive_parent" ]]; then
         rmdir "$receive_parent" >/dev/null 2>&1 || true
      fi
      if [[ "$mounted_here" -eq 1 ]] && mountpoint -q /mnt/usb; then
         umount /mnt/usb >/dev/null 2>&1 || true
      fi
   }

   mapfile -t lsblk_lines < <(lsblk -o NAME,MODEL,TRAN,SIZE,FSTYPE,MOUNTPOINTS,RM -e 7)
   ui_show_text_box "USB Detectados" lsblk_lines "Revisar dispositivo y luego ENTER"

   default_device="$(admin_detect_golden_device 2>/dev/null || true)"
   device="$(ui_prompt_input "Particion USB a usar (ejemplo: /dev/sda1)" "$default_device")"
   device="$(admin_normalize_device_path "$device")"

   if [[ -z "$device" || "$device" != /dev/* || ! -b "$device" ]]; then
      ui_show_message "Restaurar desde USB" "Dispositivo invalido o no encontrado: ${device:-vacío}"
      return 1
   fi
   admin_save_golden_device "$device"

   mkdir -p /mnt/usb
   if ! mountpoint -q /mnt/usb; then
      if ! mount "$device" /mnt/usb 2>/dev/null; then
         ui_show_message "Restaurar desde USB" "No se pudo montar $device"
         return 1
      fi
      mounted_here=1
   fi

   ui_run_menu \
      "Restaurar desde USB | Fuente" \
      "Elegir tipo de origen de restauracion" \
      mode_options \
      "Flechas: mover | ENTER: seleccionar | q/Esc: cancelar"

   if [[ "$UI_MENU_EVENT" == "QUIT" || "$UI_MENU_SELECTED" -eq 2 ]]; then
      cleanup_restore_tmp
      return 1
   fi

   if [[ "$UI_MENU_SELECTED" -eq 0 ]]; then
      local btrfs_entries=()
      local options=()
      source_mode="usb-btrfs"

      mapfile -t btrfs_entries < <(find /mnt/usb/snapshots -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort)
      if (( ${#btrfs_entries[@]} == 0 )); then
         ui_show_message "Restaurar desde USB" "No se encontraron snapshots en /mnt/usb/snapshots"
         cleanup_restore_tmp
         return 1
      fi

      options=("${btrfs_entries[@]}" "Cancelar")
      ui_run_menu \
         "Restaurar desde USB Btrfs" \
         "Selecciona snapshot a usar" \
         options \
         "Flechas: mover | ENTER: seleccionar | q/Esc: cancelar"

      if [[ "$UI_MENU_EVENT" == "QUIT" || "$UI_MENU_SELECTED" -ge ${#btrfs_entries[@]} ]]; then
         cleanup_restore_tmp
         return 1
      fi

      source_name="${btrfs_entries[$UI_MENU_SELECTED]}"
      source_path="/mnt/usb/snapshots/$source_name"
   else
      local stream_entries=()
      local options=()
      source_mode="usb-stream"

      mapfile -t stream_entries < <(find /mnt/usb/btrfs-streams -mindepth 1 -maxdepth 1 -type f -name '*.btrfs-stream' -printf '%f\n' 2>/dev/null | sort)
      if (( ${#stream_entries[@]} == 0 )); then
         ui_show_message "Restaurar desde USB" "No se encontraron archivos .btrfs-stream en /mnt/usb/btrfs-streams"
         cleanup_restore_tmp
         return 1
      fi

      options=("${stream_entries[@]}" "Cancelar")
      ui_run_menu \
         "Restaurar desde stream USB" \
         "Selecciona stream a usar" \
         options \
         "Flechas: mover | ENTER: seleccionar | q/Esc: cancelar"

      if [[ "$UI_MENU_EVENT" == "QUIT" || "$UI_MENU_SELECTED" -ge ${#stream_entries[@]} ]]; then
         cleanup_restore_tmp
         return 1
      fi

      source_name="${stream_entries[$UI_MENU_SELECTED]}"
      stream_path="/mnt/usb/btrfs-streams/$source_name"
      sha_path="${stream_path%.btrfs-stream}.sha256"

      if [[ -f "$sha_path" ]]; then
         if ! (cd /mnt/usb/btrfs-streams && sha256sum -c "$(basename "$sha_path")" >/dev/null 2>&1); then
            ui_show_message "Restaurar desde USB" "Checksum SHA256 invalido para $source_name"
            cleanup_restore_tmp
            return 1
         fi
      fi

      receive_parent="/golden-imports/restore-$$"
      mkdir -p /golden-imports "$receive_parent"
      if ! btrfs receive "$receive_parent" < "$stream_path" >/dev/null 2>&1; then
         ui_show_message "Restaurar desde USB" "No se pudo importar el stream seleccionado"
         cleanup_restore_tmp
         return 1
      fi

      receive_subvol="$(find "$receive_parent" -mindepth 1 -maxdepth 1 -type d | head -1)"
      if [[ -z "$receive_subvol" || ! -d "$receive_subvol" ]]; then
         ui_show_message "Restaurar desde USB" "No se pudo identificar el snapshot importado"
         cleanup_restore_tmp
         return 1
      fi
      source_path="$receive_subvol"
   fi

   restore_path="$(ui_prompt_input "Ruta ABSOLUTA a restaurar (ejemplo: /etc/hosts o /etc)" "")"
   restore_path="$(admin_normalize_device_path "$restore_path")"

   if [[ -z "$restore_path" || "$restore_path" != /* || "$restore_path" == "/" ]]; then
      ui_show_message "Restaurar desde USB" "Ruta invalida. Debe ser absoluta y distinta de /"
      cleanup_restore_tmp
      return 1
   fi

   case "$restore_path" in
      /proc*|/sys*|/dev*|/run*|/tmp*|/mnt*|/media*)
         ui_show_message "Restaurar desde USB" "Ruta no permitida para restauracion: $restore_path"
         cleanup_restore_tmp
         return 1
         ;;
   esac

   rel_path="${restore_path#/}"
   src_item="${source_path}/${rel_path}"
   if [[ ! -e "$src_item" ]]; then
      ui_show_message "Restaurar desde USB" "La ruta no existe en la copia USB: $restore_path"
      cleanup_restore_tmp
      return 1
   fi

   local summary_lines=(
      "Se restaurara una ruta puntual desde USB"
      ""
      "Origen tipo : $source_mode"
      "Origen      : $source_name"
      "Ruta destino: $restore_path"
      ""
      "Esto sobreescribira archivos existentes en esa ruta."
   )
   ui_show_text_box "Restaurar desde USB | Confirmacion" summary_lines "ENTER para continuar"

   ui_run_menu \
      "Restaurar desde USB | Confirmar" \
      "Aplicar restauracion selectiva ahora?" \
      confirm_options \
      "Flechas: mover | ENTER: confirmar | q/Esc: cancelar"

   if [[ "$UI_MENU_EVENT" == "QUIT" || "$UI_MENU_SELECTED" -eq 1 ]]; then
      cleanup_restore_tmp
      return 1
   fi

   if [[ -d "$src_item" ]]; then
      mkdir -p "$restore_path"
      if ! rsync -aHAX --numeric-ids "$src_item/" "$restore_path/"; then
         ui_show_message "Restaurar desde USB" "Fallo la restauracion de directorio"
         cleanup_restore_tmp
         return 1
      fi
   else
      mkdir -p "$(dirname "$restore_path")"
      if ! rsync -aHAX --numeric-ids "$src_item" "$restore_path"; then
         ui_show_message "Restaurar desde USB" "Fallo la restauracion de archivo"
         cleanup_restore_tmp
         return 1
      fi
   fi

   cleanup_restore_tmp
   ui_show_message "Restaurar desde USB" "Restauracion selectiva completada para: $restore_path"
}

usb_golden_export() {
   local lsblk_lines=()
   local device fstype mode cleanup_choice description name cmd=()
   local default_device=""
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

   mapfile -t lsblk_lines < <(lsblk -o NAME,MODEL,TRAN,SIZE,FSTYPE,MOUNTPOINTS,RM -e 7)
   ui_show_text_box "USB Detectados" lsblk_lines "Revisar dispositivo y luego ENTER"

   default_device="$(admin_detect_golden_device 2>/dev/null || true)"
   device="$(ui_prompt_input "Particion USB a usar (ejemplo: /dev/sda1)" "$default_device")"
   device="$(admin_normalize_device_path "$device")"
   if [[ -z "$device" ]]; then
      ui_show_message "USB Golden" "Operacion cancelada: falta dispositivo real."
      return 1
   fi
   if [[ "$device" != /dev/* ]]; then
      printf -v device '%q' "$device"
      ui_show_message "USB Golden" "Valor ingresado: $device\nDebes indicar ruta completa.\nEjemplo: /dev/sda1"
      return 1
   fi
   if [[ ! -b "$device" ]]; then
      ui_show_message "USB Golden" "Dispositivo no encontrado: $device\nConecta el USB e intenta de nuevo."
      return 1
   fi

   admin_save_golden_device "$device"

   fstype="$(admin_get_usb_fstype "$device")"
   if [[ -z "$fstype" ]]; then
      ui_show_message "USB Golden" "No se pudo determinar filesystem de $device."
      return 1
   fi
   if [[ " $supported_formats " != *" $fstype "* ]]; then
      ui_show_message "USB Golden" "Filesystem no soportado: $fstype\nValidos: btrfs, exfat, vfat, ntfs, ext4, xfs."
      return 1
   fi

   local space_rc
   admin_check_usb_space "$device"; space_rc=$?
   if [[ "$space_rc" -eq 2 ]]; then
      ui_show_message "USB Golden" "No se pudo montar $device para verificar espacio."
      return 1
   fi
   if [[ "$space_rc" -eq 1 ]]; then
      ui_show_message "USB Golden" "Espacio insuficiente en USB.\nLibre USB: $_USB_FREE_HUMAN\nUsado en /: $_ROOT_USED_HUMAN"
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
      "Que hacer con /golden-exports/<nombre>" \
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

   local summary_lines=(
      "Resumen de la operacion"
      ""
      "Dispositivo  : $device"
      "Filesystem   : $fstype"
      "Libre en USB : $_USB_FREE_HUMAN"
      "Usado en /   : $_ROOT_USED_HUMAN"
      "Modo         : $mode"
      "Descripcion  : $description"
      "Nombre       : $name"
      "Export local : $cleanup_choice"
   )
   ui_show_text_box "USB Golden | Confirmacion" summary_lines "ENTER para continuar"

   ui_run_menu \
      "USB Golden | Confirmacion" \
      "Proceder con la exportacion GOLDEN?" \
      confirm_options \
      "Flechas: mover | ENTER: confirmar | q/Esc: cancelar"

   if [[ "$UI_MENU_EVENT" == "QUIT" || "$UI_MENU_SELECTED" -eq 1 ]]; then
      ui_show_message "USB Golden" "Operacion cancelada por el usuario."
      return 1
   fi

   cmd=("$USB_GOLDEN_SCRIPT" "--device" "$device" "--mode" "$mode" "--description" "$description" "--name" "$name")
   if [[ "$cleanup_choice" == "delete" ]]; then
      cmd+=("--cleanup-local-export")
   fi

   admin_run_report "USB Golden Export" "${cmd[@]}"
}

compare_snapper_current() {
   local snapper_lines=()
   local from_id
   local show_diff_options=(
      "Solo resumen (snapper status)"
      "Resumen + diff detallado"
      "Cancelar"
   )
   local cmd=()

   mapfile -t snapper_lines < <(build_snapper_list_with_imp)
   ui_show_text_box "Snapper | Snapshots" snapper_lines "Elegir ID y luego ENTER"

   from_id="$(ui_prompt_input "ID base a comparar contra el estado actual" "")"
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

compare_snapper_two() {
   local snapper_lines=()
   local from_id to_id
   local show_diff_options=(
      "Solo resumen (snapper status)"
      "Resumen + diff detallado"
      "Cancelar"
   )
   local cmd=()

   mapfile -t snapper_lines < <(build_snapper_list_with_imp)
   ui_show_text_box "Snapper | Snapshots" snapper_lines "Elegir IDs y luego ENTER"

   from_id="$(ui_prompt_input "ID origen" "")"
   to_id="$(ui_prompt_input "ID destino" "0")"
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

compare_usb_btrfs_current() {
   local lsblk_lines=()
   local device mounted_here=0 usb_lines=() snapshot_name
   local selection_options=()
   local fstype
   local default_device=""

   mapfile -t lsblk_lines < <(lsblk -o NAME,MODEL,TRAN,SIZE,FSTYPE,MOUNTPOINTS,RM -e 7)
   ui_show_text_box "USB Detectados" lsblk_lines "Revisar dispositivo y luego ENTER"

   default_device="$(admin_detect_golden_device 2>/dev/null || true)"
   device="$(ui_prompt_input "Particion USB Btrfs (ejemplo: /dev/sda1)" "$default_device")"
   device="$(admin_normalize_device_path "$device")"
   if [[ -z "$device" ]]; then
      ui_show_message "Comparar USB Btrfs" "Operacion cancelada: falta dispositivo real."
      return 1
   fi
   if [[ "$device" != /dev/* ]]; then
      ui_show_message "Comparar USB Btrfs" "Debes indicar ruta completa. Ejemplo: /dev/sda1"
      return 1
   fi
   if [[ ! -b "$device" ]]; then
      ui_show_message "Comparar USB Btrfs" "Dispositivo no encontrado: $device"
      return 1
   fi

   admin_save_golden_device "$device"

   fstype="$(admin_get_usb_fstype "$device")"
   if [[ "$fstype" != "btrfs" ]]; then
      ui_show_message "Comparar USB Btrfs" "El dispositivo $device no es Btrfs (detectado: ${fstype:-desconocido})."
      return 1
   fi

   mkdir -p /mnt/usb
   if ! mountpoint -q /mnt/usb; then
      if ! mount "$device" /mnt/usb 2>/dev/null; then
         ui_show_message "Comparar USB Btrfs" "No se pudo montar $device."
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

   selection_options=("${usb_lines[@]}" "Ingresar nombre manualmente" "Cancelar")
   ui_run_menu \
      "USB Btrfs | Snapshots" \
      "Selecciona un snapshot" \
      selection_options \
      "Flechas: mover | ENTER: seleccionar | q/Esc: cancelar"

   if [[ "$UI_MENU_EVENT" == "QUIT" ]]; then
      return 1
   fi

   if [[ "$UI_MENU_SELECTED" -lt ${#usb_lines[@]} ]]; then
      snapshot_name="${usb_lines[$UI_MENU_SELECTED]}"
   elif [[ "$UI_MENU_SELECTED" -eq ${#usb_lines[@]} ]]; then
      snapshot_name="$(ui_prompt_input "Nombre del snapshot USB" "")"
      if [[ -z "$snapshot_name" ]]; then
         ui_show_message "Comparar USB Btrfs" "Operacion cancelada: falta nombre."
         return 1
      fi
   else
      return 1
   fi

   admin_run_report \
      "Comparar USB Btrfs vs Actual" \
      "$SNAPSHOT_COMPARE_SCRIPT" --mode usb-btrfs --device "$device" --usb-snapshot "$snapshot_name"
}

compare_usb_stream_current() {
   local lsblk_lines=()
   local device mounted_here=0 usb_lines=() stream_name
   local selection_options=()
   local default_device=""

   mapfile -t lsblk_lines < <(lsblk -o NAME,MODEL,TRAN,SIZE,FSTYPE,MOUNTPOINTS,RM -e 7)
   ui_show_text_box "USB Detectados" lsblk_lines "Revisar dispositivo y luego ENTER"

   default_device="$(admin_detect_golden_device 2>/dev/null || true)"
   device="$(ui_prompt_input "Particion USB con streams (ejemplo: /dev/sda1)" "$default_device")"
   device="$(admin_normalize_device_path "$device")"
   if [[ -z "$device" ]]; then
      ui_show_message "Comparar USB Stream" "Operacion cancelada: falta dispositivo real."
      return 1
   fi
   if [[ "$device" != /dev/* ]]; then
      ui_show_message "Comparar USB Stream" "Debes indicar ruta completa. Ejemplo: /dev/sda1"
      return 1
   fi
   if [[ ! -b "$device" ]]; then
      ui_show_message "Comparar USB Stream" "Dispositivo no encontrado: $device"
      return 1
   fi

   admin_save_golden_device "$device"

   mkdir -p /mnt/usb
   if ! mountpoint -q /mnt/usb; then
      if ! mount "$device" /mnt/usb 2>/dev/null; then
         ui_show_message "Comparar USB Stream" "No se pudo montar $device."
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

   selection_options=("${usb_lines[@]}" "Ingresar nombre manualmente" "Cancelar")
   ui_run_menu \
      "USB Stream | Archivos" \
      "Selecciona un archivo" \
      selection_options \
      "Flechas: mover | ENTER: seleccionar | q/Esc: cancelar"

   if [[ "$UI_MENU_EVENT" == "QUIT" ]]; then
      return 1
   fi

   if [[ "$UI_MENU_SELECTED" -lt ${#usb_lines[@]} ]]; then
      stream_name="${usb_lines[$UI_MENU_SELECTED]}"
   elif [[ "$UI_MENU_SELECTED" -eq ${#usb_lines[@]} ]]; then
      stream_name="$(ui_prompt_input "Nombre del .btrfs-stream" "")"
      if [[ -z "$stream_name" ]]; then
         ui_show_message "Comparar USB Stream" "Operacion cancelada: falta nombre."
         return 1
      fi
   else
      return 1
   fi

   admin_run_report \
      "Comparar USB Stream vs Actual" \
      "$SNAPSHOT_COMPARE_SCRIPT" --mode usb-stream --device "$device" --stream-name "$stream_name"
}

snapper_compare_menu() {
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
         0) compare_snapper_current || true ;;
         1) compare_snapper_two || true ;;
         2) return 0 ;;
      esac
   done
}

snapper_usb_compare_menu() {
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
         0) compare_usb_btrfs_current || true ;;
         1) compare_usb_stream_current || true ;;
         2) return 0 ;;
      esac
   done
}

usb_snapper_menu() {
   local usb_options=(
      "Exportar snapshot a USB"
      "Ver estado de exportacion USB"
      "Comparar con USB"
      "Restaurar desde USB (selectivo)"
      "Volver"
   )

   while true; do
      ui_run_menu \
         "Snapper | Snapshots en USB" \
         "Herramientas para gestionar snapshots en USB" \
         usb_options \
         "Flechas: mover | ENTER: ejecutar | q/Esc: volver"

      if [[ "$UI_MENU_EVENT" == "QUIT" ]]; then
         return 0
      fi

      case "$UI_MENU_SELECTED" in
         0) usb_golden_export || true ;;
         1) show_golden_export_status || true ;;
         2) snapper_usb_compare_menu || true ;;
         3) restore_from_usb_selective || true ;;
         4) return 0 ;;
      esac
   done
}

inspect_snapper_snapshot_readonly() {
   local snapper_lines=()
   local snap_id=""
   local source_path=""
   local mount_base="/mnt/snapper-ro"
   local target_path=""
   local post_options=(
      "Desmontar ahora y volver"
      "Dejar montado y volver"
   )
   local info_lines=()

   mapfile -t snapper_lines < <(build_snapper_list_with_imp)
   ui_show_text_box "Snapper | Inspeccion solo lectura" snapper_lines "Elegir ID y luego ENTER"

   snap_id="$(ui_prompt_input "ID snapshot a inspeccionar (RO)" "")"
   if [[ ! "$snap_id" =~ ^[0-9]+$ ]]; then
      ui_show_message "Snapper | Inspeccion RO" "ID invalido: ${snap_id:-vacio}"
      return 1
   fi

   source_path="/.snapshots/${snap_id}/snapshot"
   if [[ ! -d "$source_path" ]]; then
      ui_show_message "Snapper | Inspeccion RO" "No existe el snapshot local: $source_path"
      return 1
   fi

   mkdir -p "$mount_base"
   target_path="${mount_base}/${snap_id}"
   mkdir -p "$target_path"

   if mountpoint -q "$target_path"; then
      umount "$target_path" >/dev/null 2>&1 || true
   fi

   if ! mount --bind "$source_path" "$target_path" >/dev/null 2>&1; then
      ui_show_message "Snapper | Inspeccion RO" "No se pudo montar snapshot en $target_path"
      return 1
   fi

   if ! mount -o remount,bind,ro "$target_path" >/dev/null 2>&1; then
      umount "$target_path" >/dev/null 2>&1 || true
      ui_show_message "Snapper | Inspeccion RO" "No se pudo remount en solo lectura: $target_path"
      return 1
   fi

   info_lines=(
      "Snapshot #$snap_id montado en solo lectura"
      ""
      "Ruta de inspeccion: $target_path"
      ""
      "Ejemplos utiles desde otra terminal:"
      "- ls -lah $target_path"
      "- ls -lah $target_path/etc"
      "- cat $target_path/etc/fstab"
      ""
      "Este montaje es SOLO LECTURA (equivalente a inspeccion, no rollback)."
   )
   ui_show_text_box "Snapper | Inspeccion RO activa" info_lines "ENTER para continuar"

   ui_run_menu \
      "Snapper | Inspeccion RO" \
      "Que hacer con el montaje temporal?" \
      post_options \
      "Flechas: mover | ENTER: confirmar | q/Esc: volver"

   if [[ "$UI_MENU_EVENT" != "QUIT" && "$UI_MENU_SELECTED" -eq 0 ]]; then
      umount "$target_path" >/dev/null 2>&1 || true
      rmdir "$target_path" >/dev/null 2>&1 || true
      rmdir "$mount_base" >/dev/null 2>&1 || true
      ui_show_message "Snapper | Inspeccion RO" "Montaje desmontado: $target_path"
   else
      ui_show_message "Snapper | Inspeccion RO" "Montaje conservado: $target_path"
   fi
}

restore_snapper_local() {
   local snapper_lines=()
   local restore_options=(
      "undochange (en vivo, sin reboot) - revierte archivos entre dos snapshots"
      "rollback   (requiere reboot)     - reemplaza /@ en el proximo arranque"
      "Cancelar"
   )
   local confirm_options=(
      "Confirmar y ejecutar"
      "Cancelar"
   )
   local from_id to_id snap_id

   mapfile -t snapper_lines < <(build_snapper_list_with_imp)
   ui_show_text_box "Snapper | Snapshots disponibles" snapper_lines "Anotar IDs y luego ENTER"

   ui_run_menu \
      "Snapper | Restaurar desde snapshot local" \
      "Elegir metodo de restauracion" \
      restore_options \
      "Flechas: mover | ENTER: seleccionar | q/Esc: cancelar"

   if [[ "$UI_MENU_EVENT" == "QUIT" || "$UI_MENU_SELECTED" -eq 2 ]]; then
      return 1
   fi

   if [[ "$UI_MENU_SELECTED" -eq 0 ]]; then
      # undochange
      from_id="$(ui_prompt_input "ID snapshot origen (pre)" "")"
      to_id="$(ui_prompt_input "ID snapshot destino (post, 0 = estado actual)" "0")"

      if [[ ! "$from_id" =~ ^[0-9]+$ || ! "$to_id" =~ ^[0-9]+$ ]]; then
         ui_show_message "Snapper | Restaurar" "IDs invalidos: origen=${from_id:-vacio} destino=${to_id:-vacio}"
         return 1
      fi

      local warn_lines=(
         "ATENCION: undochange revierte archivos en el sistema en vivo."
         ""
         "Accion: snapper undochange ${from_id}..${to_id}"
         ""
         "- Los archivos modificados entre esos snapshots seran revertidos."
         "- No requiere reboot."
         "- El sistema sigue corriendo durante el proceso."
         ""
         "Asegurate de cerrar aplicaciones que usen archivos afectados."
      )
      ui_show_text_box "Snapper | Advertencia undochange" warn_lines "ENTER para continuar"

      ui_run_menu \
         "Snapper | Confirmar undochange" \
         "Ejecutar snapper undochange ${from_id}..${to_id}?" \
         confirm_options \
         "Flechas: mover | ENTER: confirmar | q/Esc: cancelar"

      if [[ "$UI_MENU_EVENT" == "QUIT" || "$UI_MENU_SELECTED" -eq 1 ]]; then
         return 1
      fi

      admin_run_report "Snapper | undochange ${from_id}..${to_id}" \
         snapper -c root undochange "${from_id}..${to_id}"

   else
      # rollback
      snap_id="$(ui_prompt_input "ID snapshot a usar como nuevo /@" "")"

      if [[ ! "$snap_id" =~ ^[0-9]+$ ]]; then
         ui_show_message "Snapper | Restaurar" "ID invalido: ${snap_id:-vacio}"
         return 1
      fi

      local warn_lines=(
         "ATENCION: rollback reemplaza /@ en el proximo arranque."
         ""
         "Accion: snapper rollback ${snap_id}"
         ""
         "- El snapshot ${snap_id} se convertira en el nuevo subvolumen /@."
         "- REQUIERE REBOOT para activarse."
         "- El /@ actual NO se pierde (queda como snapshot en /.snapshots)."
         "- Sugerencia: primero usar 'Inspeccionar snapshot (solo lectura)'."
         ""
         "Despues del reboot el sistema arrancara desde el snapshot ${snap_id}."
      )
      ui_show_text_box "Snapper | Advertencia rollback" warn_lines "ENTER para continuar"

      ui_run_menu \
         "Snapper | Confirmar rollback" \
         "Ejecutar snapper rollback ${snap_id}?" \
         confirm_options \
         "Flechas: mover | ENTER: confirmar | q/Esc: cancelar"

      if [[ "$UI_MENU_EVENT" == "QUIT" || "$UI_MENU_SELECTED" -eq 1 ]]; then
         return 1
      fi

      admin_run_report "Snapper | rollback ${snap_id}" \
         snapper rollback "$snap_id"
   fi
}

admin_snapper_main() {
   local snapper_options=(
      "Configuracion actual"
      "Listado de ultimos snapshots"
      "Realizar snapshot ahora"
   "Inspeccionar snapshot (solo lectura)"
      "Restaurar desde snapshot local"
      "Comparar snapshots locales"
      "Snapshots importantes"
      "Snapshots en USB"
      "Volver"
   )

   while true; do
      ui_run_menu \
         "Administracion | Snapper" \
         "Herramientas de snapshots locales" \
         snapper_options \
         "Flechas: mover | ENTER: ejecutar | q/Esc: volver"

      if [[ "$UI_MENU_EVENT" == "QUIT" ]]; then
         return 0
      fi

      case "$UI_MENU_SELECTED" in
         0) show_snapper_config || true ;;
         1) show_snapper_snapshots || true ;;
         2) run_snapper_now || true ;;
         3) inspect_snapper_snapshot_readonly || true ;;
         4) restore_snapper_local || true ;;
         5) snapper_compare_menu || true ;;
         6) manage_important_snapshots || true ;;
         7) usb_snapper_menu || true ;;
         8) return 0 ;;
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
   admin_snapper_main
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
   main "$@"
fi
