#!/bin/bash
set -euo pipefail

# Smoke test UI en bash+tput (sin whiptail).
# Base modular para reutilizar en 008.

TITLE="Test UI bash+tput"
PROMPT="Selecciona una opcion:"
OPTIONS=(
    "Iniciar instalacion"
    "Modo prueba (dry-run)"
    "Ayuda"
    "Salir"
)
BUTTONS=("Aceptar" "Cancelar")

selected_option=0
selected_button=0
focus="list"   # list | buttons
confirm_armed=0
exit_requested=0
result=""

BOX_W=76
BOX_H=18
START_COL=0
START_ROW=0

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
    if [[ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]]; then
        C_RESET="$(tput sgr0)"
        if [[ "$(tput colors 2>/dev/null || echo 0)" -ge 16 ]]; then
            C_GREEN="$(printf '\033[92m')"
            C_BG_GREEN="$(printf '\033[102m')"
        else
            C_GREEN="$(tput setaf 2)"
            C_BG_GREEN="$(tput setab 2)"
        fi
        C_BORDER="${C_GREEN}"
        C_TITLE="$(tput bold)${C_GREEN}"
        C_PROMPT="${C_GREEN}"
        C_TEXT="${C_GREEN}"
        C_HELP="${C_GREEN}"
        C_OPT_NORMAL="${C_GREEN}"
        C_FOCUS="$(tput setaf 0)${C_BG_GREEN}"
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

get_key() {
    local k rest
    IFS= read -rsn1 k || true

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

draw_frame() {
    local i
    draw_box_line "$START_ROW" "$START_COL" "$BOX_W"
    for ((i = 1; i < BOX_H - 1; i++)); do
        tput cup $((START_ROW + i)) "$START_COL"
        printf "%s|%s" "$C_BORDER" "$C_RESET"
        tput cup $((START_ROW + i)) $((START_COL + BOX_W - 1))
        printf "%s|%s" "$C_BORDER" "$C_RESET"
    done
    draw_box_line $((START_ROW + BOX_H - 1)) "$START_COL" "$BOX_W"
}

draw_header() {
    tput cup $((START_ROW + 1)) $((START_COL + 2))
    printf "%s%s%s" "$C_TITLE" "$TITLE" "$C_RESET"

    tput cup $((START_ROW + 3)) $((START_COL + 2))
    printf "%s%s%s" "$C_PROMPT" "$PROMPT" "$C_RESET"
}

draw_options() {
    local i opt_row opt_label
    for i in "${!OPTIONS[@]}"; do
        opt_row=$((START_ROW + 5 + i))
        tput cup "$opt_row" $((START_COL + 4))
        opt_label="$((i + 1)). ${OPTIONS[$i]}"

        if [[ $i -eq $selected_option ]]; then
            printf "%s %-60s %s" "$C_FOCUS" "$opt_label" "$C_RESET"
        else
            printf "%s %-60s %s" "$C_OPT_NORMAL" "$opt_label" "$C_RESET"
        fi
    done
}

draw_buttons() {
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
}

draw_help() {
    tput cup $((START_ROW + BOX_H - 2)) $((START_COL + 2))
    printf "%sFlechas: mover | TAB: foco | ENTER: seleccionar/confirmar | q: salir%s" "$C_HELP" "$C_RESET"
}

draw_ui() {
    calc_layout
    clear
    draw_frame
    draw_header
    draw_options
    draw_buttons
    draw_help
}

handle_enter() {
    if [[ "$focus" == "list" ]]; then
        focus="buttons"
        selected_button=0
        confirm_armed=1
        return 0
    fi

    if [[ $selected_button -eq 0 && $confirm_armed -eq 1 ]]; then
        if [[ $selected_option -eq 3 ]]; then
            result="Salir"
            exit_requested=1
        else
            focus="list"
            confirm_armed=0
        fi
        return 0
    fi

    # Cancelar vuelve a la lista.
    focus="list"
    confirm_armed=0
}

handle_key() {
    local key="$1"

    case "$key" in
        UP)
            if [[ "$focus" == "list" ]]; then
                (( selected_option > 0 )) && selected_option=$((selected_option - 1))
            fi
            ;;
        DOWN)
            if [[ "$focus" == "list" ]]; then
                (( selected_option < ${#OPTIONS[@]} - 1 )) && selected_option=$((selected_option + 1))
            fi
            ;;
        LEFT)
            if [[ "$focus" == "buttons" ]]; then
                selected_button=0
            fi
            ;;
        RIGHT)
            if [[ "$focus" == "buttons" ]]; then
                selected_button=1
            fi
            ;;
        TAB)
            if [[ "$focus" == "list" ]]; then
                focus="buttons"
                confirm_armed=1
            else
                focus="list"
                confirm_armed=0
            fi
            ;;
        ENTER)
            handle_enter
            ;;
        ESC)
            focus="list"
            confirm_armed=0
            ;;
        QUIT)
            result="Cancelado"
            exit_requested=1
            ;;
        OTHER)
            ;;
    esac
}

main() {
    ensure_tty
    init_palette
    setup_terminal
    trap cleanup EXIT INT TERM

    while true; do
        draw_ui
        key="$(get_key)"
        handle_key "$key"

        if [[ $exit_requested -eq 1 ]]; then
            break
        fi
    done

    cleanup
    trap - EXIT INT TERM
    printf "Resultado: %s\n" "$result"
}

main
