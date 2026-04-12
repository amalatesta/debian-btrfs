#!/bin/bash
set -euo pipefail

# ============================================
# Version 008
# Fecha: 2026-04-11
#
# Historial de mejoras
# - 0008.0001 - Base bash+tput con menu principal
# ============================================

TITLE="Debian Btrfs Installer v008"
PROMPT="Selecciona una opcion:"
OPTIONS=(
    "Iniciar instalacion"
    "Modo prueba (dry-run)"
    "Ayuda"
    "Salir"
)
BUTTONS=("Aceptar" "Cancelar")

BOX_W=76
BOX_H=18
START_COL=0
START_ROW=0

MENU_EVENT=""
MENU_SELECTED=0
RESULT=""

C_RESET=""
C_BORDER=""
C_TITLE=""
C_PROMPT=""
C_TEXT=""
C_HELP=""
C_OPT_NORMAL=""
C_FOCUS=""

ensure_tty() {
    if [[ ! -t 0 || ! -t 1 ]]; then
        echo "ERROR: Este script requiere una terminal interactiva (TTY)."
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
    C_RESET="$(tput sgr0 2>/dev/null || true)"

    if [[ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]]; then
        local fg bg
        if [[ "$(tput colors 2>/dev/null || echo 0)" -ge 16 ]]; then
            fg="$(printf '\033[92m')"
            bg="$(printf '\033[102m')"
        else
            fg="$(tput setaf 2)"
            bg="$(tput setab 2)"
        fi

        C_BORDER="$fg"
        C_TITLE="$(tput bold)${fg}"
        C_PROMPT="$fg"
        C_TEXT="$fg"
        C_HELP="$fg"
        C_OPT_NORMAL="$fg"
        C_FOCUS="$(tput setaf 0)${bg}"
    fi
}

calc_layout() {
    local cols lines
    cols="$(tput cols)"
    lines="$(tput lines)"

    BOX_W=76
    BOX_H=18

    (( BOX_W > cols - 2 )) && BOX_W=$((cols - 2))
    (( BOX_H > lines - 2 )) && BOX_H=$((lines - 2))
    (( BOX_W < 50 )) && BOX_W=50
    (( BOX_H < 14 )) && BOX_H=14

    START_COL=$(( (cols - BOX_W) / 2 ))
    START_ROW=$(( (lines - BOX_H) / 2 ))
}

get_key_raw() {
    local k rest read_status
    IFS= read -rsn1 k
    read_status=$?

    if [[ $read_status -ne 0 ]]; then
        echo "OTHER"
        return 0
    fi

    if [[ -z "${k:-}" ]]; then
        echo "ENTER"
        return 0
    fi

    if [[ "$k" == $'\x1b' ]]; then
        IFS= read -rsn2 rest || true
        case "${rest:-}" in
            "[A") echo "UP" ;;
            "[B") echo "DOWN" ;;
            "[C") echo "RIGHT" ;;
            "[D") echo "LEFT" ;;
            "OM") echo "ENTER" ;;
            *) echo "ESC" ;;
        esac
        return 0
    fi

    case "$k" in
        $'\t') echo "TAB" ;;
        $'\n'|$'\r') echo "ENTER" ;;
        q|Q) echo "QUIT" ;;
        *) echo "OTHER" ;;
    esac
}

draw_box_line() {
    local row="$1"
    local col="$2"
    local width="$3"
    tput cup "$row" "$col"
    printf "%s" "$C_BORDER"
    printf "+"
    printf '%*s' $((width - 2)) '' | tr ' ' '-'
    printf "+"
    printf "%s" "$C_RESET"
}

