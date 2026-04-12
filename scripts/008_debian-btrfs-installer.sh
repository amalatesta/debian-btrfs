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
# - 0008.0006 - Simulacion interactiva inicial con sugerencia de EFI - OK
# - 0008.0007 - Sumar mas preguntas guiadas fuera de UI con pantalla limpia - OK
# - 0008.0008 - Preguntas iniciales tipo Debian (locale/teclado/timezone) - OK
# - 0008.0009 - Red cerrada como requisito: salida a Internet preferentemente por Ethernet - OK
# - 0008.0010 - Completar preguntas faltantes (identidad + APT/software) con orden Debian - Pendiente validacion
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
OPTION1_SCRIPT="install.sh"
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
DRYRUN_SELECTED_EFI="1G"
DRYRUN_SELECTED_SYSTEM=""
DRYRUN_SELECTED_BACKUP="S"
DRYRUN_SELECTED_SWAP=""
DRYRUN_SELECTED_LOCALE=""
DRYRUN_SELECTED_KEYBOARD=""
DRYRUN_SELECTED_TIMEZONE=""
DRYRUN_SELECTED_HOSTNAME=""
DRYRUN_SELECTED_USERNAME=""
DRYRUN_SELECTED_USER_PASSWORD_SET="N"
DRYRUN_SELECTED_APT_ENABLE_NONFREE="S"
DRYRUN_SELECTED_APT_ENABLE_SECURITY="S"
DRYRUN_SELECTED_APT_ENABLE_UPDATES="S"
DRYRUN_SELECTED_APT_ENABLE_DEBSRC="N"
DRYRUN_SELECTED_APT_PROXY=""
DRYRUN_SELECTED_INSTALL_NONFREE_FIRMWARE="S"
DRYRUN_SELECTED_ENABLE_POPCON="N"
DRYRUN_SELECTED_SOFTWARE_INSTALL_MODE="POSTBOOT"
DRYRUN_SELECTED_INSTALL_SSH_IN_BASE="S"
DRYRUN_SELECTED_INSTALL_TASKSEL_NOW="N"
DRYRUN_SELECTED_DISK=""
DRYRUN_SELECTED_USER_PASSWORD=""

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

debounce_input() {
    flush_input_buffer
    sleep 0.15
    flush_input_buffer
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

    debounce_input

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

    (bash -lc "$command" >"$log_file" 2>&1)
    rc=$?

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

network_has_default_route() {
    command -v ip >/dev/null 2>&1 || return 1
    ip route show default 2>/dev/null | grep -q .
}

network_detect_wifi_iface() {
    local iface_path iface_name
    for iface_path in /sys/class/net/*; do
        iface_name="${iface_path##*/}"
        [[ "$iface_name" == "lo" ]] && continue
        if [[ -d "$iface_path/wireless" ]]; then
            printf '%s\n' "$iface_name"
            return 0
        fi
    done
    return 1
}

network_detect_ethernet_link() {
    local iface_path iface_name carrier
    for iface_path in /sys/class/net/*; do
        iface_name="${iface_path##*/}"
        [[ "$iface_name" == "lo" ]] && continue
        [[ -d "$iface_path/wireless" ]] && continue
        [[ -f "$iface_path/carrier" ]] || continue
        carrier="$(cat "$iface_path/carrier" 2>/dev/null || true)"
        if [[ "$carrier" == "1" ]]; then
            printf '%s\n' "$iface_name"
            return 0
        fi
    done
    return 1
}

prepare_network_in_plain_terminal() {
    local wifi_iface=""
    local ethernet_iface=""

    wifi_iface="$(network_detect_wifi_iface || true)"
    ethernet_iface="$(network_detect_ethernet_link || true)"

    clear > /dev/tty
    printf "\n[dry-run] red previa al analisis:\n\n" > /dev/tty

    if network_has_default_route; then
        printf "[dry-run] Red activa detectada. No hace falta preparar conectividad.\n" > /dev/tty
        [[ -n "$ethernet_iface" ]] && printf "[dry-run] Ethernet con enlace: %s\n" "$ethernet_iface" > /dev/tty
        [[ -n "$wifi_iface" ]] && printf "[dry-run] Wi-Fi detectada: %s\n" "$wifi_iface" > /dev/tty
        printf "\n[dry-run] continuando con la simulacion...\n" > /dev/tty
        sleep 0.6
        return 0
    fi

    [[ -n "$ethernet_iface" ]] && printf "[dry-run] Ethernet detectada con enlace: %s\n" "$ethernet_iface" > /dev/tty
    [[ -n "$wifi_iface" ]] && printf "[dry-run] Wi-Fi detectada: %s\n" "$wifi_iface" > /dev/tty

    if [[ -n "$wifi_iface" ]]; then
        printf "[dry-run] Nota: se detecta Wi-Fi, pero este flujo queda fuera de alcance validado.\n" > /dev/tty
    fi

    printf "[dry-run] Requisito actual: salida a Internet preferentemente por Ethernet.\n" > /dev/tty
    printf "[dry-run] Si no hay conectividad en el live, la instalacion no debe asumir descarga de paquetes.\n" > /dev/tty
    sleep 1
}

