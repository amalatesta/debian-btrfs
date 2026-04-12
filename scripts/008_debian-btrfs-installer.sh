#!/bin/bash
set -euo pipefail

# ============================================
# Version 008
# Fecha: 2026-04-12
#
# Historial de mejoras
# - 0008.0001 - Base bash+tput con menu principal
# - 0008.0002 - Integracion completa del motor de ui-bash+tput-smoke-test
# ============================================

MAIN_TITLE="Debian Btrfs Installer v008"
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
    C_RESET="$(tput sgr0 2>/dev/null || true)"

    if [[ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]]; then
        if [[ "$(tput colors 2>/dev/null || echo 0)" -ge 256 ]]; then
            C_ORANGE_FG="$(printf '\033[38;5;208m')"
        else
            C_ORANGE_FG="$(tput setaf 3)"
        fi
        apply_theme "green"
    fi
}

apply_theme() {
    local theme="$1"

    if [[ "$(tput colors 2>/dev/null || echo 0)" -lt 8 ]]; then
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
    case "$theme" in
        white)
            fg="$(tput setaf 7)"
            bg="$(tput setab 7)"
            ;;
        orange)
            fg="$C_ORANGE_FG"
            if [[ "$(tput colors 2>/dev/null || echo 0)" -ge 256 ]]; then
                bg="$(printf '\033[48;5;208m')"
            else
                bg="$(tput setab 3)"
            fi
            ;;
        green|*)
            if [[ "$(tput colors 2>/dev/null || echo 0)" -ge 16 ]]; then
                fg="$(printf '\033[92m')"
                bg="$(printf '\033[102m')"
            else
                fg="$(tput setaf 2)"
                bg="$(tput setab 2)"
            fi
            ;;
    esac

    C_BORDER="$fg"
    C_TITLE="$(tput bold)${fg}"
    C_PROMPT="$fg"
    C_TEXT="$fg"
    C_HELP="$fg"
    C_OPT_NORMAL="$fg"
    C_FOCUS="$(tput setaf 0)${bg}"
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
        [0-9]) echo "DIGIT:$k" ;;
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

draw_generic_menu() {
    local title="$1"
    local prompt="$2"
    local opts_name="$3"
    local selected="$4"
    local show_buttons="$5"
    local focus="$6"
    local selected_button="$7"
    local help_text="$8"
    local show_numbers="$9"
    local -n opts_ref="$opts_name"
    local i row label

    calc_layout
    clear
    draw_frame

    tput cup $((START_ROW + 1)) $((START_COL + 2))
    printf "%s%s%s" "$C_TITLE" "$title" "$C_RESET"

    tput cup $((START_ROW + 3)) $((START_COL + 2))
    printf "%s%s%s" "$C_PROMPT" "$prompt" "$C_RESET"

    for i in "${!opts_ref[@]}"; do
        row=$((START_ROW + 5 + i))
        tput cup "$row" $((START_COL + 4))

        if [[ "$show_numbers" -eq 1 ]]; then
            label="$((i + 1)). ${opts_ref[$i]}"
        else
            label="${opts_ref[$i]}"
        fi

        if [[ $i -eq $selected ]]; then
            printf "%s %-60s %s" "$C_FOCUS" "$label" "$C_RESET"
        else
            printf "%s %-60s %s" "$C_OPT_NORMAL" "$label" "$C_RESET"
        fi
    done

    if [[ "$show_buttons" -eq 1 ]]; then
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
    fi

    tput cup $((START_ROW + BOX_H - 2)) $((START_COL + 2))
    printf "%s%s%s" "$C_HELP" "$help_text" "$C_RESET"
}

run_menu() {
    local title="$1"
    local prompt="$2"
    local opts_name="$3"
    local show_buttons="$4"
    local allow_numeric="$5"
    local help_text="$6"
    local show_numbers="$7"
    local default_selected="$8"
    local -n opts_ref="$opts_name"

    local selected="$default_selected"
    local focus="list"
    local selected_button=0
    local confirm_armed=0
    local key digit idx

    MENU_EVENT=""
    MENU_SELECTED=0

    while true; do
        draw_generic_menu "$title" "$prompt" "$opts_name" "$selected" "$show_buttons" "$focus" "$selected_button" "$help_text" "$show_numbers"
        key="$(get_key_raw)"

        if [[ "$key" == DIGIT:* ]]; then
            if [[ "$allow_numeric" -eq 1 ]]; then
                digit="${key#DIGIT:}"
                idx=$((digit - 1))
                if (( idx >= 0 && idx < ${#opts_ref[@]} )); then
                    MENU_EVENT="SELECT"
                    MENU_SELECTED="$idx"
                    return 0
                fi
            fi
            key="OTHER"
        fi

        case "$key" in
            UP)
                if [[ "$focus" == "list" ]]; then
                    if (( selected > 0 )); then
                        selected=$((selected - 1))
                    else
                        selected=$((${#opts_ref[@]} - 1))
                    fi
                else
                    confirm_armed=0
                fi
                ;;
            DOWN)
                if [[ "$focus" == "list" ]]; then
                    if (( selected < ${#opts_ref[@]} - 1 )); then
                        selected=$((selected + 1))
                    else
                        selected=0
                    fi
                else
                    confirm_armed=0
                fi
                ;;
            LEFT)
                if [[ "$show_buttons" -eq 1 && "$focus" == "buttons" ]]; then
                    selected_button=0
                    confirm_armed=0
                fi
                ;;
            RIGHT)
                if [[ "$show_buttons" -eq 1 && "$focus" == "buttons" ]]; then
                    selected_button=1
                    confirm_armed=0
                fi
                ;;
            TAB)
                if [[ "$show_buttons" -eq 1 ]]; then
                    if [[ "$focus" == "list" ]]; then
                        focus="buttons"
                        confirm_armed=0
                    else
                        focus="list"
                        confirm_armed=0
                    fi
                fi
                ;;
            ENTER)
                if [[ "$show_buttons" -eq 0 ]]; then
                    MENU_EVENT="SELECT"
                    MENU_SELECTED="$selected"
                    return 0
                fi

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
                if [[ "$show_buttons" -eq 1 ]]; then
                    focus="list"
                    confirm_armed=0
                fi
                ;;
            QUIT)
                MENU_EVENT="QUIT"
                return 0
                ;;
            OTHER)
                if [[ "$show_buttons" -eq 1 && "$focus" == "buttons" ]]; then
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

    apply_theme "white"
    run_menu "$THEME_TITLE" "$THEME_PROMPT" THEME_OPTIONS 0 1 "Flechas: mover | ENTER: seleccionar color | 1-3 directo | q: salir" 1 2

    if [[ "$MENU_EVENT" == "QUIT" ]]; then
        result="Cancelado"
        cleanup
        trap - EXIT INT TERM
        printf "Resultado: %s\n" "$result"
        return 0
    fi

    case "$MENU_SELECTED" in
        0) apply_theme "white" ;;
        1) apply_theme "orange" ;;
        2) apply_theme "green" ;;
        *) apply_theme "green" ;;
    esac

    while true; do
        run_menu "$MAIN_TITLE" "$MAIN_PROMPT" MAIN_OPTIONS 1 0 "Flechas: mover | TAB: foco | ENTER: seleccionar/confirmar | q: salir" 1 0

        if [[ "$MENU_EVENT" == "QUIT" ]]; then
            result="Cancelado"
            break
        fi

        if (( MENU_SELECTED == 3 )); then
            result="Salir"
            break
        fi
    done

    cleanup
    trap - EXIT INT TERM
    printf "Resultado: %s\n" "$result"
}

main
