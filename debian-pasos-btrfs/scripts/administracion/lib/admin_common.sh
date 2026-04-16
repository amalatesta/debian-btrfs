#!/usr/bin/env bash
# admin_common.sh — helpers compartidos para todos los scripts de administracion/
# Sourced por admin-general.sh, admin-snapper.sh, admin-btrbk.sh

ADMIN_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADMIN_BASE_DIR="$(cd "${ADMIN_COMMON_DIR}/.." && pwd)"
SCRIPTS_BASE="$(cd "${ADMIN_BASE_DIR}/../version_repo" && pwd)"
SETUP_BASE="$(cd "${ADMIN_BASE_DIR}/../version_pasos" && pwd)"
ADMIN_STATE_FILE="${ADMIN_BASE_DIR}/.admin-tools.conf"

# Scripts utilitarios (de version_repo, ya validados)
BOOT_CONTEXT_SCRIPT="${SCRIPTS_BASE}/show-boot-context.sh"
BACKUP_HEALTH_SCRIPT="${SCRIPTS_BASE}/backup-health-report.sh"
SNAPPER_RUN_SCRIPT="${SCRIPTS_BASE}/snapper-run-now.sh"
SNAPPER_CONFIG_SCRIPT="${SCRIPTS_BASE}/snapper-show-config.sh"
BTRBK_RUN_SCRIPT="${SCRIPTS_BASE}/btrbk-run-now.sh"
BTRBK_CONFIG_SCRIPT="${SCRIPTS_BASE}/btrbk-show-config.sh"
RECOVERY_SCRIPT="${SCRIPTS_BASE}/recovery-partition.sh"
USB_GOLDEN_SCRIPT="${SCRIPTS_BASE}/usb-golden-snapshot.sh"
SNAPSHOT_COMPARE_SCRIPT="${SCRIPTS_BASE}/snapshot-compare.sh"
SETUP_SNAPPER_SCRIPT="${SETUP_BASE}/setup-snapper.sh"
SETUP_BTRBK_SCRIPT="${SETUP_BASE}/setup-btrbk.sh"
SETUP_GRUB_BTRFS_SCRIPT="${SETUP_BASE}/setup-grub-btrfs.sh"
SETUP_GENERAL_SCRIPT="${SETUP_BASE}/setup-general.sh"

admin_require_root() {
   if [[ "${EUID}" -ne 0 ]]; then
      echo "ERROR: ejecutar con sudo: sudo $(basename "$0")"
      exit 1
   fi
}

admin_require_scripts() {
   local missing=0
   local file
   for file in \
      "$BOOT_CONTEXT_SCRIPT" \
      "$BACKUP_HEALTH_SCRIPT" \
      "$SNAPPER_RUN_SCRIPT" \
      "$SNAPPER_CONFIG_SCRIPT" \
      "$BTRBK_RUN_SCRIPT" \
      "$BTRBK_CONFIG_SCRIPT" \
      "$RECOVERY_SCRIPT" \
      "$USB_GOLDEN_SCRIPT" \
      "$SNAPSHOT_COMPARE_SCRIPT" \
      "$SETUP_SNAPPER_SCRIPT" \
      "$SETUP_BTRBK_SCRIPT" \
      "$SETUP_GRUB_BTRFS_SCRIPT" \
      "$SETUP_GENERAL_SCRIPT"; do
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

admin_get_usb_fstype() {
   lsblk -no FSTYPE "$1" 2>/dev/null | head -1
}

admin_normalize_device_path() {
   local raw_value="$1"
   local normalized="$raw_value"

   normalized="${normalized//$'\r'/}"
   normalized="${normalized//$'\n'/}"
   normalized="${normalized//$'\t'/}"
   normalized="${normalized//[[:cntrl:]]/}"
   normalized="${normalized#${normalized%%[![:space:]]*}}"
   normalized="${normalized%${normalized##*[![:space:]]}}"

   printf '%s\n' "$normalized"
}

# Verifica espacio libre en USB para el golden export.
# Exporta _USB_FREE_HUMAN y _ROOT_USED_HUMAN.
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

admin_show_boot_context() {
   admin_run_report "Estado actual del sistema" "$BOOT_CONTEXT_SCRIPT"
}

admin_get_saved_golden_device() {
   if [[ -f "$ADMIN_STATE_FILE" ]]; then
      awk -F= '/^GOLDEN_USB_DEVICE=/{print $2}' "$ADMIN_STATE_FILE" | tail -1
   fi
}

admin_save_golden_device() {
   local device="$1"

   mkdir -p "$(dirname "$ADMIN_STATE_FILE")"
   printf 'GOLDEN_USB_DEVICE=%s\n' "$device" > "$ADMIN_STATE_FILE"
}

admin_detect_golden_device() {
   local saved_device=""
   local detected_by_label=""
   local removable_parts=()

   saved_device="$(admin_get_saved_golden_device)"
   if [[ -n "$saved_device" && -b "$saved_device" ]]; then
      printf '%s\n' "$saved_device"
      return 0
   fi

   detected_by_label="$(lsblk -prno NAME,RM,TYPE,LABEL 2>/dev/null | awk '$2=="1" && $3=="part" && tolower($4)=="golden" {print $1; exit}')"
   if [[ -n "$detected_by_label" ]]; then
      printf '%s\n' "$detected_by_label"
      return 0
   fi

   mapfile -t removable_parts < <(lsblk -prno NAME,RM,TYPE 2>/dev/null | awk '$2=="1" && $3=="part" {print $1}')
   if (( ${#removable_parts[@]} == 1 )); then
      printf '%s\n' "${removable_parts[0]}"
      return 0
   fi

   return 1
}

admin_run_external_setup() {
   local title="$1"
   local script_path="$2"

   if [[ ! -x "$script_path" ]]; then
      ui_show_message "$title" "No se encontro ejecutable:\n$script_path"
      return 1
   fi

   ui_restore_terminal
   clear > /dev/tty
   printf "\n[%s]\n\n" "$title" > /dev/tty
   "$script_path" < /dev/tty > /dev/tty 2>&1
   printf "\nPresione Enter para volver a la interfaz..." > /dev/tty
   read -r _ < /dev/tty
   ui_setup_terminal
}
