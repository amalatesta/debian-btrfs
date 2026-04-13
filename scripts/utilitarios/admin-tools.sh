#!/usr/bin/env bash
set -euo pipefail

ADMIN_TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/admin_ui.sh
source "${ADMIN_TOOLS_DIR}/lib/admin_ui.sh"
# shellcheck source=lib/admin_actions.sh
source "${ADMIN_TOOLS_DIR}/lib/admin_actions.sh"

MAIN_TITLE="Debian Btrfs Admin Tools"
MAIN_PROMPT="Selecciona una herramienta administrativa:"
MAIN_OPTIONS=(
   "Ver contexto de arranque"
   "Reporte de salud de backups"
   "Ejecutar btrbk ahora"
   "Gestion de particion recovery"
   "Exportar snapshot GOLDEN a USB"
   "Comparar snapshots"
   "Ver README de utilitarios"
   "Ayuda"
   "Salir"
)

main() {
   ui_require_tty
   admin_require_root
   admin_require_scripts
   ui_init_theme
   ui_setup_terminal
   trap ui_cleanup EXIT INT TERM

   while true; do
      ui_run_menu \
         "$MAIN_TITLE" \
         "$MAIN_PROMPT" \
         MAIN_OPTIONS \
         "Flechas: mover | ENTER: ejecutar | q/Esc: salir"

      if [[ "$UI_MENU_EVENT" == "QUIT" ]]; then
         break
      fi

      case "$UI_MENU_SELECTED" in
         0) admin_show_boot_context || true ;;
         1) admin_show_backup_health || true ;;
         2) admin_run_btrbk_now || true ;;
         3) admin_recovery_partition_menu || true ;;
         4) admin_usb_golden_export || true ;;
         5) admin_snapshot_compare_menu || true ;;
         6) admin_show_utilitarios_readme || true ;;
         7) admin_show_help || true ;;
         8) break ;;
      esac
   done
}

main "$@"