ask_efi_in_plain_terminal() {
    local option2_path="$1"
    local locale_value=""
    local language_code="" suggested_language=""
    local language_choice=""
    local location_value="" suggested_location=""
    local location_choice=""
    local keyboard_value="" suggested_keyboard=""
    local timezone_value="" suggested_timezone=""
    local hostname_value="" suggested_hostname=""
    local username_value="usuario" suggested_username="usuario"
    local user_password_set="N" suggested_user_password_set="N"
    local efi_size="" suggested_efi=""
    local system_size="" suggested_system=""
    local create_backup="" suggested_backup=""
    local swap_size="" suggested_swap=""
    local apt_enable_nonfree="S" suggested_apt_enable_nonfree="S"
    local apt_enable_security="S" suggested_apt_enable_security="S"
    local apt_enable_updates="S" suggested_apt_enable_updates="S"
    local apt_enable_debsrc="N" suggested_apt_enable_debsrc="N"
    local apt_proxy="" suggested_apt_proxy=""
    local install_nonfree_firmware="S" suggested_install_nonfree_firmware="S"
    local enable_popcon="N" suggested_enable_popcon="N"
    local software_install_mode="POSTBOOT" suggested_software_install_mode="POSTBOOT"
    local install_ssh_in_base="S" suggested_install_ssh_in_base="S"
    local install_tasksel_now="N" suggested_install_tasksel_now="N"
    local user_password=""
    local user_password_confirm=""
    local defaults_output key value
    local default_efi="1G"
    local default_system="64G"
    local default_backup="S"
    local default_swap="8G"
    local default_locale="en_US.UTF-8"
    local default_timezone="UTC"
    local default_keyboard="us"
    local default_keyboard_source="heuristica"
    local default_hostname="debian-pc"
    local run_keyboard_selector=""
    local quick_keyboard_choice=""
    local install_temp_tools=""

    restore_terminal
    clear > /dev/tty

    defaults_output="$(bash "$option2_path" --defaults 2>/dev/null || true)"
    while IFS='=' read -r key value; do
        case "$key" in
            DRYRUN_DEFAULT_EFI) default_efi="$value" ;;
            DRYRUN_DEFAULT_SYSTEM) default_system="$value" ;;
            DRYRUN_DEFAULT_CREATE_BACKUP) default_backup="$value" ;;
            DRYRUN_DEFAULT_SWAP) default_swap="$value" ;;
            DRYRUN_DEFAULT_LOCALE) default_locale="$value" ;;
            DRYRUN_DEFAULT_TIMEZONE) default_timezone="$value" ;;
            DRYRUN_DEFAULT_KEYBOARD) default_keyboard="$value" ;;
            DRYRUN_DEFAULT_KEYBOARD_SOURCE) default_keyboard_source="$value" ;;
            DRYRUN_DEFAULT_HOSTNAME) default_hostname="$value" ;;
        esac
    done <<< "$defaults_output"

    prepare_network_in_plain_terminal

    clear > /dev/tty
    printf "\n[dry-run] idioma (estilo Debian):\n" > /dev/tty

    case "$default_locale" in
        es_*) language_code="es" ;;
        pt_*) language_code="pt" ;;
        fr_*) language_code="fr" ;;
        de_*) language_code="de" ;;
        *) language_code="en" ;;
    esac
    suggested_language="$language_code"
    printf "[dry-run]   1) Espanol\n" > /dev/tty
    printf "[dry-run]   2) English\n" > /dev/tty
    printf "[dry-run]   3) Portugues\n" > /dev/tty
    printf "[dry-run]   4) Francais\n" > /dev/tty
    printf "[dry-run]   5) Deutsch\n" > /dev/tty
    printf "[dry-run]   6) Otro (manual)\n\n" > /dev/tty
    read -r -p "Opcion [1]: " language_choice < /dev/tty
    language_choice="${language_choice:-1}"
    case "$language_choice" in
        1) language_code="es" ;;
        2) language_code="en" ;;
        3) language_code="pt" ;;
        4) language_code="fr" ;;
        5) language_code="de" ;;
        6)
            read -r -p "Idioma (codigo ISO, ej: es/en/pt) [${language_code}] : " language_code < /dev/tty
            language_code="${language_code:-en}"
            ;;
        *) language_code="es" ;;
    esac

    case "$default_timezone" in
        America/Argentina*) location_value="Argentina" ;;
        Europe/Madrid) location_value="Espana" ;;
        America/Mexico_City) location_value="Mexico" ;;
        America/Bogota) location_value="Colombia" ;;
        America/Santiago) location_value="Chile" ;;
        America/Lima) location_value="Peru" ;;
        America/Montevideo) location_value="Uruguay" ;;
        *) location_value="Internacional" ;;
    esac
    suggested_location="$location_value"
    suggested_timezone="$default_timezone"

    clear > /dev/tty
    printf "\n[dry-run] pais / ubicacion:\n" > /dev/tty
    printf "[dry-run]   1) Argentina\n" > /dev/tty
    printf "[dry-run]   2) Espana\n" > /dev/tty
    printf "[dry-run]   3) Mexico\n" > /dev/tty
    printf "[dry-run]   4) Colombia\n" > /dev/tty
    printf "[dry-run]   5) Chile\n" > /dev/tty
    printf "[dry-run]   6) Peru\n" > /dev/tty
    printf "[dry-run]   7) Uruguay\n" > /dev/tty
    printf "[dry-run]   8) Internacional / US\n" > /dev/tty
    printf "[dry-run]   9) Otro (manual)\n\n" > /dev/tty
    read -r -p "Opcion [9]: " location_choice < /dev/tty
    location_choice="${location_choice:-9}"
    case "$location_choice" in
        1) location_value="Argentina"; default_timezone="America/Argentina/Buenos_Aires"; default_keyboard="latam" ;;
        2) location_value="Espana"; default_timezone="Europe/Madrid"; default_keyboard="es" ;;
        3) location_value="Mexico"; default_timezone="America/Mexico_City"; default_keyboard="latam" ;;
        4) location_value="Colombia"; default_timezone="America/Bogota"; default_keyboard="latam" ;;
        5) location_value="Chile"; default_timezone="America/Santiago"; default_keyboard="latam" ;;
        6) location_value="Peru"; default_timezone="America/Lima"; default_keyboard="latam" ;;
        7) location_value="Uruguay"; default_timezone="America/Montevideo"; default_keyboard="latam" ;;
        8) location_value="Internacional"; default_timezone="UTC"; default_keyboard="us" ;;
        *)
            read -r -p "Pais/ubicacion (texto libre) [${location_value}] : " location_value < /dev/tty
            location_value="${location_value:-Internacional}"
            ;;
    esac

    case "$language_code" in
        es)
            case "$location_value" in
                Argentina) default_locale="es_AR.UTF-8" ;;
                Espana) default_locale="es_ES.UTF-8" ;;
                Mexico) default_locale="es_MX.UTF-8" ;;
                Colombia) default_locale="es_CO.UTF-8" ;;
                Chile) default_locale="es_CL.UTF-8" ;;
                Peru) default_locale="es_PE.UTF-8" ;;
                Uruguay) default_locale="es_UY.UTF-8" ;;
                *) default_locale="es_ES.UTF-8" ;;
            esac
            ;;
        en) default_locale="en_US.UTF-8" ;;
        pt)
            if [[ "$location_value" == "Espana" || "$location_value" == "Internacional" ]]; then
                default_locale="pt_PT.UTF-8"
            else
                default_locale="pt_BR.UTF-8"
            fi
            ;;
        fr) default_locale="fr_FR.UTF-8" ;;
        de) default_locale="de_DE.UTF-8" ;;
        *) default_locale="en_US.UTF-8" ;;
    esac
    locale_value="$default_locale"
    DRYRUN_SELECTED_LOCALE="$locale_value"

    if [[ -z "$default_keyboard" ]] && [[ "$locale_value" == es_* ]]; then
        default_keyboard="es"
    fi
    suggested_keyboard="$default_keyboard"
    suggested_efi="$default_efi"
    suggested_system="$default_system"
    suggested_swap="$default_swap"
    suggested_backup="$default_backup"

    if command -v dpkg-reconfigure >/dev/null 2>&1; then
        clear > /dev/tty
        printf "\n[dry-run] se puede abrir selector real de Debian.\n\n" > /dev/tty
        printf "[dry-run] Nota: si ese selector muestra opciones no deseadas, luego\n" > /dev/tty
        printf "[dry-run] podras elegir rapido es/latam/us manualmente.\n\n" > /dev/tty
        read -r -p "Abrir selector de teclado ahora? [s/N]: " run_keyboard_selector < /dev/tty
        run_keyboard_selector="${run_keyboard_selector^^}"

        if [[ "$run_keyboard_selector" == "S" ]]; then
            clear > /dev/tty
            printf "[dry-run] abriendo selector de teclado...\n" > /dev/tty
            if [[ "$(id -u)" -eq 0 ]]; then
                dpkg-reconfigure keyboard-configuration < /dev/tty > /dev/tty 2>&1 || true
                setupcon < /dev/tty > /dev/tty 2>&1 || true
            else
                sudo dpkg-reconfigure keyboard-configuration < /dev/tty > /dev/tty 2>&1 || true
                sudo setupcon < /dev/tty > /dev/tty 2>&1 || true
            fi

            local detected_keyboard_after_selector
            detected_keyboard_after_selector="$(awk -F= '/^XKBLAYOUT=/{gsub(/"/,"",$2); print $2; exit}' /etc/default/keyboard 2>/dev/null || true)"
            if [[ -n "$detected_keyboard_after_selector" ]]; then
                default_keyboard="$detected_keyboard_after_selector"
                default_keyboard_source="selector-debian"
            fi
        fi
    fi

    clear > /dev/tty
    printf "\n[dry-run] selector rapido de teclado:\n" > /dev/tty
    printf "[dry-run]   1) es\n" > /dev/tty
    printf "[dry-run]   2) latam\n" > /dev/tty
    printf "[dry-run]   3) us\n" > /dev/tty
    printf "[dry-run]   4) mantener sugerido (%s)\n\n" "$default_keyboard" > /dev/tty
    read -r -p "Opcion [4]: " quick_keyboard_choice < /dev/tty
    quick_keyboard_choice="${quick_keyboard_choice:-4}"
    case "$quick_keyboard_choice" in
        1) default_keyboard="es" ;;
        2) default_keyboard="latam" ;;
        3) default_keyboard="us" ;;
        *) : ;;
    esac

    if [[ "$default_keyboard_source" != "system-file" ]]; then
        clear > /dev/tty
        printf "\n[dry-run] confirmacion: no se detecto teclado del sistema.\n" > /dev/tty
        printf "[dry-run] se puede instalar temporalmente (solo en Live) para mejorar deteccion.\n\n" > /dev/tty
        read -r -p "Instalar temporalmente herramientas de teclado? [s/N]: " install_temp_tools < /dev/tty
        install_temp_tools="${install_temp_tools^^}"

        if [[ "$install_temp_tools" == "S" ]]; then
            clear > /dev/tty
            printf "[dry-run] instalando temporalmente (console-setup, keyboard-configuration)...\n" > /dev/tty
            if DEBIAN_FRONTEND=noninteractive apt-get update -y >/dev/null 2>&1 && \
               DEBIAN_FRONTEND=noninteractive apt-get install -y console-setup keyboard-configuration >/dev/null 2>&1; then
                local detected_keyboard
                detected_keyboard="$(awk -F= '/^XKBLAYOUT=/{gsub(/"/,"",$2); print $2; exit}' /etc/default/keyboard 2>/dev/null || true)"
                if [[ -n "$detected_keyboard" ]]; then
                    default_keyboard="$detected_keyboard"
                fi
                printf "[dry-run] instalacion temporal completada.\n" > /dev/tty
            else
                printf "[dry-run] no se pudo instalar temporalmente (sin red o paquetes no disponibles).\n" > /dev/tty
            fi
            sleep 1
        fi
    fi

    keyboard_value="$default_keyboard"
    DRYRUN_SELECTED_KEYBOARD="$keyboard_value"

    clear > /dev/tty
    printf "\n[dry-run] timezone (derivada por ubicacion):\n\n" > /dev/tty
    read -r -p "Timezone [${default_timezone}] : " timezone_value < /dev/tty
    timezone_value="${timezone_value:-$default_timezone}"
    DRYRUN_SELECTED_TIMEZONE="$timezone_value"

    suggested_hostname="$default_hostname"
    clear > /dev/tty
    printf "\n[dry-run] identidad del sistema:\n\n" > /dev/tty
    read -r -p "Hostname [${default_hostname}] : " hostname_value < /dev/tty
    hostname_value="${hostname_value:-$default_hostname}"
    DRYRUN_SELECTED_HOSTNAME="$hostname_value"

    clear > /dev/tty
    printf "\n[dry-run] usuario principal (simulacion):\n\n" > /dev/tty
    read -r -p "Nombre de usuario [usuario] : " username_value < /dev/tty
    username_value="${username_value:-usuario}"
    DRYRUN_SELECTED_USERNAME="$username_value"

    while true; do
        clear > /dev/tty
        printf "\n[dry-run] password de usuario:\n\n" > /dev/tty
        read -r -s -p "Password para ${username_value}: " user_password < /dev/tty
        printf "\n" > /dev/tty
        if [[ -z "$user_password" ]]; then
            printf "[dry-run] La password no puede estar vacia.\n" > /dev/tty
            sleep 0.8
            continue
        fi

        read -r -s -p "Confirmar password: " user_password_confirm < /dev/tty
        printf "\n" > /dev/tty
        if [[ "$user_password" != "$user_password_confirm" ]]; then
            printf "[dry-run] Las passwords no coinciden. Reintenta.\n" > /dev/tty
            sleep 0.8
            continue
        fi

        user_password_set="S"
        break
    done
    DRYRUN_SELECTED_USER_PASSWORD_SET="$user_password_set"

    clear > /dev/tty
    printf "\n[dry-run] G : Gigas - M : Megas\n\n" > /dev/tty
    read -r -p "Tamano EFI [${default_efi}] : " efi_size < /dev/tty
    efi_size="${efi_size:-$default_efi}"
    DRYRUN_SELECTED_EFI="$efi_size"

    clear > /dev/tty
    printf "\n[dry-run] G : Gigas - M : Megas\n\n" > /dev/tty
    read -r -p "Tamano SISTEMA [${default_system}] : " system_size < /dev/tty
    system_size="${system_size:-$default_system}"
    DRYRUN_SELECTED_SYSTEM="$system_size"

    clear > /dev/tty
    printf "\n[dry-run] G : Gigas - M : Megas\n\n" > /dev/tty
    read -r -p "Tamano SWAP [${default_swap}] : " swap_size < /dev/tty
    swap_size="${swap_size:-$default_swap}"
    DRYRUN_SELECTED_SWAP="$swap_size"

    clear > /dev/tty
    printf "\n" > /dev/tty
    read -r -p "Crear particion de Backup? [S/n]: " create_backup < /dev/tty
    create_backup="${create_backup:-$default_backup}"
    create_backup="${create_backup^^}"
    if [[ "$create_backup" != "S" ]]; then
        create_backup="N"
    fi
    DRYRUN_SELECTED_BACKUP="$create_backup"

    clear > /dev/tty
    printf "\n[dry-run] preguntas no criticas (APT/software):\n\n" > /dev/tty
    read -r -p "Habilitar software no libre? [S/n]: " apt_enable_nonfree < /dev/tty
    apt_enable_nonfree="${apt_enable_nonfree:-S}"
    apt_enable_nonfree="${apt_enable_nonfree^^}"
    [[ "$apt_enable_nonfree" != "S" ]] && apt_enable_nonfree="N"
    DRYRUN_SELECTED_APT_ENABLE_NONFREE="$apt_enable_nonfree"

    clear > /dev/tty
    printf "\n[dry-run] preguntas no criticas (APT/software):\n\n" > /dev/tty
    read -r -p "Habilitar repositorio security? [S/n]: " apt_enable_security < /dev/tty
    apt_enable_security="${apt_enable_security:-S}"
    apt_enable_security="${apt_enable_security^^}"
    [[ "$apt_enable_security" != "S" ]] && apt_enable_security="N"
    DRYRUN_SELECTED_APT_ENABLE_SECURITY="$apt_enable_security"

    clear > /dev/tty
    printf "\n[dry-run] preguntas no criticas (APT/software):\n\n" > /dev/tty
    read -r -p "Habilitar repositorio updates? [S/n]: " apt_enable_updates < /dev/tty
    apt_enable_updates="${apt_enable_updates:-S}"
    apt_enable_updates="${apt_enable_updates^^}"
    [[ "$apt_enable_updates" != "S" ]] && apt_enable_updates="N"
    DRYRUN_SELECTED_APT_ENABLE_UPDATES="$apt_enable_updates"

    clear > /dev/tty
    printf "\n[dry-run] preguntas no criticas (APT/software):\n\n" > /dev/tty
    read -r -p "Incluir deb-src? [s/N]: " apt_enable_debsrc < /dev/tty
    apt_enable_debsrc="${apt_enable_debsrc:-N}"
    apt_enable_debsrc="${apt_enable_debsrc^^}"
    [[ "$apt_enable_debsrc" != "S" ]] && apt_enable_debsrc="N"
    DRYRUN_SELECTED_APT_ENABLE_DEBSRC="$apt_enable_debsrc"

    clear > /dev/tty
    printf "\n[dry-run] preguntas no criticas (APT/software):\n\n" > /dev/tty
    read -r -p "Proxy HTTP para APT [vacio=sin proxy]: " apt_proxy < /dev/tty
    DRYRUN_SELECTED_APT_PROXY="$apt_proxy"

    clear > /dev/tty
    printf "\n[dry-run] preguntas no criticas (APT/software):\n\n" > /dev/tty
    read -r -p "Instalar firmware no libre (si aplica)? [S/n]: " install_nonfree_firmware < /dev/tty
    install_nonfree_firmware="${install_nonfree_firmware:-S}"
    install_nonfree_firmware="${install_nonfree_firmware^^}"
    [[ "$install_nonfree_firmware" != "S" ]] && install_nonfree_firmware="N"
    DRYRUN_SELECTED_INSTALL_NONFREE_FIRMWARE="$install_nonfree_firmware"

    clear > /dev/tty
    printf "\n[dry-run] preguntas no criticas (APT/software):\n\n" > /dev/tty
    read -r -p "Participar en popularity-contest? [s/N]: " enable_popcon < /dev/tty
    enable_popcon="${enable_popcon:-N}"
    enable_popcon="${enable_popcon^^}"
    [[ "$enable_popcon" != "S" ]] && enable_popcon="N"
    DRYRUN_SELECTED_ENABLE_POPCON="$enable_popcon"

    clear > /dev/tty
    printf "\n[dry-run] modo de software base:\n" > /dev/tty
    printf "[dry-run]   1) AUTO        (instala base + set estandar automaticamente)\n" > /dev/tty
    printf "[dry-run]   2) INTERACTIVE (abre seleccion interactiva de paquetes/tareas)\n" > /dev/tty
    printf "[dry-run]   3) POSTBOOT    (deja la instalacion minima; software despues del primer arranque) [RECOMENDADA]\n\n" > /dev/tty
    printf "[dry-run] resumen rapido:\n" > /dev/tty
    printf "[dry-run]   AUTO: para dejar el sistema util desde el primer reinicio.\n" > /dev/tty
    printf "[dry-run]   INTERACTIVE: para elegir manualmente que instalar.\n" > /dev/tty
    printf "[dry-run]   POSTBOOT: para instalar lo minimo y personalizar luego.\n\n" > /dev/tty
    read -r -p "Opcion [3 - RECOMENDADA]: " software_install_mode < /dev/tty
    software_install_mode="${software_install_mode:-3}"
    case "$software_install_mode" in
        1|AUTO|auto) software_install_mode="AUTO" ;;
        2|INTERACTIVE|interactive) software_install_mode="INTERACTIVE" ;;
        *) software_install_mode="POSTBOOT" ;;
    esac
    DRYRUN_SELECTED_SOFTWARE_INSTALL_MODE="$software_install_mode"

    clear > /dev/tty
    printf "\n[dry-run] preguntas no criticas (APT/software):\n\n" > /dev/tty
    read -r -p "Instalar SSH en la base? [S/n]: " install_ssh_in_base < /dev/tty
    install_ssh_in_base="${install_ssh_in_base:-S}"
    install_ssh_in_base="${install_ssh_in_base^^}"
    [[ "$install_ssh_in_base" != "S" ]] && install_ssh_in_base="N"
    DRYRUN_SELECTED_INSTALL_SSH_IN_BASE="$install_ssh_in_base"

    clear > /dev/tty
    printf "\n[dry-run] preguntas no criticas (APT/software):\n\n" > /dev/tty
    read -r -p "Instalar tasksel ahora? [s/N]: " install_tasksel_now < /dev/tty
    install_tasksel_now="${install_tasksel_now:-N}"
    install_tasksel_now="${install_tasksel_now^^}"
    [[ "$install_tasksel_now" != "S" ]] && install_tasksel_now="N"
    DRYRUN_SELECTED_INSTALL_TASKSEL_NOW="$install_tasksel_now"

    clear > /dev/tty
    printf "\n[dry-run] RESUMEN DE CONFIGURACION:\n\n" > /dev/tty
    printf "[dry-run] === SISTEMA ===\n" > /dev/tty
    printf "[dry-run] Idioma:\n" > /dev/tty
    printf "[dry-run]   Sugerido --> %s\n" "$suggested_language" > /dev/tty
    printf "[dry-run]   Elegido  --> %s\n" "$language_code" > /dev/tty
    printf "[dry-run] Ubicacion:\n" > /dev/tty
    printf "[dry-run]   Sugerido --> %s\n" "$suggested_location" > /dev/tty
    printf "[dry-run]   Elegido  --> %s\n" "$location_value" > /dev/tty
    printf "[dry-run] Teclado:\n" > /dev/tty
    printf "[dry-run]   Sugerido --> %s\n" "$suggested_keyboard" > /dev/tty
    printf "[dry-run]   Elegido  --> %s\n" "$keyboard_value" > /dev/tty
    printf "[dry-run] Timezone:\n" > /dev/tty
    printf "[dry-run]   Sugerido --> %s\n" "$suggested_timezone" > /dev/tty
    printf "[dry-run]   Elegido  --> %s\n" "$timezone_value" > /dev/tty
    printf "\n[dry-run] === IDENTIDAD ===\n" > /dev/tty
    printf "[dry-run] Hostname:\n" > /dev/tty
    printf "[dry-run]   Sugerido --> %s\n" "$suggested_hostname" > /dev/tty
    printf "[dry-run]   Elegido  --> %s\n" "$hostname_value" > /dev/tty
    printf "[dry-run] Usuario:\n" > /dev/tty
    printf "[dry-run]   Sugerido --> %s\n" "$suggested_username" > /dev/tty
    printf "[dry-run]   Elegido  --> %s\n" "$username_value" > /dev/tty
    printf "[dry-run] Password usuario:\n" > /dev/tty
    printf "[dry-run]   Sugerido --> %s\n" "$suggested_user_password_set" > /dev/tty
    printf "[dry-run]   Elegido  --> %s\n" "$user_password_set" > /dev/tty
    printf "\n[dry-run] === PARTICIONES ===\n" > /dev/tty
    printf "[dry-run] EFI:\n" > /dev/tty
    printf "[dry-run]   Sugerido --> %s\n" "$suggested_efi" > /dev/tty
    printf "[dry-run]   Elegido  --> %s\n" "$efi_size" > /dev/tty
    printf "[dry-run] Sistema:\n" > /dev/tty
    printf "[dry-run]   Sugerido --> %s\n" "$suggested_system" > /dev/tty
    printf "[dry-run]   Elegido  --> %s\n" "$system_size" > /dev/tty
    printf "[dry-run] Swap:\n" > /dev/tty
    printf "[dry-run]   Sugerido --> %s\n" "$suggested_swap" > /dev/tty
    printf "[dry-run]   Elegido  --> %s\n" "$swap_size" > /dev/tty
    printf "[dry-run] Backup:\n" > /dev/tty
    printf "[dry-run]   Sugerido --> %s\n" "$suggested_backup" > /dev/tty
    printf "[dry-run]   Elegido  --> %s\n" "$create_backup" > /dev/tty
    printf "\n[dry-run] === APT / SOFTWARE ===\n" > /dev/tty
    printf "[dry-run] non-free:\n" > /dev/tty
    printf "[dry-run]   Sugerido --> %s\n" "$suggested_apt_enable_nonfree" > /dev/tty
    printf "[dry-run]   Elegido  --> %s\n" "$apt_enable_nonfree" > /dev/tty
    printf "[dry-run] security:\n" > /dev/tty
    printf "[dry-run]   Sugerido --> %s\n" "$suggested_apt_enable_security" > /dev/tty
    printf "[dry-run]   Elegido  --> %s\n" "$apt_enable_security" > /dev/tty
    printf "[dry-run] updates:\n" > /dev/tty
    printf "[dry-run]   Sugerido --> %s\n" "$suggested_apt_enable_updates" > /dev/tty
    printf "[dry-run]   Elegido  --> %s\n" "$apt_enable_updates" > /dev/tty
    printf "[dry-run] deb-src:\n" > /dev/tty
    printf "[dry-run]   Sugerido --> %s\n" "$suggested_apt_enable_debsrc" > /dev/tty
    printf "[dry-run]   Elegido  --> %s\n" "$apt_enable_debsrc" > /dev/tty
    printf "[dry-run] Proxy APT:\n" > /dev/tty
    printf "[dry-run]   Sugerido --> %s\n" "${suggested_apt_proxy:-<sin proxy>}" > /dev/tty
    printf "[dry-run]   Elegido  --> %s\n" "${apt_proxy:-<sin proxy>}" > /dev/tty
    printf "[dry-run] Firmware no libre:\n" > /dev/tty
    printf "[dry-run]   Sugerido --> %s\n" "$suggested_install_nonfree_firmware" > /dev/tty
    printf "[dry-run]   Elegido  --> %s\n" "$install_nonfree_firmware" > /dev/tty
    printf "[dry-run] popularity-contest:\n" > /dev/tty
    printf "[dry-run]   Sugerido --> %s\n" "$suggested_enable_popcon" > /dev/tty
    printf "[dry-run]   Elegido  --> %s\n" "$enable_popcon" > /dev/tty
    printf "[dry-run] Modo software:\n" > /dev/tty
    printf "[dry-run]   Sugerido --> %s\n" "$suggested_software_install_mode" > /dev/tty
    printf "[dry-run]   Elegido  --> %s\n" "$software_install_mode" > /dev/tty
    printf "[dry-run] SSH en base:\n" > /dev/tty
    printf "[dry-run]   Sugerido --> %s\n" "$suggested_install_ssh_in_base" > /dev/tty
    printf "[dry-run]   Elegido  --> %s\n" "$install_ssh_in_base" > /dev/tty
    printf "[dry-run] tasksel ahora:\n" > /dev/tty
    printf "[dry-run]   Sugerido --> %s\n" "$suggested_install_tasksel_now" > /dev/tty
    printf "[dry-run]   Elegido  --> %s\n" "$install_tasksel_now" > /dev/tty
    printf "\n[dry-run] volviendo a la UI para mostrar el informe...\n" > /dev/tty
    sleep 0.6

    setup_terminal
    flush_input_buffer
    return 0
}

