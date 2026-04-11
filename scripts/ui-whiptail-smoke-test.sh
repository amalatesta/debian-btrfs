#!/bin/bash
set -euo pipefail

# Smoke test minimo de UI en TTY con whiptail.

if ! command -v whiptail >/dev/null 2>&1; then
    echo "ERROR: whiptail no esta instalado."
    echo "Instala con: sudo apt install whiptail"
    exit 1
fi

if [[ ! -t 0 || ! -t 1 ]]; then
    echo "ERROR: Este test requiere una terminal interactiva (TTY)."
    exit 1
fi

whiptail --title "Test UI Debian Btrfs" --msgbox "Prueba de interfaz whiptail.\n\nSi ves esta ventana, la UI base funciona." 12 70

choice="$(whiptail \
    --title "Test UI Debian Btrfs" \
    --menu "Selecciona una opcion:" \
    14 70 4 \
    "1" "Seguir" \
    "2" "Salir" \
    --output-fd 1)" || {
    echo "Cancelado por el usuario (ESC)."
    exit 0
}

case "$choice" in
    1)
        whiptail --title "Resultado" --msgbox "Elegiste: Seguir" 10 50
        echo "Resultado: Seguir"
        ;;
    2)
        whiptail --title "Resultado" --msgbox "Elegiste: Salir" 10 50
        echo "Resultado: Salir"
        ;;
    *)
        whiptail --title "Error" --msgbox "Opcion invalida recibida: $choice" 10 70
        echo "ERROR: opcion invalida: $choice"
        exit 1
        ;;
esac
