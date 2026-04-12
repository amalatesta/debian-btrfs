#!/bin/bash
set -euo pipefail

# ============================================
# Version 008
# Fecha: 2026-04-12
#
# Historial de mejoras
# - 0008.0001 - Base bash+tput (menu + motor integrado) - OK
# - 0008.0002 - Ayuda integrada + refactor UI generica (confirm, preview, run_with_progress) - OK
# - 0008.0003 - Opcion 2 externalizada en script propio (primera parte) - OK
# - 0008.0004 - Ampliar opcion 2 con flujo dry-run controlado - OK
# - 0008.0005 - Mostrar informe completo del dry-run en UI con scroll - OK
# - 0008.0006 - Simulacion interactiva inicial con sugerencia de EFI - Pendiente validacion
# ============================================

MAIN_TITLE="Debian Btrfs Installer v008"
MAIN_PROMPT="Selecciona una opcion:"
MAIN_OPTIONS=(
    "Iniciar instalacion"
    "Modo prueba (dry-run)"
    "Ayuda"
    "Salir"
)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPTION2_SCRIPT="dry_run.sh"

THEME_TITLE="Seleccion de Color"
THEME_PROMPT="Elige una paleta para continuar:"
THEME_OPTIONS=("Blanco" "Naranja" "Verde")
YES_NO_OPTIONS=("Si" "No")
BUTTONS=("Aceptar" "Cancelar")

BOX_W=76
BOX_H=18
START_COL=0
START_ROW=0

BASE_BOX_W=76
BASE_BOX_H=18
MIN_BOX_W=50
MIN_BOX_H=14
MAX_TEXT_BOX_W=100
MAX_TEXT_BOX_H=24
TEXT_BOX_PAGE_LINE_LIMIT=16

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

show_help_screen() {
    local HELP_LINES=(
        "Este es un prototipo de interfaz en bash+tput."
        ""
        "Navegacion:"
        "  - Flechas arriba/abajo: mover opcion"
        "  - TAB / izquierda-derecha: mover foco"
        "  - ENTER: seleccionar o confirmar"
        ""
        "Estado actual:"
        "  - Opcion 3: abre esta ayuda"
        "  - Opcion 4: salir del script"
        "  - Opciones 1 y 2: en construccion"
    )

    show_centered_text_box "AYUDA - Debian Btrfs Installer v008" HELP_LINES "ENTER/Esc/q: volver al menu" "normal"
}

get_text_box_profile() {
    local profile="${1:-normal}"

    case "$profile" in
        compact)
            # base_w|base_h|min_w|min_h|max_w|max_h|page_limit
            echo "68|16|50|14|90|20|10"
            ;;
        wide-log)
            echo "84|18|56|14|116|28|14"
            ;;
        normal|*)
            echo "${BASE_BOX_W}|${BASE_BOX_H}|${MIN_BOX_W}|${MIN_BOX_H}|${MAX_TEXT_BOX_W}|${MAX_TEXT_BOX_H}|${TEXT_BOX_PAGE_LINE_LIMIT}"
            ;;
    esac
}