ask_disk_password_in_plain_terminal() {
    restore_terminal
    flush_input_buffer
    clear

    printf "\n[install] === SELECCION DE DISCO ===\n\n" > /dev/tty

    local disks=()
    local disk_info=()
    local live_root_src live_root_disk
    live_root_src="$(findmnt -n -o SOURCE / 2>/dev/null || true)"
    live_root_disk="$(lsblk -ndo PKNAME "$live_root_src" 2>/dev/null || true)"

    while IFS= read -r line; do
        local dname dsize dmodel dtype
        dname="$line"
        dsize="$(lsblk -ndo SIZE "/dev/$dname" 2>/dev/null | xargs)"
        dmodel="$(lsblk -ndo MODEL "/dev/$dname" 2>/dev/null | xargs)"
        dtype="$(lsblk -ndo TYPE "/dev/$dname" 2>/dev/null)"
        if [[ "$dtype" == "disk" ]]; then
            disks+=("/dev/$dname")
            disk_info+=("$dsize $dmodel")
        fi
    done < <(lsblk -ndpo NAME | sed 's|/dev/||')

    if [[ ${#disks[@]} -eq 0 ]]; then
        printf "[install][error] No se detectaron discos.\n" > /dev/tty
        setup_terminal
        return 1
    fi

    for i in "${!disks[@]}"; do
        local idx=$((i + 1))
        printf "  [%s] %s  (%s)\n" "$idx" "${disks[$i]}" "${disk_info[$i]}" > /dev/tty
        if [[ -n "$live_root_disk" ]] && [[ "${disks[$i]}" == "/dev/$live_root_disk" ]]; then
            printf "       Aviso: puede ser el disco live actual\n" > /dev/tty
        fi
        if lsblk -n "${disks[$i]}" 2>/dev/null | grep -q part; then
            printf "       Aviso: contiene particiones (seran eliminadas)\n" > /dev/tty
        fi
    done
    printf "\n" > /dev/tty

    local selection candidate
    while true; do
        read -r -p "[install] Selecciona disco [1-${#disks[@]}]: " selection < /dev/tty
        selection="${selection:-1}"
        if [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 1 )) && (( selection <= ${#disks[@]} )); then
            candidate="${disks[$((selection - 1))]}"
            if lsblk -n "$candidate" 2>/dev/null | grep -q part; then
                printf "\n[install][warn] El disco %s contiene particiones. SERAN ELIMINADAS.\n" "$candidate" > /dev/tty
                local wipe_confirm
                read -r -p "[install] Continuar? (S/N) [N]: " wipe_confirm < /dev/tty
                wipe_confirm="${wipe_confirm:-N}"
                wipe_confirm="${wipe_confirm^^}"
                if [[ "$wipe_confirm" != "S" ]]; then
                    printf "[install] Elige otro disco.\n\n" > /dev/tty
                    continue
                fi
            fi
            DRYRUN_SELECTED_DISK="$candidate"
            break
        fi
        printf "[install] Seleccion invalida.\n" > /dev/tty
    done

    printf "\n[install] === PASSWORD DE USUARIO ===\n" > /dev/tty
    printf "[install] Usuario : %s\n\n" "$DRYRUN_SELECTED_USERNAME" > /dev/tty

    local pw1 pw2
    while true; do
        read -r -s -p "[install] Password        : " pw1 < /dev/tty
        printf "\n" > /dev/tty
        if [[ -z "$pw1" ]]; then
            printf "[install][warn] La password no puede estar vacia.\n" > /dev/tty
            continue
        fi
        read -r -s -p "[install] Repite password : " pw2 < /dev/tty
        printf "\n" > /dev/tty
        if [[ "$pw1" == "$pw2" ]]; then
            DRYRUN_SELECTED_USER_PASSWORD="$pw1"
            break
        fi
        printf "[install][warn] Las passwords no coinciden. Intenta de nuevo.\n" > /dev/tty
    done

    printf "\n[install] Disco: %s  |  Password: definida\n" "$DRYRUN_SELECTED_DISK" > /dev/tty
    sleep 0.5
    setup_terminal
    flush_input_buffer
    return 0
}

run_install_part1() {
    local option1_path="${SCRIPT_DIR}/${OPTION1_SCRIPT}"
    local defaults_path="${SCRIPT_DIR}/${OPTION2_SCRIPT}"
    local precheck_lines=(
        "Instalacion real de Debian"
        ""
        "Se seguira el mismo flujo de preguntas que el dry-run"
        "y se pedira tambien el disco y la password de usuario."
        ""
        "Al finalizar se mostrara un resumen y podras"
        "confirmar si ejecutar la instalacion real o salir."
        ""
        "ADVERTENCIA: se borrara el disco seleccionado."
    )

    show_info_box "INSTALAR" precheck_lines "ENTER/Esc/q: continuar" "normal"

    if [[ ! -f "$option1_path" ]]; then
        local missing_lines=(
            "No se encontro el archivo requerido:"
            "$OPTION1_SCRIPT"
            ""
            "Verifica el repo y vuelve a intentar."
        )
        show_error_box missing_lines
        return 1
    fi

    if [[ ! -f "$defaults_path" ]]; then
        local missing_defaults_lines=(
            "No se encontro el archivo de defaults:"
            "$OPTION2_SCRIPT"
            ""
            "Se requiere para el flujo de preguntas inicial."
        )
        show_error_box missing_defaults_lines
        return 1
    fi

    if ! confirm_yes_no "CONFIRMAR" "Iniciar el flujo de preguntas?" 0; then
        return 0
    fi

    # Recolectar decisiones comunes (mismo flujo que dry-run)
    if ! ask_efi_in_plain_terminal "$defaults_path"; then
        return 0
    fi

    # Recolectar disco y password (especificos de install)
    if ! ask_disk_password_in_plain_terminal; then
        return 0
    fi

    # Mostrar resumen en UI antes de la confirmacion final
    local summary_lines=(
        "Disco objetivo : $DRYRUN_SELECTED_DISK"
        ""
        "Locale   : $DRYRUN_SELECTED_LOCALE"
        "Teclado  : $DRYRUN_SELECTED_KEYBOARD"
        "Timezone : $DRYRUN_SELECTED_TIMEZONE"
        "Hostname : $DRYRUN_SELECTED_HOSTNAME"
        "Usuario  : $DRYRUN_SELECTED_USERNAME"
        "Password : definida"
        ""
        "EFI      : $DRYRUN_SELECTED_EFI"
        "Sistema  : $DRYRUN_SELECTED_SYSTEM"
        "Swap     : $DRYRUN_SELECTED_SWAP"
        "Backup   : $DRYRUN_SELECTED_BACKUP"
        ""
        "Modo sw  : $DRYRUN_SELECTED_SOFTWARE_INSTALL_MODE"
        "SSH base : $DRYRUN_SELECTED_INSTALL_SSH_IN_BASE"
        "non-free : $DRYRUN_SELECTED_APT_ENABLE_NONFREE"
        ""
        "ADVERTENCIA: EL DISCO $DRYRUN_SELECTED_DISK SERA BORRADO."
    )
    show_info_box "RESUMEN INSTALACION" summary_lines "ENTER/Esc/q: revisar" "normal"

    if ! confirm_yes_no "EJECUTAR INSTALACION" "Ejecutar la instalacion real ahora con estos parametros?" 0; then
        return 0
    fi

    # Ceder control a install.sh en terminal limpia con todos los parametros
    restore_terminal
    clear
    DRYRUN_LOCALE="$DRYRUN_SELECTED_LOCALE" \
    DRYRUN_KEYBOARD="$DRYRUN_SELECTED_KEYBOARD" \
    DRYRUN_TIMEZONE="$DRYRUN_SELECTED_TIMEZONE" \
    DRYRUN_HOSTNAME="$DRYRUN_SELECTED_HOSTNAME" \
    DRYRUN_USERNAME="$DRYRUN_SELECTED_USERNAME" \
    DRYRUN_DISK="$DRYRUN_SELECTED_DISK" \
    INSTALL_USER_PASSWORD="$DRYRUN_SELECTED_USER_PASSWORD" \
    DRYRUN_APT_ENABLE_NONFREE="$DRYRUN_SELECTED_APT_ENABLE_NONFREE" \
    DRYRUN_APT_ENABLE_SECURITY="$DRYRUN_SELECTED_APT_ENABLE_SECURITY" \
    DRYRUN_APT_ENABLE_UPDATES="$DRYRUN_SELECTED_APT_ENABLE_UPDATES" \
    DRYRUN_APT_ENABLE_DEBSRC="$DRYRUN_SELECTED_APT_ENABLE_DEBSRC" \
    DRYRUN_APT_PROXY="$DRYRUN_SELECTED_APT_PROXY" \
    DRYRUN_INSTALL_NONFREE_FIRMWARE="$DRYRUN_SELECTED_INSTALL_NONFREE_FIRMWARE" \
    DRYRUN_ENABLE_POPCON="$DRYRUN_SELECTED_ENABLE_POPCON" \
    DRYRUN_SOFTWARE_INSTALL_MODE="$DRYRUN_SELECTED_SOFTWARE_INSTALL_MODE" \
    DRYRUN_INSTALL_SSH_IN_BASE="$DRYRUN_SELECTED_INSTALL_SSH_IN_BASE" \
    DRYRUN_INSTALL_TASKSEL_NOW="$DRYRUN_SELECTED_INSTALL_TASKSEL_NOW" \
    DRYRUN_EFI_SIZE="$DRYRUN_SELECTED_EFI" \
    DRYRUN_SYSTEM_SIZE="$DRYRUN_SELECTED_SYSTEM" \
    DRYRUN_SWAP_SIZE="$DRYRUN_SELECTED_SWAP" \
    DRYRUN_CREATE_BACKUP="$DRYRUN_SELECTED_BACKUP" \
    bash "$option1_path"
    # Si install.sh termina sin reboot (cancelacion o error), volvemos a la UI
    setup_terminal
}

run_dryrun_part1() {
    local option2_path="${SCRIPT_DIR}/${OPTION2_SCRIPT}"
    local precheck_lines=(
        "Modo prueba (dry-run)"
        ""
        "Se ejecutara un script externo de diagnostico:"
        "  ${OPTION2_SCRIPT}"
        ""
        "Se hara una simulacion de la opcion 1 sin aplicar cambios."
        "Al confirmar SI, se abrira la terminal para ejecutar el analisis"
        "y al finalizar volvera automaticamente al menu UI."
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

    if ! ask_efi_in_plain_terminal "$option2_path"; then
        return 0
    fi

    if run_with_report "DRY-RUN | INFORME" "DRYRUN_LOCALE=\"$DRYRUN_SELECTED_LOCALE\" DRYRUN_KEYBOARD=\"$DRYRUN_SELECTED_KEYBOARD\" DRYRUN_TIMEZONE=\"$DRYRUN_SELECTED_TIMEZONE\" DRYRUN_HOSTNAME=\"$DRYRUN_SELECTED_HOSTNAME\" DRYRUN_USERNAME=\"$DRYRUN_SELECTED_USERNAME\" DRYRUN_USER_PASSWORD_SET=\"$DRYRUN_SELECTED_USER_PASSWORD_SET\" DRYRUN_APT_ENABLE_NONFREE=\"$DRYRUN_SELECTED_APT_ENABLE_NONFREE\" DRYRUN_APT_ENABLE_SECURITY=\"$DRYRUN_SELECTED_APT_ENABLE_SECURITY\" DRYRUN_APT_ENABLE_UPDATES=\"$DRYRUN_SELECTED_APT_ENABLE_UPDATES\" DRYRUN_APT_ENABLE_DEBSRC=\"$DRYRUN_SELECTED_APT_ENABLE_DEBSRC\" DRYRUN_APT_PROXY=\"$DRYRUN_SELECTED_APT_PROXY\" DRYRUN_INSTALL_NONFREE_FIRMWARE=\"$DRYRUN_SELECTED_INSTALL_NONFREE_FIRMWARE\" DRYRUN_ENABLE_POPCON=\"$DRYRUN_SELECTED_ENABLE_POPCON\" DRYRUN_SOFTWARE_INSTALL_MODE=\"$DRYRUN_SELECTED_SOFTWARE_INSTALL_MODE\" DRYRUN_INSTALL_SSH_IN_BASE=\"$DRYRUN_SELECTED_INSTALL_SSH_IN_BASE\" DRYRUN_INSTALL_TASKSEL_NOW=\"$DRYRUN_SELECTED_INSTALL_TASKSEL_NOW\" DRYRUN_EFI_SIZE=\"$DRYRUN_SELECTED_EFI\" DRYRUN_SYSTEM_SIZE=\"$DRYRUN_SELECTED_SYSTEM\" DRYRUN_SWAP_SIZE=\"$DRYRUN_SELECTED_SWAP\" DRYRUN_CREATE_BACKUP=\"$DRYRUN_SELECTED_BACKUP\" bash \"$option2_path\"" "Opcion 2 completada." "Opcion 2 fallo."; then
        local ok_lines=(
            "Ejecucion completada."
            ""
            "Locale elegido para la simulacion: $DRYRUN_SELECTED_LOCALE"
            "Teclado elegido para la simulacion: $DRYRUN_SELECTED_KEYBOARD"
            "Timezone elegida para la simulacion: $DRYRUN_SELECTED_TIMEZONE"
            "Hostname elegido para la simulacion: $DRYRUN_SELECTED_HOSTNAME"
            "Usuario elegido para la simulacion: $DRYRUN_SELECTED_USERNAME"
            "EFI elegido para la simulacion: $DRYRUN_SELECTED_EFI"
            "Sistema elegido para la simulacion: $DRYRUN_SELECTED_SYSTEM"
            "Swap elegido para la simulacion: $DRYRUN_SELECTED_SWAP"
            "Crear backup: $DRYRUN_SELECTED_BACKUP"
            "SSH en base: $DRYRUN_SELECTED_INSTALL_SSH_IN_BASE"
            "Modo software: $DRYRUN_SELECTED_SOFTWARE_INSTALL_MODE"
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
                run_install_part1
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
