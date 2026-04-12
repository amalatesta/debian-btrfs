#!/bin/bash
set -euo pipefail

# ============================================
# Version 008
# Fecha: 2026-04-11
#
# Historial de mejoras
# - 0008.0001 - Base limpia
# ============================================

if ! command -v whiptail >/dev/null 2>&1; then
    echo "ERROR: whiptail no esta instalado."
    echo "Instala con: sudo apt install whiptail"
    exit 1
fi

if [[ ! -t 0 || ! -t 1 ]]; then
    echo "ERROR: Este script requiere una terminal interactiva (TTY)."
    exit 1
fi

tmp_choice="$(mktemp)"
trap 'rm -f "$tmp_choice"' EXIT

if ! whiptail \
    --title "Debian Btrfs Installer v008" \
    --ok-button "Aceptar" \
    --cancel-button "Cancelar" \
    --menu "Selecciona una opcion:" \
    16 76 4 \
    "1" "Iniciar instalacion" \
    "2" "Modo prueba (dry-run)" \
    "3" "Ayuda" \
    "4" "Salir" \
    2>"$tmp_choice"; then
    echo "Cancelado por el usuario."
    exit 0
fi

choice="$(cat "$tmp_choice")"
choice="$(printf '%s' "$choice" | tr -d '\r\n' | xargs)"

echo "Opcion seleccionada: $choice"
echo "(Demo v008: sin accion)"