show_centered_text_box() {
    local title="$1"
    local lines_name="$2"
    local footer="$3"
    local profile="${4:-normal}"
    local -n lines_ref="$lines_name"
    local key footer_view
    local total_lines start end count offset max_offset
    local profile_spec
    local p_base_w p_base_h p_min_w p_min_h p_max_w p_max_h p_page_limit
    local VIEW_LINES
    local jump_size

    profile_spec="$(get_text_box_profile "$profile")"
    IFS='|' read -r p_base_w p_base_h p_min_w p_min_h p_max_w p_max_h p_page_limit <<< "$profile_spec"

    total_lines=${#lines_ref[@]}
    if (( total_lines < 1 )); then
        VIEW_LINES=("")
        draw_centered_text_frame "$title" VIEW_LINES "$footer" "$p_base_w" "$p_base_h" "$p_min_w" "$p_min_h" "$p_max_w" "$p_max_h"
        while true; do
            key="$(get_key_raw)"
            case "$key" in
                ENTER|ESC|QUIT)
                    return 0
                    ;;
            esac
        done
    fi

    offset=0
    max_offset=$(( total_lines - p_page_limit ))
    (( max_offset < 0 )) && max_offset=0
    jump_size=$((p_page_limit - 2))
    (( jump_size < 1 )) && jump_size=1

    while true; do
        start=$offset
        end=$((start + p_page_limit))
        (( end > total_lines )) && end=$total_lines
        count=$((end - start))

        if (( count > 0 )); then
            VIEW_LINES=("${lines_ref[@]:start:count}")
        else
            VIEW_LINES=("")
        fi

        if (( total_lines > p_page_limit )); then
            footer_view="${footer} | Up/Down/PgUp/PgDn: scroll (${start+1}-${end}/${total_lines}) | ENTER/Esc/q: cerrar"
        else
            footer_view="$footer"
        fi

        draw_centered_text_frame "$title" VIEW_LINES "$footer_view" "$p_base_w" "$p_base_h" "$p_min_w" "$p_min_h" "$p_max_w" "$p_max_h"

        key="$(get_key_raw)"
        case "$key" in
            UP)
                if (( offset > 0 )); then
                    offset=$((offset - 1))
                fi
                ;;
            DOWN)
                if (( offset < max_offset )); then
                    offset=$((offset + 1))
                fi
                ;;
            PGUP)
                if (( offset > 0 )); then
                    offset=$((offset - jump_size))
                    (( offset < 0 )) && offset=0
                fi
                ;;
            PGDN)
                if (( offset < max_offset )); then
                    offset=$((offset + jump_size))
                    (( offset > max_offset )) && offset=$max_offset
                fi
                ;;
            ENTER|ESC|QUIT)
                return 0
                ;;
        esac
    done
}