draw_ui() {
    local i row label
    local selected="$1"
    local focus="$2"
    local selected_button="$3"

    calc_layout
    clear

    draw_box_line "$START_ROW" "$START_COL" "$BOX_W"
    for ((i = 1; i < BOX_H - 1; i++)); do
        tput cup $((START_ROW + i)) "$START_COL"
        printf "%s|%s" "$C_BORDER" "$C_RESET"
        tput cup $((START_ROW + i)) $((START_COL + BOX_W - 1))
        printf "%s|%s" "$C_BORDER" "$C_RESET"
    done
    draw_box_line $((START_ROW + BOX_H - 1)) "$START_COL" "$BOX_W"

    tput cup $((START_ROW + 1)) $((START_COL + 2))
    printf "%s%s%s" "$C_TITLE" "$TITLE" "$C_RESET"

    tput cup $((START_ROW + 3)) $((START_COL + 2))
    printf "%s%s%s" "$C_PROMPT" "$PROMPT" "$C_RESET"

    for i in "${!OPTIONS[@]}"; do
        row=$((START_ROW + 5 + i))
        label="$((i + 1)). ${OPTIONS[$i]}"
        tput cup "$row" $((START_COL + 4))

        if [[ $i -eq $selected ]]; then
            printf "%s %-60s %s" "$C_FOCUS" "$label" "$C_RESET"
        else
            printf "%s %-60s %s" "$C_OPT_NORMAL" "$label" "$C_RESET"
        fi
    done

    local btn_row btn_col_accept btn_col_cancel
    btn_row=$((START_ROW + BOX_H - 3))
    btn_col_accept=$((START_COL + BOX_W - 28))
    btn_col_cancel=$((START_COL + BOX_W - 15))

    tput cup "$btn_row" "$btn_col_accept"
    if [[ "$focus" == "buttons" && $selected_button -eq 0 ]]; then
        printf "%s< %s >%s" "$C_FOCUS" "${BUTTONS[0]}" "$C_RESET"
    else
        printf "%s< %s >%s" "$C_TEXT" "${BUTTONS[0]}" "$C_RESET"
    fi

    tput cup "$btn_row" "$btn_col_cancel"
    if [[ "$focus" == "buttons" && $selected_button -eq 1 ]]; then
        printf "%s< %s >%s" "$C_FOCUS" "${BUTTONS[1]}" "$C_RESET"
    else
        printf "%s< %s >%s" "$C_TEXT" "${BUTTONS[1]}" "$C_RESET"
    fi

    tput cup $((START_ROW + BOX_H - 2)) $((START_COL + 2))
    printf "%sFlechas: mover | TAB: foco | ENTER: seleccionar/confirmar | q: salir%s" "$C_HELP" "$C_RESET"
}

run_main_menu() {
    local selected=0
    local focus="list"
    local selected_button=0
    local confirm_armed=0
    local key

    MENU_EVENT=""
    MENU_SELECTED=0

    while true; do
        draw_ui "$selected" "$focus" "$selected_button"
        key="$(get_key_raw)"

        case "$key" in
            UP)
                if [[ "$focus" == "list" ]]; then
                    if (( selected > 0 )); then
                        selected=$((selected - 1))
                    else
                        selected=$((${#OPTIONS[@]} - 1))
                    fi
                else
                    confirm_armed=0
                fi
                ;;
            DOWN)
                if [[ "$focus" == "list" ]]; then
                    if (( selected < ${#OPTIONS[@]} - 1 )); then
                        selected=$((selected + 1))
                    else
                        selected=0
                    fi
                else
                    confirm_armed=0
                fi
                ;;
            LEFT)
                if [[ "$focus" == "buttons" ]]; then
                    selected_button=0
                    confirm_armed=0
                fi
                ;;
            RIGHT)
                if [[ "$focus" == "buttons" ]]; then
                    selected_button=1
                    confirm_armed=0
                fi
                ;;
            TAB)
                if [[ "$focus" == "list" ]]; then
                    focus="buttons"
                    confirm_armed=0
                else
                    focus="list"
                    confirm_armed=0
                fi
                ;;
            ENTER)
                if [[ "$focus" == "list" ]]; then
                    focus="buttons"
                    selected_button=0
                    confirm_armed=1
                else
                    if [[ $selected_button -eq 0 && $confirm_armed -eq 1 ]]; then
                        MENU_EVENT="SELECT"
                        MENU_SELECTED="$selected"
                        return 0
                    else
                        focus="list"
                        confirm_armed=0
                    fi
                fi
                ;;
            ESC)
                focus="list"
                confirm_armed=0
                ;;
            QUIT)
                MENU_EVENT="QUIT"
                return 0
                ;;
            OTHER)
                if [[ "$focus" == "buttons" ]]; then
                    confirm_armed=0
                fi
                ;;
        esac
    done
}

main() {
    ensure_tty
    init_palette
    setup_terminal
    trap cleanup EXIT INT TERM

    run_main_menu

    if [[ "$MENU_EVENT" == "QUIT" ]]; then
        RESULT="Cancelado"
    else
        RESULT="Seleccion: $((MENU_SELECTED + 1)). ${OPTIONS[$MENU_SELECTED]}"
    fi

    cleanup
    trap - EXIT INT TERM
    printf "%s\n" "$RESULT"
}

main
