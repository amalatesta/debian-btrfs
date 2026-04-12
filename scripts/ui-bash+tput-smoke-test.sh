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
THEME_OPTIONS=("Blanco" "Naranja" "Verde")

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

get_key() {
    local k rest read_status
    IFS= read -rsn1 k
    read_status=$?

    if [[ $read_status -ne 0 ]]; then
        echo "OTHER"
        return 0
    fi

    if [[ -z "${k:-}" ]]; then
        # Lectura vacia espuria: no tratar como ENTER para evitar acciones fantasmas.
        echo "OTHER"
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

draw_theme_ui() {
    local selected_theme="$1"
    local i row label color

    calc_layout
    clear
    draw_frame

    tput cup $((START_ROW + 1)) $((START_COL + 2))
    printf "%sSeleccion de Color%s" "$C_TITLE" "$C_RESET"

    tput cup $((START_ROW + 3)) $((START_COL + 2))
    printf "%sElige una paleta para continuar:%s" "$C_PROMPT" "$C_RESET"

    for i in "${!THEME_OPTIONS[@]}"; do
        row=$((START_ROW + 5 + i))
        label="$((i + 1)). ${THEME_OPTIONS[$i]}"
        tput cup "$row" $((START_COL + 4))

        case "$i" in
            0) color="$(tput setaf 7 2>/dev/null || true)" ;;
            1) color="$C_ORANGE_FG" ;;
            2) color="$(tput setaf 2 2>/dev/null || true)" ;;
        esac

        if [[ $i -eq $selected_theme ]]; then
            printf "%s %-60s %s" "$C_FOCUS" "$label" "$C_RESET"
        else
            printf "%s %-60s %s" "$color" "$label" "$C_RESET"
        fi
    done

    tput cup $((START_ROW + BOX_H - 2)) $((START_COL + 2))
    printf "%sFlechas: mover | ENTER: seleccionar color | q: salir%s" "$C_HELP" "$C_RESET"
}

run_theme_selector() {
    local selected_theme=2
    local key

    # El selector inicial se muestra siempre en blanco.
    apply_theme "white"

    while true; do
        draw_theme_ui "$selected_theme"
        key="$(get_key)"

        case "$key" in
            UP)
                (( selected_theme > 0 )) && selected_theme=$((selected_theme - 1))
                ;;
            DOWN)
                (( selected_theme < ${#THEME_OPTIONS[@]} - 1 )) && selected_theme=$((selected_theme + 1))
                ;;
            ENTER)
                case "$selected_theme" in
                    0) apply_theme "white" ;;
                    1) apply_theme "orange" ;;
                    2) apply_theme "green" ;;
                esac
                return 0
                ;;
            QUIT)
                result="Cancelado"
                exit_requested=1
                return 0
                ;;
            ESC|TAB|LEFT|RIGHT|OTHER)
                ;;
        esac
    done
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
                # TAB solo mueve foco. No debe habilitar salida por Enter.
                confirm_armed=0
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

    run_theme_selector

    if [[ $exit_requested -eq 1 ]]; then
        cleanup
        trap - EXIT INT TERM
        printf "Resultado: %s\n" "$result"
        return 0
    fi

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
