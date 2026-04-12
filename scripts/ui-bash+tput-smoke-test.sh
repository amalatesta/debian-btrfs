#!/bin/bash
set -euo pipefail

# Smoke test UI en bash+tput (sin whiptail).
# Base generica reusable para 008.

MAIN_TITLE="Test UI bash+tput"
MAIN_PROMPT="Selecciona una opcion:"
MAIN_OPTIONS=(
    "Iniciar instalacion"
    "Modo prueba (dry-run)"
    "Ayuda"
    "Salir"
)

THEME_TITLE="Seleccion de Color"
THEME_PROMPT="Elige una paleta para continuar:"
THEME_OPTIONS=("Blanco" "Naranja" "Verde")

BUTTONS=("Aceptar" "Cancelar")

BOX_W=76
BOX_H=18
START_COL=0
START_ROW=0

MENU_EVENT=""
MENU_SELECTED=0
result=""

C_RESET=""
C_BORDER=""
C_TITLE=""
C_PROMPT=""
C_TEXT=""
C_HELP=""
C_OPT_NORMAL=""
C_FOCUS=""
C_ORANGE_FG=""

ensure_tty() {
    if [[ ! -t 0 || ! -t 1 ]]; then
        echo "ERROR: Este test requiere una terminal interactiva (TTY)."
        exit 1
    fi
}

setup_terminal() {
    stty -echo -icanon min 1 time 0
    tput civis
}

restore_terminal() {
    stty sane 2>/dev/null || true
    tput sgr0 2>/dev/null || true
    tput cnorm 2>/dev/null || true
}

cleanup() {
    restore_terminal
    clear
}

init_palette() {
    C_RESET="(B[m"

    if [[ "256" -ge 8 ]]; then
        if [[ "256" -ge 256 ]]; then
            C_ORANGE_FG=""[38"
        else
            C_ORANGE_FG="[33m"
        fi
        apply_theme "green"
    fi
}

apply_theme() {
    local theme=""

    if [[ "256" -lt 8 ]]; then
        C_BORDER=""
        C_TITLE=""
        C_PROMPT=""
        C_TEXT=""
        C_HELP=""
        C_OPT_NORMAL=""
        C_FOCUS=""
        return 0
    fi

    local fg bg
    case "" in
        white)
            fg="[37m"
            bg="[47m"
            ;;
        orange)
            fg=""
            if [[ "256" -ge 256 ]]; then
                bg=""[48"
            else
                bg="[43m"
            fi
            ;;
        green|*)
            if [[ "256" -ge 16 ]]; then
                fg=""[92m""
                bg=""[102m""
            else
                fg="[32m"
                bg="[42m"
            fi
            ;;
    esac

    C_BORDER=""
    C_TITLE="[1m"
    C_PROMPT=""
    C_TEXT=""
    C_HELP=""
    C_OPT_NORMAL=""
    C_FOCUS="[30m"
}

calc_layout() {
    local cols lines
    cols="88"
    lines="19"

    BOX_W=76
    BOX_H=18

    (( BOX_W > cols - 2 )) && BOX_W=-2
    (( BOX_H > lines - 2 )) && BOX_H=-2
    (( BOX_W < 50 )) && BOX_W=50
    (( BOX_H < 14 )) && BOX_H=14

    START_COL=0
    START_ROW=0
}

get_key_raw() {
    local k rest read_status
    IFS= read -rsn1 k
    read_status=0

    if [[  -ne 0 ]]; then
        echo "OTHER"
        return 0
    fi

    if [[ -z "" ]]; then
        echo "ENTER"
        return 0
    fi

    if [[ "" == $
