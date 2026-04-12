#!/bin/bash
set -euo pipefail

# Smoke test UI en bash+tput (sin whiptail).
# Objetivo: probar look tipo dialog y flujo de foco:
# - ENTER sobre lista mueve foco a botones
# - ENTER en Aceptar confirma opcion

if [[ ! -t 0 || ! -t 1 ]]; then
    echo "ERROR: Este test requiere una terminal interactiva (TTY)."
    exit 1
fi

stty -echo -icanon time 0 min 0

cleanup() {
    stty sane 2>/dev/null || true
    tput sgr0 2>/dev/null || true
    tput cnorm 2>/dev/null || true
    clear
}
trap cleanup EXIT INT TERM

tput civis

# Paleta simple con fallback si la terminal no soporta color.
if [[ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]]; then
    C_RESET="$(tput sgr0)"
    C_BORDER="$(tput setaf 6)"
    C_TITLE="$(tput bold)$(tput setaf 3)"
    C_PROMPT="$(tput setaf 2)"
    C_TEXT="$(tput setaf 7)"
    C_HELP="$(tput setaf 4)"
    C_OPT_NORMAL="$(tput setaf 6)"
else
    C_RESET=""
    C_BORDER=""
    C_TITLE=""
    C_PROMPT=""
    C_TEXT=""
    C_HELP=""
    C_OPT_NORMAL=""
fi

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
result=""

get_key() {
    local k rest
    IFS= read -rsn1 k || true

    if [[ -z "${k:-}" ]]; then
        echo "NONE"
        return 0
    fi

    if [[ "$k" == $'\x1b' ]]; then
        IFS= read -rsn2 rest || true
        case "${rest:-}" in
            "[A") echo "UP" ;;
            "[B") echo "DOWN" ;;
            "[C") echo "RIGHT" ;;
            "[D") echo "LEFT" ;;
            *) echo "ESC" ;;
        esac
        return 0
    fi

    case "$k" in
        $'\t') echo "TAB" ;;
        "") echo "ENTER" ;;
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
    local cols lines box_w box_h start_col start_row
    cols="$(tput cols)"
    lines="$(tput lines)"

    box_w=76
    box_h=18

    (( box_w > cols - 2 )) && box_w=$((cols - 2))
    (( box_h > lines - 2 )) && box_h=$((lines - 2))
    (( box_w < 50 )) && box_w=50
    (( box_h < 14 )) && box_h=14

    start_col=$(( (cols - box_w) / 2 ))
    start_row=$(( (lines - box_h) / 2 ))

    clear

    draw_box_line "$start_row" "$start_col" "$box_w"

    local i
    for ((i = 1; i < box_h - 1; i++)); do
        tput cup $((start_row + i)) "$start_col"
        printf "%s" "$C_BORDER"
        printf "|"
        tput cup $((start_row + i)) $((start_col + box_w - 1))
        printf "|"
        printf "%s" "$C_RESET"
    done

    draw_box_line $((start_row + box_h - 1)) "$start_col" "$box_w"

    tput cup $((start_row + 1)) $((start_col + 2))
    printf "%s" "$C_TITLE"
    printf "%s" "$TITLE"
    printf "%s" "$C_RESET"

    tput cup $((start_row + 3)) $((start_col + 2))
    printf "%s" "$C_PROMPT"
    printf "%s" "$PROMPT"
    printf "%s" "$C_RESET"

    local opt_row
    for i in "${!OPTIONS[@]}"; do
        opt_row=$((start_row + 5 + i))
        tput cup "$opt_row" $((start_col + 4))

        if [[ $i -eq $selected_option ]]; then
            # Opcion seleccionada siempre en azul.
            tput setaf 7
            tput setab 4
            printf " %-60s " "${OPTIONS[$i]}"
            tput sgr0
        else
            printf "%s" "$C_OPT_NORMAL"
            printf " %-60s " "${OPTIONS[$i]}"
            printf "%s" "$C_RESET"
        fi
    done

    local btn_row btn_col_accept btn_col_cancel
    btn_row=$((start_row + box_h - 3))
    btn_col_accept=$((start_col + box_w - 28))
    btn_col_cancel=$((start_col + box_w - 15))

    tput cup "$btn_row" "$btn_col_accept"
    if [[ "$focus" == "buttons" && $selected_button -eq 0 ]]; then
        tput setaf 7
        tput setab 1
        printf "< %s >" "${BUTTONS[0]}"
        tput sgr0
    else
        printf "%s" "$C_TEXT"
        printf "< %s >" "${BUTTONS[0]}"
        printf "%s" "$C_RESET"
    fi

    tput cup "$btn_row" "$btn_col_cancel"
    if [[ "$focus" == "buttons" && $selected_button -eq 1 ]]; then
        tput setaf 7
        tput setab 1
        printf "< %s >" "${BUTTONS[1]}"
        tput sgr0
    else
        printf "%s" "$C_TEXT"
        printf "< %s >" "${BUTTONS[1]}"
        printf "%s" "$C_RESET"
    fi

    tput cup $((start_row + box_h - 2)) $((start_col + 2))
    printf "%s" "$C_HELP"
    printf "Flechas: mover | TAB: foco | ENTER: seleccionar/confirmar | q: salir"
    printf "%s" "$C_RESET"
}

while true; do
    draw_ui

    key="$(get_key)"
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
            else
                focus="list"
            fi
            ;;
        ENTER)
            if [[ "$focus" == "list" ]]; then
                # Enter en lista no ejecuta: pasa el foco a Aceptar.
                focus="buttons"
                selected_button=0
            else
                if [[ $selected_button -eq 0 ]]; then
                    result="${OPTIONS[$selected_option]}"
                    break
                else
                    result="Cancelado"
                    break
                fi
            fi
            ;;
        ESC|QUIT)
            result="Cancelado"
            break
            ;;
        NONE|OTHER)
            ;;
    esac

    sleep 0.02
done

cleanup
printf "Resultado: %s\n" "$result"