draw_centered_text_frame() {
    local title="$1"
    local lines_name="$2"
    local footer="$3"
    local base_w="$4"
    local base_h="$5"
    local min_w="$6"
    local min_h="$7"
    local max_w="$8"
    local max_h="$9"
    local -n lines_ref="$lines_name"
    local i line line_row content_width max_lines
    local max_len title_len footer_len desired_w desired_h

    max_len=0
    for line in "${lines_ref[@]}"; do
        (( ${#line} > max_len )) && max_len=${#line}
    done

    title_len=${#title}
    footer_len=${#footer}
    (( title_len > max_len )) && max_len=$title_len
    (( footer_len > max_len )) && max_len=$footer_len

    desired_w=$((max_len + 6))
    (( desired_w < base_w )) && desired_w=$base_w
    (( desired_w > max_w )) && desired_w=$max_w

    desired_h=$(( ${#lines_ref[@]} + 6 ))
    (( desired_h < base_h )) && desired_h=$base_h
    (( desired_h > max_h )) && desired_h=$max_h

    calc_layout_with_target "$desired_w" "$desired_h" "$min_w" "$min_h"
    clear
    draw_frame

    tput cup $((START_ROW + 1)) $((START_COL + 2))
    printf "%s%s%s" "$C_TITLE" "$title" "$C_RESET"

    content_width=$((BOX_W - 4))
    max_lines=$((BOX_H - 6))
    for ((i = 0; i < ${#lines_ref[@]} && i < max_lines; i++)); do
        line="${lines_ref[$i]}"
        line_row=$((START_ROW + 3 + i))
        tput cup "$line_row" $((START_COL + 2))
        printf "%s%-*.*s%s" "$C_TEXT" "$content_width" "$content_width" "$line" "$C_RESET"
    done

    tput cup $((START_ROW + BOX_H - 2)) $((START_COL + 2))
    printf "%s%s%s" "$C_HELP" "$footer" "$C_RESET"
}

calc_layout_with_target() {
    local target_w="$1"
    local target_h="$2"
    local min_w="${3:-$MIN_BOX_W}"
    local min_h="${4:-$MIN_BOX_H}"
    local cols lines

    cols="$(tput cols)"
    lines="$(tput lines)"

    BOX_W="$target_w"
    BOX_H="$target_h"

    (( BOX_W > cols - 2 )) && BOX_W=$((cols - 2))
    (( BOX_H > lines - 2 )) && BOX_H=$((lines - 2))
    (( BOX_W < min_w )) && BOX_W=$min_w
    (( BOX_H < min_h )) && BOX_H=$min_h

    START_COL=$(( (cols - BOX_W) / 2 ))
    START_ROW=$(( (lines - BOX_H) / 2 ))
}

show_info_box() {
    local title="$1"
    local lines_name="$2"
    local footer="${3:-ENTER/Esc/q: volver}"
    local profile="${4:-normal}"
    show_centered_text_box "$title" "$lines_name" "$footer" "$profile"
}

show_message_box() {
    local title="$1"
    local message="$2"
    local footer="${3:-ENTER/Esc/q: volver}"
    local profile="${4:-normal}"
    local MSG_LINES=("$message")

    show_info_box "$title" MSG_LINES "$footer" "$profile"
}

show_todo_screen() {
    local feature_name="$1"
    local TODO_LINES=(
        "${feature_name}"
        ""
        "Esta parte se implementara en una proxima iteracion."
        "La UI ya esta preparada para reutilizar este cuadro."
    )

    show_info_box "EN CONSTRUCCION" TODO_LINES "ENTER/Esc/q: volver al menu" "compact"
}

show_success_box() {
    local lines_name="$1"
    show_info_box "OK" "$lines_name" "ENTER/Esc/q: continuar" "compact"
}

show_error_box() {
    local lines_name="$1"
    show_info_box "ERROR" "$lines_name" "ENTER/Esc/q: volver" "compact"
}

show_command_preview() {
    local title="$1"
    local command="$2"
    local note="${3:-Revisar antes de ejecutar.}"
    local PREVIEW_LINES=(
        "Comando previsto:"
        ""
        "$command"
        ""
        "$note"
    )

    show_info_box "$title" PREVIEW_LINES "ENTER/Esc/q: volver al menu" "wide-log"
}

flush_input_buffer() {
    local key
    while IFS= read -rsn1 -t 0.01 key; do
        :
    done
}

choose_efi_size() {
    local suggested="$1"
    local EFI_SIM_OPTIONS=(
        "Aceptar sugerido (${suggested})"
        "1G"
        "2G"
        "4G"
        "Cancelar"
    )

    flush_input_buffer

    run_menu "SIMULACION | EFI" "Elige tamano de EFI para simulacion" EFI_SIM_OPTIONS 0 0 "Flechas: mover | ENTER: confirmar | Esc/q: cancelar" 1 0

    if [[ "$MENU_EVENT" == "QUIT" ]]; then
        return 1
    fi

    case "$MENU_SELECTED" in
        0) printf '%s\n' "$suggested" ;;
        1) printf '1G\n' ;;
        2) printf '2G\n' ;;
        3) printf '4G\n' ;;
        4) return 1 ;;
        *) printf '%s\n' "$suggested" ;;
    esac
}

confirm_yes_no() {
    local title="$1"
    local prompt="$2"
    local default_selected="${3:-1}"

    run_menu "$title" "$prompt" YES_NO_OPTIONS 0 0 "Flechas: mover | ENTER: confirmar | Esc/q: cancelar" 0 "$default_selected"

    if [[ "$MENU_EVENT" == "QUIT" ]]; then
        return 1
    fi

    [[ "$MENU_SELECTED" -eq 0 ]]
}

run_with_progress() {
    local title="$1"
    local command="$2"
    local success_note="${3:-Comando finalizado correctamente.}"
    local error_note="${4:-El comando termino con error.}"
    local log_file rc

    log_file="$(mktemp)"

    (bash -lc "$command" >"$log_file" 2>&1)
    rc=$?

    local OUTPUT_LINES=(
        "Comando ejecutado:"
        ""
        "$command"
        ""
        "Codigo de salida: $rc"
    )

    if [[ "$rc" -eq 0 ]]; then
        OUTPUT_LINES+=("" "$success_note")
        show_success_box OUTPUT_LINES
    else
        OUTPUT_LINES+=("" "$error_note")
        show_error_box OUTPUT_LINES
    fi

    # Muestra una vista resumida de salida para diagnostico rapido.
    mapfile -t OUTPUT_TAIL < <(tail -n 6 "$log_file" 2>/dev/null || true)
    if (( ${#OUTPUT_TAIL[@]} > 0 )); then
        local TAIL_LINES=("Ultimas lineas de salida:" "")
        TAIL_LINES+=("${OUTPUT_TAIL[@]}")
        show_info_box "SALIDA (RESUMEN)" TAIL_LINES "ENTER/Esc/q: volver" "wide-log"
    fi

    rm -f "$log_file"

    return "$rc"
}

run_with_report() {
    local title="$1"
    local command="$2"
    local success_note="${3:-Comando finalizado correctamente.}"
    local error_note="${4:-El comando termino con error.}"
    local log_file rc

    log_file="$(mktemp)"

    (bash -lc "$command" >"$log_file" 2>&1) &
    local run_pid=$!
    local spinner=("|" "/" "-" "\\")
    local spin_idx=0
    local profile_spec
    local p_base_w p_base_h p_min_w p_min_h p_max_w p_max_h p_page_limit
    local STATUS_LINES
    local TAIL_LINES

    profile_spec="$(get_text_box_profile "compact")"
    IFS='|' read -r p_base_w p_base_h p_min_w p_min_h p_max_w p_max_h p_page_limit <<< "$profile_spec"

    while true; do
        mapfile -t TAIL_LINES < <(tail -n 3 "$log_file" 2>/dev/null || true)

        STATUS_LINES=(
            "Ejecutando analisis dry-run..."
            ""
            "Esto puede tardar unos segundos segun el hardware."
            ""
            "Estado: en curso ${spinner[$spin_idx]}"
            ""
            "Ultimo log:"
        )

        if (( ${#TAIL_LINES[@]} > 0 )); then
            STATUS_LINES+=("${TAIL_LINES[-1]}")
        else
            STATUS_LINES+=("iniciando...")
        fi

        STATUS_LINES+=("" "No cierres esta pantalla.")

        draw_centered_text_frame "$title" STATUS_LINES "Procesando..." "$p_base_w" "$p_base_h" "$p_min_w" "$p_min_h" "$p_max_w" "$p_max_h"
        spin_idx=$(( (spin_idx + 1) % 4 ))

        if ! kill -0 "$run_pid" 2>/dev/null; then
            break
        fi

        sleep 0.12
    done

    if wait "$run_pid"; then
        rc=0
    else
        rc=$?
    fi

    mapfile -t REPORT_LINES < "$log_file"
    if (( ${#REPORT_LINES[@]} == 0 )); then
        REPORT_LINES=("Sin salida generada por el comando.")
    fi

    show_info_box "$title" REPORT_LINES "Informe completo" "wide-log"

    local RESULT_LINES=(
        "Comando ejecutado:"
        ""
        "$command"
        ""
        "Codigo de salida: $rc"
    )

    if [[ "$rc" -eq 0 ]]; then
        RESULT_LINES+=("" "$success_note")
        show_info_box "OK" RESULT_LINES "ENTER/Esc/q: continuar" "normal"
    else
        RESULT_LINES+=("" "$error_note")
        show_info_box "ERROR" RESULT_LINES "ENTER/Esc/q: volver" "normal"
    fi

    rm -f "$log_file"

    return "$rc"
}

run_dryrun_part1() {
    local option2_path="${SCRIPT_DIR}/${OPTION2_SCRIPT}"
    local efi_size
    local precheck_lines=(
        "Modo prueba (dry-run)"
        ""
        "Se ejecutara un script externo de diagnostico:"
        "  ${OPTION2_SCRIPT}"
        ""
        "Se hara una simulacion de la opcion 1 sin aplicar cambios."
        "Primero se preguntara una configuracion sugerida y luego se mostrara"
        "el informe final completo dentro de esta UI."
    )

    show_info_box "DRY-RUN" precheck_lines "ENTER/Esc/q: continuar" "normal"

    if [[ ! -f "$option2_path" ]]; then
        local missing_lines=(
            "No se encontro el archivo requerido:"
            "$OPTION2_SCRIPT"
            ""
            "Verifica el repo y vuelve a intentar."
        )
        show_error_box missing_lines
        return 1
    fi

    if ! confirm_yes_no "CONFIRMAR PRUEBA" "Ejecutar opcion 2 ahora?" 0; then
        return 0
    fi

    flush_input_buffer

    if ! efi_size="$(choose_efi_size "1G")"; then
        return 0
    fi

    if run_with_report "DRY-RUN | INFORME" "DRYRUN_EFI_SIZE=\"$efi_size\" bash \"$option2_path\"" "Opcion 2 completada." "Opcion 2 fallo."; then
        local ok_lines=(
            "Ejecucion completada."
            ""
            "EFI elegido para la simulacion: $efi_size"
            "Se mostro el informe completo del dry-run."
            "No se realizaron cambios en disco."
        )
        show_info_box "OK" ok_lines "ENTER/Esc/q: continuar" "normal"
    fi
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
    calc_layout_with_target "$BASE_BOX_W" "$BASE_BOX_H"
}

get_key_raw() {
    local k rest read_status tail
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
            "[5")
                IFS= read -rsn1 tail || true
                [[ "${tail:-}" == "~" ]] && echo "PGUP" || echo "ESC"
                ;;
            "[6")
                IFS= read -rsn1 tail || true
                [[ "${tail:-}" == "~" ]] && echo "PGDN" || echo "ESC"
                ;;
            "OM") echo "ENTER" ;;
            "Op") echo "DIGIT:0" ;;
            "Oq") echo "DIGIT:1" ;;
            "Or") echo "DIGIT:2" ;;
            "Os") echo "DIGIT:3" ;;
            "Ot") echo "DIGIT:4" ;;
            "Ou") echo "DIGIT:5" ;;
            "Ov") echo "DIGIT:6" ;;
            "Ow") echo "DIGIT:7" ;;
            "Ox") echo "DIGIT:8" ;;
            "Oy") echo "DIGIT:9" ;;
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
        run_menu "$MAIN_TITLE" "$MAIN_PROMPT" MAIN_OPTIONS 1 1 "Flechas: mover | TAB: foco | ENTER: seleccionar/confirmar | q: salir" 1 0

        if [[ "$MENU_EVENT" == "QUIT" ]]; then
            result="Cancelado"
            break
        fi

        case "$MENU_SELECTED" in
            0)
                show_command_preview "INSTALACION (PREVIEW)" "bash scripts/005_debian-btrfs-installer.sh" "En siguientes iteraciones se ejecutara desde este flujo."
                ;;
            1)
                run_dryrun_part1
                ;;
            2)
                show_help_screen
                ;;
            3)
                if confirm_yes_no "CONFIRMAR SALIDA" "Deseas salir del instalador?" 1; then
                    result="Salir"
                    break
                fi
                ;;
        esac
    done

    cleanup
    trap - EXIT INT TERM
    printf "Resultado: %s\n" "$result"
}

main
