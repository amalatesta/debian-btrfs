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

script_self_path() {
    printf '%s\n' "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
}

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

# Runtime state used by integrated install pipeline/traps.
LOG_FILE="/tmp/debian-btrfs-install.log"
MOUNTED_TARGET="false"
MOUNTED_CHROOT_BIND="false"
GRUB_BTRFS_INSTALLED="N"

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

    defaults_output="$(internal_emit_defaults)"
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

    # En instalacion, usuario y password se piden en ask_disk_password_in_plain_terminal
    # Aqui solo dejamos defaults vacios para dry-run
    DRYRUN_SELECTED_USERNAME="usuario"
    DRYRUN_SELECTED_USER_PASSWORD_SET="N"

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

internal_emit_defaults() {
    local default_efi="1G"
    local default_system="64G"
    local default_backup="S"
    local default_swap="8G"
    local default_locale="en_US.UTF-8"
    local default_timezone="UTC"
    local default_keyboard="us"
    local default_keyboard_source="heuristica"
    local default_hostname="debian-pc"
    local ram_gb=0
    local disk_size_gb=128

    if [[ -r /proc/meminfo ]]; then
        ram_gb="$(free -m 2>/dev/null | awk '/^Mem:/{print int($2/1024)}')"
        [[ -z "$ram_gb" ]] && ram_gb=0
    fi

    if command -v lsblk >/dev/null 2>&1; then
        disk_size_gb="$(lsblk -bdn -o SIZE,TYPE 2>/dev/null | awk '$2=="disk"{g=int($1/1024/1024/1024); if(g>m)m=g} END{print (m?m:128)}')"
    fi

    if (( disk_size_gb < 128 )); then
        default_system="$((disk_size_gb * 90 / 100))G"
    elif (( disk_size_gb < 256 )); then
        default_system="$((disk_size_gb * 85 / 100))G"
    else
        default_system="$((disk_size_gb * 80 / 100))G"
    fi

    if (( ram_gb <= 2 )); then
        default_swap="${ram_gb}G"
    elif (( ram_gb <= 8 )); then
        default_swap="$((ram_gb * 2))G"
    elif (( ram_gb <= 16 )); then
        default_swap="${ram_gb}G"
    else
        default_swap="8G"
    fi
    [[ "$default_swap" == "0G" ]] && default_swap="2G"

    default_locale="$(locale 2>/dev/null | awk -F= '/^LANG=/{print $2; exit}')"
    [[ -z "$default_locale" ]] && default_locale="en_US.UTF-8"

    default_timezone="$(cat /etc/timezone 2>/dev/null || true)"
    [[ -z "$default_timezone" ]] && default_timezone="UTC"

    if [[ -f /etc/default/keyboard ]]; then
        local kb_layout
        kb_layout="$(awk -F= '/^XKBLAYOUT=/{gsub(/"/,"",$2); print $2; exit}' /etc/default/keyboard 2>/dev/null || true)"
        if [[ -n "$kb_layout" ]]; then
            default_keyboard="$kb_layout"
            default_keyboard_source="system-file"
        fi
    fi

    if grep -qiE 'laptop|notebook' /sys/class/dmi/id/product_name 2>/dev/null; then
        default_hostname="debian-laptop"
    fi

    printf 'DRYRUN_DEFAULT_EFI=%s\n' "$default_efi"
    printf 'DRYRUN_DEFAULT_SYSTEM=%s\n' "$default_system"
    printf 'DRYRUN_DEFAULT_CREATE_BACKUP=%s\n' "$default_backup"
    printf 'DRYRUN_DEFAULT_SWAP=%s\n' "$default_swap"
    printf 'DRYRUN_DEFAULT_LOCALE=%s\n' "$default_locale"
    printf 'DRYRUN_DEFAULT_TIMEZONE=%s\n' "$default_timezone"
    printf 'DRYRUN_DEFAULT_KEYBOARD=%s\n' "$default_keyboard"
    printf 'DRYRUN_DEFAULT_KEYBOARD_SOURCE=%s\n' "$default_keyboard_source"
    printf 'DRYRUN_DEFAULT_HOSTNAME=%s\n' "$default_hostname"
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

    # ==== USUARIO Y PASSWORD (identidad) ====
    printf "\n[install] === IDENTIDAD: USUARIO Y PASSWORD ===\n\n" > /dev/tty

    local username_value input_username
    username_value="${DRYRUN_SELECTED_USERNAME:-usuario}"
    while true; do
        read -r -p "[install] Nombre de usuario [${username_value}] : " input_username < /dev/tty
        input_username="${input_username:-$username_value}"

        if [[ "$input_username" == "root" ]]; then
            printf "[install][warn] No se permite usar 'root' como usuario principal.\n" > /dev/tty
            continue
        fi

        if [[ ! "$input_username" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
            printf "[install][warn] Usuario invalido. Usa minusculas, numeros, '_' o '-'.\n" > /dev/tty
            continue
        fi

        DRYRUN_SELECTED_USERNAME="$input_username"
        break
    done

    printf "\n" > /dev/tty

    local pw1 pw2
    while true; do
        read -r -s -p "[install] Password para ${DRYRUN_SELECTED_USERNAME}        : " pw1 < /dev/tty
        printf "\n" > /dev/tty
        if [[ -z "$pw1" ]]; then
            printf "[install][warn] La password no puede estar vacia.\n" > /dev/tty
            continue
        fi
        read -r -s -p "[install] Repite password                : " pw2 < /dev/tty
        printf "\n" > /dev/tty
        if [[ "$pw1" == "$pw2" ]]; then
            DRYRUN_SELECTED_USER_PASSWORD="$pw1"
            break
        fi
        printf "[install][warn] Las passwords no coinciden. Intenta de nuevo.\n" > /dev/tty
    done

    printf "\n[install] Disco: %s  |  Usuario: %s  |  Password: definida\n" "$DRYRUN_SELECTED_DISK" "$DRYRUN_SELECTED_USERNAME" > /dev/tty
    sleep 0.5
    setup_terminal
    flush_input_buffer
    return 0
}

run_install_part1() {
    local self_path
    self_path="$(script_self_path)"
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

    if ! confirm_yes_no "CONFIRMAR" "Iniciar el flujo de preguntas?" 0; then
        return 0
    fi

    # Recolectar decisiones comunes (mismo flujo que dry-run)
    if ! ask_efi_in_plain_terminal; then
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
    bash "$self_path" --internal-install
    # Si install.sh termina sin reboot (cancelacion o error), volvemos a la UI
    setup_terminal
}

run_dryrun_part1() {
    local self_path
    self_path="$(script_self_path)"
    local precheck_lines=(
        "Modo prueba (dry-run)"
        ""
        "Se ejecutara el analisis interno del instalador"
        "(sin tocar disco)."
        ""
        "Se hara una simulacion de la opcion 1 sin aplicar cambios."
        "Al confirmar SI, se abrira la terminal para ejecutar el analisis"
        "y al finalizar volvera automaticamente al menu UI."
    )

    show_info_box "DRY-RUN" precheck_lines "ENTER/Esc/q: continuar" "normal"

    if ! confirm_yes_no "CONFIRMAR PRUEBA" "Ejecutar opcion 2 ahora?" 0; then
        return 0
    fi

    if ! ask_efi_in_plain_terminal; then
        return 0
    fi

    if run_with_report "DRY-RUN | INFORME" "DRYRUN_LOCALE=\"$DRYRUN_SELECTED_LOCALE\" DRYRUN_KEYBOARD=\"$DRYRUN_SELECTED_KEYBOARD\" DRYRUN_TIMEZONE=\"$DRYRUN_SELECTED_TIMEZONE\" DRYRUN_HOSTNAME=\"$DRYRUN_SELECTED_HOSTNAME\" DRYRUN_USERNAME=\"$DRYRUN_SELECTED_USERNAME\" DRYRUN_USER_PASSWORD_SET=\"$DRYRUN_SELECTED_USER_PASSWORD_SET\" DRYRUN_APT_ENABLE_NONFREE=\"$DRYRUN_SELECTED_APT_ENABLE_NONFREE\" DRYRUN_APT_ENABLE_SECURITY=\"$DRYRUN_SELECTED_APT_ENABLE_SECURITY\" DRYRUN_APT_ENABLE_UPDATES=\"$DRYRUN_SELECTED_APT_ENABLE_UPDATES\" DRYRUN_APT_ENABLE_DEBSRC=\"$DRYRUN_SELECTED_APT_ENABLE_DEBSRC\" DRYRUN_APT_PROXY=\"$DRYRUN_SELECTED_APT_PROXY\" DRYRUN_INSTALL_NONFREE_FIRMWARE=\"$DRYRUN_SELECTED_INSTALL_NONFREE_FIRMWARE\" DRYRUN_ENABLE_POPCON=\"$DRYRUN_SELECTED_ENABLE_POPCON\" DRYRUN_SOFTWARE_INSTALL_MODE=\"$DRYRUN_SELECTED_SOFTWARE_INSTALL_MODE\" DRYRUN_INSTALL_SSH_IN_BASE=\"$DRYRUN_SELECTED_INSTALL_SSH_IN_BASE\" DRYRUN_INSTALL_TASKSEL_NOW=\"$DRYRUN_SELECTED_INSTALL_TASKSEL_NOW\" DRYRUN_EFI_SIZE=\"$DRYRUN_SELECTED_EFI\" DRYRUN_SYSTEM_SIZE=\"$DRYRUN_SELECTED_SYSTEM\" DRYRUN_SWAP_SIZE=\"$DRYRUN_SELECTED_SWAP\" DRYRUN_CREATE_BACKUP=\"$DRYRUN_SELECTED_BACKUP\" DRYRUN_DISK=\"$DRYRUN_SELECTED_DISK\" bash \"$self_path\" --internal-dryrun-report" "Opcion 2 completada." "Opcion 2 fallo."; then
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


# ============================================  
# BLOQUE: DRY-RUN FUNCTIONS (renombrado dryrun_*)
# ============================================

DISK=""
DISK_SIZE_GB=0
RAM_GB=0
SUGGESTED_EFI="1G"
SUGGESTED_SYSTEM_GB=0
SUGGESTED_SYSTEM_PCT=0
SUGGESTED_BACKUP_GB=0
SUGGESTED_SWAP=""
SWAP_REASON=""
SUGGESTED_TIMEZONE=""
SUGGESTED_LOCALE=""
SUGGESTED_HOSTNAME="debian-pc"
SUGGESTED_USERNAME="usuario"
SUGGESTED_USER_PASSWORD_SET="N"
SUGGESTED_KEYBOARD="us"
SUGGESTED_KEYBOARD_SOURCE="heuristica"
SUGGESTED_APT_ENABLE_NONFREE="S"
SUGGESTED_APT_ENABLE_SECURITY="S"
SUGGESTED_APT_ENABLE_UPDATES="S"
SUGGESTED_APT_ENABLE_DEBSRC="N"
SUGGESTED_APT_PROXY=""
SUGGESTED_INSTALL_NONFREE_FIRMWARE="S"
SUGGESTED_ENABLE_POPCON="N"
SUGGESTED_SOFTWARE_INSTALL_MODE="POSTBOOT"
SUGGESTED_INSTALL_SSH_IN_BASE="S"
SUGGESTED_INSTALL_TASKSEL_NOW="N"
NETWORK_DEFAULT_ROUTE="N"
NETWORK_WIFI_IFACE=""
NETWORK_ETH_IFACE=""
NETWORK_DNS_OK="N"
CREATE_BACKUP="S"
SELECTED_EFI_SIZE=""
SELECTED_EFI_GB=1
SELECTED_SYSTEM_SIZE=""
SELECTED_SYSTEM_GB=0
SELECTED_SWAP_SIZE=""
SELECTED_CREATE_BACKUP="S"
SELECTED_LOCALE=""
SELECTED_TIMEZONE=""
SELECTED_KEYBOARD=""
SELECTED_HOSTNAME=""
SELECTED_USERNAME=""
SELECTED_USER_PASSWORD_SET="N"
SELECTED_APT_ENABLE_NONFREE="S"
SELECTED_APT_ENABLE_SECURITY="S"
SELECTED_APT_ENABLE_UPDATES="S"
SELECTED_APT_ENABLE_DEBSRC="N"
SELECTED_APT_PROXY=""
SELECTED_INSTALL_NONFREE_FIRMWARE="S"
SELECTED_ENABLE_POPCON="N"
SELECTED_SOFTWARE_INSTALL_MODE="POSTBOOT"
SELECTED_INSTALL_SSH_IN_BASE="S"
SELECTED_INSTALL_TASKSEL_NOW="N"
EFFECTIVE_BACKUP_GB=0

dryrun_step() {
    printf "\n[dry-run][step] %s\n" "$1"
}

dryrun_ok() {
    printf "[dry-run][ok] %s\n" "$1"
}

dryrun_warn() {
    printf "[dry-run][warn] %s\n" "$1"
}

dryrun_fail() {
    printf "[dry-run][error] %s\n" "$1" >&2
    exit 1
}

dryrun_info() {
    printf "[dry-run][info] %s\n" "$1"
}

dryrun_have_cmd() {
    command -v "$1" >/dev/null 2>&1
}

dryrun_dryrun_normalize_size_gib() {
    local raw="$1"
    raw="${raw// /}"
    raw="${raw^^}"
    [[ -z "$raw" ]] && raw="1G"
    if [[ "$raw" =~ ^[0-9]+$ ]]; then
        raw="${raw}G"
    fi
    printf '%s\n' "$raw"
}

dryrun_dryrun_size_gib_to_int() {
    local raw="$1"
    raw="$(normalize_size_gib "$raw")"
    if [[ "$raw" =~ ^[0-9]+G$ ]]; then
        printf '%s\n' "${raw%G}"
        return 0
    fi
    if [[ "$raw" =~ ^[0-9]+M$ ]]; then
        local mib="${raw%M}"
        printf '%s\n' "$(( (mib + 1023) / 1024 ))"
        return 0
    fi
    printf '0\n'
}

dryrun_dryrun_calculate_recommendations() {
    if [[ -z "$DRYRUN_DISK" ]]; then
        warn "no hay disco sugerido; no se pueden calcular recomendaciones"
        return 1
    fi

    RAM_GB="$(free -m 2>/dev/null | awk '/^Mem:/{print int($2/1024)}')"
    [[ -z "$DRYRUN_RAM_GB" ]] && RAM_GB=0

    if [[ $DRYRUN_DISK_SIZE_GB -lt 128 ]]; then
        SUGGESTED_SYSTEM_PCT=90
    elif [[ $DRYRUN_DISK_SIZE_GB -lt 256 ]]; then
        SUGGESTED_SYSTEM_PCT=85
    else
        SUGGESTED_SYSTEM_PCT=80
    fi

    SUGGESTED_SYSTEM_GB=$((DISK_SIZE_GB * SUGGESTED_SYSTEM_PCT / 100))
    SUGGESTED_BACKUP_GB=$((DISK_SIZE_GB - SUGGESTED_SYSTEM_GB - 1))
    if (( SUGGESTED_BACKUP_GB <= 0 )); then
        SUGGESTED_BACKUP_GB=0
        CREATE_BACKUP="N"
    else
        CREATE_BACKUP="S"
    fi

    if [[ $DRYRUN_RAM_GB -le 2 ]]; then
        SUGGESTED_SWAP="${RAM_GB}G"
        SWAP_REASON="igual a RAM (sistema con poca memoria)"
    elif [[ $DRYRUN_RAM_GB -le 8 ]]; then
        SUGGESTED_SWAP="$((RAM_GB * 2))G"
        SWAP_REASON="2x RAM (permite hibernacion)"
    elif [[ $DRYRUN_RAM_GB -le 16 ]]; then
        SUGGESTED_SWAP="${RAM_GB}G"
        SWAP_REASON="igual a RAM (permite hibernacion)"
    else
        SUGGESTED_SWAP="8G"
        SWAP_REASON="8GB fijo (RAM suficiente)"
    fi

    if grep -qiE 'laptop|notebook' /sys/class/dmi/id/product_name 2>/dev/null; then
        SUGGESTED_HOSTNAME="debian-laptop"
    else
        SUGGESTED_HOSTNAME="debian-pc"
    fi

    SUGGESTED_TIMEZONE="$(cat /etc/timezone 2>/dev/null || true)"
    [[ -z "$DRYRUN_SUGGESTED_TIMEZONE" ]] && SUGGESTED_TIMEZONE="UTC"

    SUGGESTED_LOCALE="$(locale 2>/dev/null | awk -F= '/^LANG=/{print $2; exit}')"
    [[ -z "$DRYRUN_SUGGESTED_LOCALE" ]] && SUGGESTED_LOCALE="en_US.UTF-8"

    if [[ -f /etc/default/keyboard ]]; then
        local kb_layout
        kb_layout="$(awk -F= '/^XKBLAYOUT=/{gsub(/"/,"",$2); print $2; exit}' /etc/default/keyboard 2>/dev/null || true)"
        if [[ -n "$kb_layout" ]]; then
            SUGGESTED_KEYBOARD="$kb_layout"
            SUGGESTED_KEYBOARD_SOURCE="system-file"
        fi
    fi

    if [[ "$DRYRUN_SUGGESTED_KEYBOARD_SOURCE" != "system-file" ]]; then
        if [[ "$DRYRUN_SUGGESTED_LOCALE" == es_* ]]; then
            SUGGESTED_KEYBOARD="es"
        else
            SUGGESTED_KEYBOARD="us"
        fi
        SUGGESTED_KEYBOARD_SOURCE="heuristica"
    fi

    SELECTED_EFI_SIZE="$(normalize_size_gib "${DRYRUN_EFI_SIZE:-$DRYRUN_SUGGESTED_EFI}")"
    SELECTED_EFI_GB="$(size_gib_to_int "$DRYRUN_SELECTED_EFI_SIZE")"
    if (( SELECTED_EFI_GB < 1 )); then
        SELECTED_EFI_SIZE="$DRYRUN_SUGGESTED_EFI"
        SELECTED_EFI_GB="$(size_gib_to_int "$DRYRUN_SELECTED_EFI_SIZE")"
    fi

    SELECTED_SYSTEM_SIZE="$(normalize_size_gib "${DRYRUN_SYSTEM_SIZE:-${SUGGESTED_SYSTEM_GB}G}")"
    SELECTED_SYSTEM_GB="$(size_gib_to_int "$DRYRUN_SELECTED_SYSTEM_SIZE")"
    if (( SELECTED_SYSTEM_GB < 16 )); then
        SELECTED_SYSTEM_SIZE="${SUGGESTED_SYSTEM_GB}G"
        SELECTED_SYSTEM_GB="$DRYRUN_SUGGESTED_SYSTEM_GB"
    fi

    SELECTED_SWAP_SIZE="$(normalize_size_gib "${DRYRUN_SWAP_SIZE:-$DRYRUN_SUGGESTED_SWAP}")"
    if (( $(size_gib_to_int "$DRYRUN_SELECTED_SWAP_SIZE") < 1 )); then
        SELECTED_SWAP_SIZE="$DRYRUN_SUGGESTED_SWAP"
    fi

    SELECTED_CREATE_BACKUP="${DRYRUN_CREATE_BACKUP:-$DRYRUN_CREATE_BACKUP}"
    SELECTED_CREATE_BACKUP="${SELECTED_CREATE_BACKUP^^}"
    if [[ "$DRYRUN_SELECTED_CREATE_BACKUP" != "S" ]]; then
        SELECTED_CREATE_BACKUP="N"
    fi

    SELECTED_LOCALE="${DRYRUN_LOCALE:-$DRYRUN_SUGGESTED_LOCALE}"
    SELECTED_TIMEZONE="${DRYRUN_TIMEZONE:-$DRYRUN_SUGGESTED_TIMEZONE}"
    SELECTED_KEYBOARD="${DRYRUN_KEYBOARD:-$DRYRUN_SUGGESTED_KEYBOARD}"
    SELECTED_HOSTNAME="${DRYRUN_HOSTNAME:-$DRYRUN_SUGGESTED_HOSTNAME}"
    SELECTED_USERNAME="${DRYRUN_USERNAME:-$DRYRUN_SUGGESTED_USERNAME}"

    SELECTED_USER_PASSWORD_SET="${DRYRUN_USER_PASSWORD_SET:-$DRYRUN_SUGGESTED_USER_PASSWORD_SET}"
    SELECTED_USER_PASSWORD_SET="${SELECTED_USER_PASSWORD_SET^^}"
    [[ "$DRYRUN_SELECTED_USER_PASSWORD_SET" != "S" ]] && SELECTED_USER_PASSWORD_SET="N"

    SELECTED_APT_ENABLE_NONFREE="${DRYRUN_APT_ENABLE_NONFREE:-$DRYRUN_SUGGESTED_APT_ENABLE_NONFREE}"
    SELECTED_APT_ENABLE_NONFREE="${SELECTED_APT_ENABLE_NONFREE^^}"
    [[ "$DRYRUN_SELECTED_APT_ENABLE_NONFREE" != "S" ]] && SELECTED_APT_ENABLE_NONFREE="N"

    SELECTED_APT_ENABLE_SECURITY="${DRYRUN_APT_ENABLE_SECURITY:-$DRYRUN_SUGGESTED_APT_ENABLE_SECURITY}"
    SELECTED_APT_ENABLE_SECURITY="${SELECTED_APT_ENABLE_SECURITY^^}"
    [[ "$DRYRUN_SELECTED_APT_ENABLE_SECURITY" != "S" ]] && SELECTED_APT_ENABLE_SECURITY="N"

    SELECTED_APT_ENABLE_UPDATES="${DRYRUN_APT_ENABLE_UPDATES:-$DRYRUN_SUGGESTED_APT_ENABLE_UPDATES}"
    SELECTED_APT_ENABLE_UPDATES="${SELECTED_APT_ENABLE_UPDATES^^}"
    [[ "$DRYRUN_SELECTED_APT_ENABLE_UPDATES" != "S" ]] && SELECTED_APT_ENABLE_UPDATES="N"

    SELECTED_APT_ENABLE_DEBSRC="${DRYRUN_APT_ENABLE_DEBSRC:-$DRYRUN_SUGGESTED_APT_ENABLE_DEBSRC}"
    SELECTED_APT_ENABLE_DEBSRC="${SELECTED_APT_ENABLE_DEBSRC^^}"
    [[ "$DRYRUN_SELECTED_APT_ENABLE_DEBSRC" != "S" ]] && SELECTED_APT_ENABLE_DEBSRC="N"

    SELECTED_APT_PROXY="${DRYRUN_APT_PROXY:-$DRYRUN_SUGGESTED_APT_PROXY}"

    SELECTED_INSTALL_NONFREE_FIRMWARE="${DRYRUN_INSTALL_NONFREE_FIRMWARE:-$DRYRUN_SUGGESTED_INSTALL_NONFREE_FIRMWARE}"
    SELECTED_INSTALL_NONFREE_FIRMWARE="${SELECTED_INSTALL_NONFREE_FIRMWARE^^}"
    [[ "$DRYRUN_SELECTED_INSTALL_NONFREE_FIRMWARE" != "S" ]] && SELECTED_INSTALL_NONFREE_FIRMWARE="N"

    SELECTED_ENABLE_POPCON="${DRYRUN_ENABLE_POPCON:-$DRYRUN_SUGGESTED_ENABLE_POPCON}"
    SELECTED_ENABLE_POPCON="${SELECTED_ENABLE_POPCON^^}"
    [[ "$DRYRUN_SELECTED_ENABLE_POPCON" != "S" ]] && SELECTED_ENABLE_POPCON="N"

    SELECTED_SOFTWARE_INSTALL_MODE="${DRYRUN_SOFTWARE_INSTALL_MODE:-$DRYRUN_SUGGESTED_SOFTWARE_INSTALL_MODE}"
    SELECTED_SOFTWARE_INSTALL_MODE="${SELECTED_SOFTWARE_INSTALL_MODE^^}"
    case "$DRYRUN_SELECTED_SOFTWARE_INSTALL_MODE" in
        AUTO|INTERACTIVE|POSTBOOT) : ;;
        *) SELECTED_SOFTWARE_INSTALL_MODE="$DRYRUN_SUGGESTED_SOFTWARE_INSTALL_MODE" ;;
    esac

    SELECTED_INSTALL_SSH_IN_BASE="${DRYRUN_INSTALL_SSH_IN_BASE:-$DRYRUN_SUGGESTED_INSTALL_SSH_IN_BASE}"
    SELECTED_INSTALL_SSH_IN_BASE="${SELECTED_INSTALL_SSH_IN_BASE^^}"
    [[ "$DRYRUN_SELECTED_INSTALL_SSH_IN_BASE" != "S" ]] && SELECTED_INSTALL_SSH_IN_BASE="N"

    SELECTED_INSTALL_TASKSEL_NOW="${DRYRUN_INSTALL_TASKSEL_NOW:-$DRYRUN_SUGGESTED_INSTALL_TASKSEL_NOW}"
    SELECTED_INSTALL_TASKSEL_NOW="${SELECTED_INSTALL_TASKSEL_NOW^^}"
    [[ "$DRYRUN_SELECTED_INSTALL_TASKSEL_NOW" != "S" ]] && SELECTED_INSTALL_TASKSEL_NOW="N"

    EFFECTIVE_BACKUP_GB=$((DISK_SIZE_GB - SELECTED_SYSTEM_GB - SELECTED_EFI_GB))
    if (( EFFECTIVE_BACKUP_GB <= 0 )); then
        EFFECTIVE_BACKUP_GB=0
        SELECTED_CREATE_BACKUP="N"
    fi
}

dryrun_dryrun_print_defaults() {
    detect_suggested_disk || return 1
    calculate_recommendations || return 1

    printf 'DRYRUN_DEFAULT_DISK=%s\n' "$DRYRUN_DISK"
    printf 'DRYRUN_DEFAULT_EFI=%s\n' "$DRYRUN_SUGGESTED_EFI"
    printf 'DRYRUN_DEFAULT_SYSTEM=%sG\n' "$DRYRUN_SUGGESTED_SYSTEM_GB"
    printf 'DRYRUN_DEFAULT_BACKUP=%sG\n' "$DRYRUN_SUGGESTED_BACKUP_GB"
    printf 'DRYRUN_DEFAULT_CREATE_BACKUP=%s\n' "$DRYRUN_CREATE_BACKUP"
    printf 'DRYRUN_DEFAULT_SWAP=%s\n' "$DRYRUN_SUGGESTED_SWAP"
    printf 'DRYRUN_DEFAULT_LOCALE=%s\n' "$DRYRUN_SUGGESTED_LOCALE"
    printf 'DRYRUN_DEFAULT_TIMEZONE=%s\n' "$DRYRUN_SUGGESTED_TIMEZONE"
    printf 'DRYRUN_DEFAULT_HOSTNAME=%s\n' "$DRYRUN_SUGGESTED_HOSTNAME"
    printf 'DRYRUN_DEFAULT_KEYBOARD=%s\n' "$DRYRUN_SUGGESTED_KEYBOARD"
    printf 'DRYRUN_DEFAULT_KEYBOARD_SOURCE=%s\n' "$DRYRUN_SUGGESTED_KEYBOARD_SOURCE"
}

dryrun_dryrun_analyze_memory() {
    step "1/9 - Analisis de memoria"

    if [[ ! -f /proc/meminfo ]]; then
        warn "no se puede leer /proc/meminfo"
        return 1
    fi

    local total_kb used_kb available_kb percent_used
    total_kb="$(grep '^MemTotal:' /proc/meminfo | awk '{print $2}')"
    available_kb="$(grep '^MemAvailable:' /proc/meminfo | awk '{print $2}')"
    used_kb=$((total_kb - available_kb))
    percent_used=$((100 * used_kb / total_kb))

    local total_gb used_gb available_gb
    total_gb=$((total_kb / 1024 / 1024))
    used_gb=$((used_kb / 1024 / 1024))
    available_gb=$((available_kb / 1024 / 1024))

    printf "[dry-run] RAM total: %sGB\n" "$total_gb"
    printf "[dry-run] RAM usada: %sGB (%s%%)\n" "$used_gb" "$percent_used"
    printf "[dry-run] RAM disponible: %sGB\n" "$available_gb"

    if (( available_gb < 2 )); then
        warn "memoria insuficiente (<2GB); instalacion posible pero lenta"
    else
        ok "memoria suficiente"
    fi

    if [[ -f /proc/swaps ]]; then
        local swap_total
        swap_total="$(tail -n +2 /proc/swaps | awk '{sum+=$3} END{print sum}')"
        if [[ -z "$swap_total" ]] || (( swap_total == 0 )); then
            info "no hay swap configurado"
        else
            local swap_gb
            swap_gb=$((swap_total / 1024 / 1024))
            printf "[dry-run] swap disponible: %sGB\n" "$swap_gb"
        fi
    fi
}

dryrun_dryrun_analyze_cpu() {
    step "2/9 - Analisis de CPU"

    if [[ ! -f /proc/cpuinfo ]]; then
        warn "no se puede leer /proc/cpuinfo"
        return 1
    fi

    local cpu_count cpu_model
    cpu_count="$(grep -c '^processor' /proc/cpuinfo)"
    cpu_model="$(grep '^model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"

    printf "[dry-run] CPUs: %s\n" "$cpu_count"
    printf "[dry-run] modelo: %s\n" "$cpu_model"

    if (( cpu_count < 2 )); then
        warn "CPU limitada (1 core); compilacion y instalacion seran lentas"
    else
        ok "CPU multiples cores disponibles"
    fi

    if have_cmd nproc; then
        local available_procs
        available_procs="$(nproc)"
        printf "[dry-run] procesos paralelos disponibles: %s\n" "$available_procs"
    fi
}

dryrun_dryrun_detect_suggested_disk() {
    local root_source live_root_disk candidate_name candidate_size
    local -a candidates
    local best_size=0

    candidates=()

    if have_cmd findmnt; then
        root_source="$(findmnt -n -o SOURCE / 2>/dev/null || true)"
        live_root_disk="$(lsblk -ndo PKNAME "$root_source" 2>/dev/null || true)"
    fi

    while IFS='|' read -r candidate_name candidate_size; do
        [[ -z "$candidate_name" ]] && continue
        candidates+=("${candidate_name}|${candidate_size}")
    done < <(lsblk -bdn -o NAME,SIZE,TYPE 2>/dev/null | awk '$3=="disk"{print $1"|"int($2/1024/1024/1024)}')

    if (( ${#candidates[@]} == 0 )); then
        warn "no se detectaron discos para simulacion"
        return 1
    fi

    for candidate in "${candidates[@]}"; do
        IFS='|' read -r candidate_name candidate_size <<< "$candidate"
        if [[ -n "$live_root_disk" && "$candidate_name" == "$live_root_disk" ]]; then
            continue
        fi
        if (( candidate_size > best_size )); then
            DISK="/dev/${candidate_name}"
            best_size=$candidate_size
        fi
    done

    if [[ -z "$DRYRUN_DISK" ]]; then
        IFS='|' read -r candidate_name candidate_size <<< "${candidates[0]}"
        DISK="/dev/${candidate_name}"
        best_size=$candidate_size
    fi

    DISK_SIZE_GB=$best_size
    ok "disco sugerido para simulacion: ${DISK} (${DISK_SIZE_GB}GB)"
}

dryrun_dryrun_analyze_and_suggest() {
    step "8/9 - Calculo de sugerencias como opcion 1"
    calculate_recommendations || return 1

    printf "[dry-run] disco objetivo sugerido: %s\n" "$DRYRUN_DISK"
    printf "[dry-run] capacidad usada para calculo: %sGB\n" "$DRYRUN_DISK_SIZE_GB"
    printf "[dry-run] RAM usada para calculo: %sGB\n" "$DRYRUN_RAM_GB"
    printf "[dry-run] Sugerido --> EFI: %s\n" "$DRYRUN_SUGGESTED_EFI"
    printf "[dry-run] Elegido  --> EFI: %s\n" "$DRYRUN_SELECTED_EFI_SIZE"

    printf "[dry-run] Sugerido --> Sistema: %sG (%s%% del disco)\n" "$DRYRUN_SUGGESTED_SYSTEM_GB" "$DRYRUN_SUGGESTED_SYSTEM_PCT"
    printf "[dry-run] Elegido  --> Sistema: %s\n" "$DRYRUN_SELECTED_SYSTEM_SIZE"

    if [[ "$DRYRUN_CREATE_BACKUP" == "S" ]]; then
        printf "[dry-run] Sugerido --> Backup: %sG\n" "$DRYRUN_SUGGESTED_BACKUP_GB"
    else
        printf "[dry-run] Sugerido --> Backup: no crear (sin espacio suficiente)\n"
    fi

    if [[ "$DRYRUN_SELECTED_CREATE_BACKUP" == "S" ]]; then
        printf "[dry-run] Elegido  --> Backup: %sG\n" "$DRYRUN_EFFECTIVE_BACKUP_GB"
    else
        printf "[dry-run] Elegido  --> Backup: no crear\n"
    fi

    printf "[dry-run] Sugerido --> Swapfile: %s (%s)\n" "$DRYRUN_SUGGESTED_SWAP" "$SWAP_REASON"
    printf "[dry-run] Elegido  --> Swapfile: %s\n" "$DRYRUN_SELECTED_SWAP_SIZE"

    printf "[dry-run] Sugerido --> Hostname: %s\n" "$DRYRUN_SUGGESTED_HOSTNAME"
    printf "[dry-run] Elegido  --> Hostname: %s\n" "$DRYRUN_SELECTED_HOSTNAME"
    printf "[dry-run] Sugerido --> Usuario: %s\n" "$DRYRUN_SUGGESTED_USERNAME"
    printf "[dry-run] Elegido  --> Usuario: %s\n" "$DRYRUN_SELECTED_USERNAME"
    printf "[dry-run] Sugerido --> Password usuario definida: %s\n" "$DRYRUN_SUGGESTED_USER_PASSWORD_SET"
    printf "[dry-run] Elegido  --> Password usuario definida: %s\n" "$DRYRUN_SELECTED_USER_PASSWORD_SET"

    printf "[dry-run] Sugerido --> Timezone: %s\n" "$DRYRUN_SUGGESTED_TIMEZONE"
    printf "[dry-run] Elegido  --> Timezone: %s\n" "$DRYRUN_SELECTED_TIMEZONE"

    printf "[dry-run] Sugerido --> Locale: %s\n" "$DRYRUN_SUGGESTED_LOCALE"
    printf "[dry-run] Elegido  --> Locale: %s\n" "$DRYRUN_SELECTED_LOCALE"
    printf "[dry-run] Sugerido --> Teclado: %s\n" "$DRYRUN_SUGGESTED_KEYBOARD"
    printf "[dry-run] Elegido  --> Teclado: %s\n" "$DRYRUN_SELECTED_KEYBOARD"

    printf "[dry-run] Sugerido --> APT non-free: %s\n" "$DRYRUN_SUGGESTED_APT_ENABLE_NONFREE"
    printf "[dry-run] Elegido  --> APT non-free: %s\n" "$DRYRUN_SELECTED_APT_ENABLE_NONFREE"
    printf "[dry-run] Sugerido --> APT security: %s\n" "$DRYRUN_SUGGESTED_APT_ENABLE_SECURITY"
    printf "[dry-run] Elegido  --> APT security: %s\n" "$DRYRUN_SELECTED_APT_ENABLE_SECURITY"
    printf "[dry-run] Sugerido --> APT updates: %s\n" "$DRYRUN_SUGGESTED_APT_ENABLE_UPDATES"
    printf "[dry-run] Elegido  --> APT updates: %s\n" "$DRYRUN_SELECTED_APT_ENABLE_UPDATES"
    printf "[dry-run] Sugerido --> APT deb-src: %s\n" "$DRYRUN_SUGGESTED_APT_ENABLE_DEBSRC"
    printf "[dry-run] Elegido  --> APT deb-src: %s\n" "$DRYRUN_SELECTED_APT_ENABLE_DEBSRC"
    printf "[dry-run] Sugerido --> APT proxy: %s\n" "${SUGGESTED_APT_PROXY:-<sin proxy>}"
    printf "[dry-run] Elegido  --> APT proxy: %s\n" "${SELECTED_APT_PROXY:-<sin proxy>}"
    printf "[dry-run] Sugerido --> Firmware no libre: %s\n" "$DRYRUN_SUGGESTED_INSTALL_NONFREE_FIRMWARE"
    printf "[dry-run] Elegido  --> Firmware no libre: %s\n" "$DRYRUN_SELECTED_INSTALL_NONFREE_FIRMWARE"
    printf "[dry-run] Sugerido --> popularity-contest: %s\n" "$DRYRUN_SUGGESTED_ENABLE_POPCON"
    printf "[dry-run] Elegido  --> popularity-contest: %s\n" "$DRYRUN_SELECTED_ENABLE_POPCON"
    printf "[dry-run] Sugerido --> Modo software: %s\n" "$DRYRUN_SUGGESTED_SOFTWARE_INSTALL_MODE"
    printf "[dry-run] Elegido  --> Modo software: %s\n" "$DRYRUN_SELECTED_SOFTWARE_INSTALL_MODE"
    printf "[dry-run] Sugerido --> SSH en base: %s\n" "$DRYRUN_SUGGESTED_INSTALL_SSH_IN_BASE"
    printf "[dry-run] Elegido  --> SSH en base: %s\n" "$DRYRUN_SELECTED_INSTALL_SSH_IN_BASE"
    printf "[dry-run] Sugerido --> tasksel ahora: %s\n" "$DRYRUN_SUGGESTED_INSTALL_TASKSEL_NOW"
    printf "[dry-run] Elegido  --> tasksel ahora: %s\n" "$DRYRUN_SELECTED_INSTALL_TASKSEL_NOW"

    ok "recomendaciones calculadas con la misma base de opcion 1"
}

dryrun_dryrun_print_header() {
    printf "[dry-run] === DEBIAN BTRFS INSTALLER - DRY-RUN ANALYSIS ===\n"
    printf "[dry-run] repo: %s\n" "$REPO_ROOT"
    printf "[dry-run] objetivo: validar sistema sin tocar disco\n"
    printf "[dry-run] fecha: %s\n" "$(date '+%Y-%m-%d %H:%M:%S')"
    printf "\n"
}

dryrun_dryrun_check_environment() {
    step "3/9 - Validaciones de entorno"

    if ! have_cmd bash; then
        fail "bash no disponible"
    fi
    ok "bash disponible"

    if have_cmd tput; then
        ok "tput disponible"
    else
        warn "tput no disponible (continuando)"
    fi

    if have_cmd lsblk; then
        ok "lsblk disponible"
    else
        warn "lsblk no disponible (analisis de discos limitado)"
    fi

    if have_cmd findmnt; then
        ok "findmnt disponible"
    else
        warn "findmnt no disponible (deteccion de raiz limitada)"
    fi

    if have_cmd awk; then
        ok "awk disponible"
    else
        fail "awk no disponible"
    fi

    if have_cmd sed; then
        ok "sed disponible"
    else
        fail "sed no disponible"
    fi
}

dryrun_dryrun_detect_runtime_context() {
    step "4/9 - Contexto de ejecucion"

    local kernel user uid_value root_fs root_src
    kernel="$(uname -sr 2>/dev/null || echo desconocido)"
    user="${USER:-desconocido}"
    uid_value="$(id -u 2>/dev/null || echo n/a)"

    printf "[dry-run] kernel: %s\n" "$kernel"
    printf "[dry-run] usuario: %s (uid=%s)\n" "$user" "$uid_value"

    if [[ "${uid_value}" != "0" ]]; then
        warn "no se ejecuta como root; algunas lecturas podrian estar limitadas"
    else
        ok "ejecutando como root"
    fi

    if have_cmd findmnt; then
        root_fs="$(findmnt -n -o FSTYPE / 2>/dev/null || true)"
        root_src="$(findmnt -n -o SOURCE / 2>/dev/null || true)"
        [[ -n "$root_fs" ]] && printf "[dry-run] fs raiz: %s\n" "$root_fs"
        [[ -n "$root_src" ]] && printf "[dry-run] origen raiz: %s\n" "$root_src"
    fi
}

dryrun_dryrun_verify_disk_space() {
    step "5/9 - Verificacion de espacio en disco"

    if ! have_cmd df; then
        warn "df no disponible; verificacion saltada"
        return 0
    fi

    local root_available root_size
    root_available="$(df -BG / 2>/dev/null | awk 'NR==2{print $4}' | sed 's/G$//')"
    root_size="$(df -BG / 2>/dev/null | awk 'NR==2{print $2}' | sed 's/G$//')"

    printf "[dry-run] espacio total en /: %sGB\n" "$root_size"
    printf "[dry-run] espacio disponible en /: %sGB\n" "$root_available"

    local min_required
    min_required=20

    if (( root_available < min_required )); then
        warn "espacio insuficiente (<${min_required}GB); instalacion dificil o imposible"
    else
        ok "espacio suficiente para instalacion"
    fi

    if (( root_available < 50 )); then
        info "recomendacion: considerar espacio >= 50GB para comodidad"
    fi
}

dryrun_dryrun_detect_storage() {
    step "6/9 - Deteccion de hardware y particiones"

    if ! have_cmd lsblk; then
        warn "omitiendo deteccion de discos porque lsblk no esta disponible"
        return 0
    fi

    local disks_count nvme_count ssd_count hdd_count
    disks_count="$(lsblk -d -n -o NAME 2>/dev/null | sed '/^$/d' | wc -l | awk '{print $1}')"
    nvme_count="$(lsblk -d -n -o NAME 2>/dev/null | grep -c '^nvme' || true)"
    ssd_count="$(lsblk -d -n -o ROTA 2>/dev/null | awk '$1==0{c++} END{print c+0}')"
    hdd_count="$(lsblk -d -n -o ROTA 2>/dev/null | awk '$1==1{c++} END{print c+0}')"

    printf "[dry-run] discos detectados: %s\n" "$disks_count"
    printf "[dry-run] tipo aprox: nvme=%s ssd=%s hdd=%s\n" "$nvme_count" "$ssd_count" "$hdd_count"

    printf "[dry-run] tabla de bloques (resumen):\n"
    lsblk -e7 -o NAME,TYPE,SIZE,FSTYPE,MOUNTPOINTS 2>/dev/null | sed 's/^/[dry-run]   /'

    local btrfs_parts efi_parts
    btrfs_parts="$(lsblk -nr -o NAME,FSTYPE 2>/dev/null | awk '$2=="btrfs"{c++} END{print c+0}')"
    efi_parts="$(lsblk -nr -o NAME,FSTYPE,PARTTYPE 2>/dev/null | awk '$2=="vfat" || tolower($3)=="c12a7328-f81f-11d2-ba4b-00a0c93ec93b"{c++} END{print c+0}')"

    printf "[dry-run] particiones btrfs detectadas: %s\n" "$btrfs_parts"
    printf "[dry-run] particiones EFI detectadas (aprox): %s\n" "$efi_parts"

    detect_suggested_disk || true
}

dryrun_dryrun_analyze_network() {
    step "7/9 - Estado de red (requisito del entorno)"

    if ! have_cmd ip; then
        warn "ip no disponible; analisis de red limitado"
        return 0
    fi

    local iface_path iface_name
    for iface_path in /sys/class/net/*; do
        iface_name="${iface_path##*/}"
        [[ "$iface_name" == "lo" ]] && continue
        if [[ -d "$iface_path/wireless" ]]; then
            NETWORK_WIFI_IFACE="$iface_name"
        elif [[ -f "$iface_path/carrier" ]] && [[ "$(cat "$iface_path/carrier" 2>/dev/null || true)" == "1" ]]; then
            NETWORK_ETH_IFACE="$iface_name"
        fi
    done

    if ip route show default 2>/dev/null | grep -q .; then
        NETWORK_DEFAULT_ROUTE="S"
    fi

    if have_cmd getent && getent hosts deb.debian.org >/dev/null 2>&1; then
        NETWORK_DNS_OK="S"
    fi

    printf "[dry-run] interfaz ethernet: %s\n" "${NETWORK_ETH_IFACE:-no detectada}"
    printf "[dry-run] interfaz wifi: %s\n" "${NETWORK_WIFI_IFACE:-no detectada}"
    printf "[dry-run] ruta por defecto: %s\n" "$DRYRUN_NETWORK_DEFAULT_ROUTE"
    printf "[dry-run] DNS funcional: %s\n" "$DRYRUN_NETWORK_DNS_OK"
    printf "[dry-run] requisito actual: salida a Internet preferentemente por Ethernet\n"

    if [[ "$DRYRUN_NETWORK_DEFAULT_ROUTE" == "S" ]]; then
        ok "red operativa para continuar"
    elif [[ -n "$DRYRUN_NETWORK_ETH_IFACE" ]]; then
        warn "hay interfaz ethernet, pero sin conectividad valida"
    elif [[ -n "$DRYRUN_NETWORK_WIFI_IFACE" ]]; then
        warn "hay Wi-Fi detectada, pero este flujo queda como requisito del entorno live"
    else
        warn "sin conectividad lista; la instalacion debe asumir Ethernet/Internet como requisito"
    fi
}

dryrun_dryrun_print_preview_plan() {
    step "9/9 - Simulacion del plan de instalacion"

    printf "\n[dry-run] === PLAN DE PARTICIONES ===\n\n"
    printf "[dry-run] EFI:\n"
    printf "[dry-run]   Sugerido --> %s   FAT32   /boot/efi\n" "$DRYRUN_SUGGESTED_EFI"
    printf "[dry-run]   Elegido  --> %s   FAT32   /boot/efi\n" "$DRYRUN_SELECTED_EFI_SIZE"

    printf "\n[dry-run] SISTEMA (BTRFS raiz):\n"
    printf "[dry-run]   Sugerido --> %sG   BTRFS   /\n" "$DRYRUN_SUGGESTED_SYSTEM_GB"
    printf "[dry-run]   Elegido  --> %s   BTRFS   /\n" "$DRYRUN_SELECTED_SYSTEM_SIZE"

    printf "\n[dry-run] BACKUP (BTRFS opcional):\n"
    if [[ "$DRYRUN_CREATE_BACKUP" == "S" ]]; then
        printf "[dry-run]   Sugerido --> %sG   BTRFS   (desmontada)\n" "$DRYRUN_SUGGESTED_BACKUP_GB"
    else
        printf "[dry-run]   Sugerido --> omitida por espacio\n"
    fi
    if [[ "$DRYRUN_SELECTED_CREATE_BACKUP" == "S" ]]; then
        printf "[dry-run]   Elegido  --> %sG   BTRFS   (desmontada)\n" "$DRYRUN_EFFECTIVE_BACKUP_GB"
    else
        printf "[dry-run]   Elegido  --> omitida\n"
    fi

    printf "\n[dry-run] === SWAP ===\n"
    printf "[dry-run]   Sugerido --> %s   (en subvol @swap)\n" "$DRYRUN_SUGGESTED_SWAP"
    printf "[dry-run]   Elegido  --> %s   (en subvol @swap)\n" "$DRYRUN_SELECTED_SWAP_SIZE"

    cat <<'EOF'

[dry-run] === SUBVOLUMENES BTRFS ===
[dry-run]   - @           -> raiz del sistema (/)
[dry-run]   - @home       -> datos de usuario (/home)
[dry-run]   - @snapshots  -> base para snapshots (/.snapshots)
[dry-run]   - @swap       -> contenedor del swapfile

[dry-run] === PASO A PASO EN INSTALACION REAL ===
[dry-run]   1) Confirmar disco objetivo y schema GPT/UEFI
[dry-run]   2) Crear/validar particiones (EFI, SISTEMA, BACKUP)
[dry-run]   3) Crear subvolumenes estándar (@, @home, @snapshots, @swap)
[dry-run]   4) Montar con opciones de rendimiento y generar fstab
[dry-run]   5) Instalar sistema base + Grub + herramientas Btrfs
[dry-run]   6) Validar arranque y preparar snapshots iniciales

[dry-run] === COMANDOS DE REFERENCIA ===
[dry-run]   - lsblk -f               (ver estructura)
[dry-run]   - blkid                  (verificar particiones)
[dry-run]   - btrfs subvolume list / (ver subvolumenes)
[dry-run]   - mount | grep btrfs     (ver montajes activos)
EOF

    ok "preview generado sin operaciones destructivas"
}

# BLOQUE: INSTALL FUNCTIONS (renombrado install_*)
# ============================================
INSTALL_SUGGESTED_HOSTNAME="debian-pc"
INSTALL_SUGGESTED_USERNAME="usuario"

# Valores finales que se van a usar en la instalacion
INSTALL_EFI_SIZE=""
INSTALL_SYSTEM_SIZE=""
INSTALL_SWAP_SIZE=""
INSTALL_CREATE_BACKUP="S"
INSTALL_LOCALE=""
INSTALL_KEYBOARD=""
INSTALL_TIMEZONE=""
HOSTNAME_VALUE=""
USERNAME=""
USER_PASSWORD=""
APT_ENABLE_NONFREE="S"
APT_ENABLE_SECURITY="S"
APT_ENABLE_UPDATES="S"
APT_ENABLE_DEBSRC="N"
APT_PROXY=""
INSTALL_NONFREE_FIRMWARE="S"
ENABLE_POPCON="N"
SOFTWARE_INSTALL_MODE="POSTBOOT"
INSTALL_SSH_IN_BASE="S"
INSTALL_TASKSEL_NOW="N"

# ============================================
# LOG Y MENSAJES
# ============================================

install_step() {
    local msg="[install][step] $*"
    printf "\n%s\n" "$msg" | tee -a "$LOG_FILE"
}

install_ok() {
    local msg="[install][ok] $*"
    printf "%s\n" "$msg" | tee -a "$LOG_FILE"
}

install_warn() {
    local msg="[install][warn] $*"
    printf "%s\n" "$msg" | tee -a "$LOG_FILE"
}

install_fail() {
    local msg="[install][error] $*"
    printf "%s\n" "$msg" | tee -a "$LOG_FILE" >&2
    exit 1
}

install_info() {
    local msg="[install][info] $*"
    printf "%s\n" "$msg" | tee -a "$LOG_FILE"
}

install_have_cmd() {
    command -v "$1" >/dev/null 2>&1
}

# ============================================
# UTILIDADES
# ============================================

install_install_normalize_size_gib() {
    local raw="$1"
    raw="${raw// /}"
    raw="${raw^^}"
    [[ -z "$raw" ]] && raw="1G"
    if [[ "$raw" =~ ^[0-9]+$ ]]; then
        raw="${raw}G"
    fi
    printf '%s\n' "$raw"
}

install_install_size_gib_to_int() {
    local raw="$1"
    raw="$(normalize_size_gib "$raw")"
    if [[ "$raw" =~ ^[0-9]+G$ ]]; then
        printf '%s\n' "${raw%G}"
        return 0
    fi
    printf '0\n'
}

normalize_yes_no() {
    local input="${1:-}"
    input="${input^^}"
    case "$input" in
        S|SI|Y|YES) echo "S" ;;
        N|NO)       echo "N" ;;
        *)          echo ""  ;;
    esac
}

# ============================================
# LIMPIEZA
# ============================================

cleanup_mounts() {
    if [[ "$MOUNTED_CHROOT_BIND" == "true" ]]; then
        umount -R /mnt/proc &>/dev/null || true
        umount -R /mnt/sys  &>/dev/null || true
        umount -R /mnt/dev  &>/dev/null || true
        umount -R /mnt/run  &>/dev/null || true
        MOUNTED_CHROOT_BIND="false"
    fi

    if [[ "$MOUNTED_TARGET" == "true" ]]; then
        umount -R /mnt &>/dev/null || true
        MOUNTED_TARGET="false"
    fi
}

handle_error() {
    local line="$1"
    printf "\n[install][error] Error inesperado en linea %s. Log: %s\n" "$line" "$LOG_FILE" | tee -a "$LOG_FILE" >&2
    cleanup_mounts
}

unmount_disk_partitions() {
    [[ -z "$INSTALL_DISK" ]] && return 0

    while IFS= read -r part; do
        [[ -z "$part" ]] && continue
        swapoff "$part" &>/dev/null || true
        umount  "$part" &>/dev/null || true
    done < <(lsblk -ln -o NAME,TYPE "$INSTALL_DISK" 2>/dev/null | awk '$2=="part"{print "/dev/"$1}')

    command -v udevadm &>/dev/null && udevadm settle || true
    return 0
}

ensure_partition_unmounted() {
    local part="$1"
    local tries=0

    while [[ $tries -lt 5 ]]; do
        if ! findmnt -rn -S "$part" &>/dev/null; then
            return 0
        fi
        while IFS= read -r mnt; do
            [[ -z "$mnt" ]] && continue
            umount "$mnt" &>/dev/null || umount -l "$mnt" &>/dev/null || true
        done < <(findmnt -rn -S "$part" -o TARGET)
        command -v udevadm &>/dev/null && udevadm settle || true
        sleep 1
        tries=$((tries + 1))
    done

    fail "No se pudo desmontar $part. Cierra el explorador de archivos del Live e intenta de nuevo."
}

trap 'handle_error $LINENO' ERR
trap cleanup_mounts EXIT

# ============================================
# 1 - VALIDACIONES
# ============================================

check_requirements() {
    step "1/15 - Verificando requisitos"

    if [[ $EUID -ne 0 ]]; then
        fail "Este script debe ejecutarse como root (sudo)"
    fi
    ok "ejecutando como root"

    if [[ ! -d /sys/firmware/efi ]]; then
        fail "Entorno no UEFI detectado. Este instalador solo soporta UEFI."
    fi
    ok "UEFI detectado"

    if ! ping -c 1 deb.debian.org &>/dev/null; then
        fail "Sin conexion a internet. Verifica la red (Ethernet requerido)."
    fi
    ok "conectividad a deb.debian.org OK"

    local tools_needed=false
    for tool in debootstrap gdisk mkfs.btrfs mkfs.fat lsblk blkid sgdisk partprobe; do
        if ! have_cmd "$tool"; then
            tools_needed=true
            break
        fi
    done

    if [[ "$tools_needed" == true ]]; then
        info "instalando herramientas necesarias..."
        apt-get update &>/dev/null
        apt-get install -y debootstrap gdisk btrfs-progs dosfstools util-linux &>/dev/null
    fi
    ok "herramientas verificadas"
}

# ============================================
# 2 - CALCULAR SUGERENCIAS
# ============================================

calculate_suggestions() {
    step "2/15 - Calculando sugerencias"

    DISK_SIZE_GB="$(lsblk -bdn -o SIZE "$INSTALL_DISK" 2>/dev/null | awk '{print int($1/1024/1024/1024)}')"
    [[ -z "$DISK_SIZE_GB" ]] && DISK_SIZE_GB=0
    RAM_GB="$(free -m 2>/dev/null | awk '/^Mem:/{print int($2/1024)}')"
    [[ -z "$RAM_GB" ]] && RAM_GB=0

    INSTALL_DISK_SIZE_GB="$DISK_SIZE_GB"
    INSTALL_RAM_GB="$RAM_GB"

    if [[ $INSTALL_DISK_SIZE_GB -lt 128 ]]; then
        SUGGESTED_SYSTEM_PCT=90
    elif [[ $INSTALL_DISK_SIZE_GB -lt 256 ]]; then
        SUGGESTED_SYSTEM_PCT=85
    else
        SUGGESTED_SYSTEM_PCT=80
    fi

    SUGGESTED_SYSTEM_GB=$((DISK_SIZE_GB * SUGGESTED_SYSTEM_PCT / 100))
    SUGGESTED_BACKUP_GB=$((DISK_SIZE_GB - SUGGESTED_SYSTEM_GB - 1))
    (( SUGGESTED_BACKUP_GB <= 0 )) && SUGGESTED_BACKUP_GB=0

    if [[ $INSTALL_RAM_GB -le 2 ]]; then
        SUGGESTED_SWAP="${RAM_GB}G"
        SWAP_REASON="igual a RAM"
    elif [[ $INSTALL_RAM_GB -le 8 ]]; then
        SUGGESTED_SWAP="$((RAM_GB * 2))G"
        SWAP_REASON="2x RAM"
    elif [[ $INSTALL_RAM_GB -le 16 ]]; then
        SUGGESTED_SWAP="${RAM_GB}G"
        SWAP_REASON="igual a RAM"
    else
        SUGGESTED_SWAP="8G"
        SWAP_REASON="8GB fijo"
    fi

    if grep -qiE 'laptop|notebook' /sys/class/dmi/id/product_name 2>/dev/null; then
        SUGGESTED_HOSTNAME="debian-laptop"
    else
        SUGGESTED_HOSTNAME="debian-pc"
    fi

    ok "sugerencias calculadas (disco: ${DISK_SIZE_GB}GB, RAM: ${RAM_GB}GB)"
}

# ============================================
# 3 - SELECCION DE DISCO (interactivo en terminal)
# ============================================

select_disk() {
    step "3/15 - Seleccion de disco"

    local disks=()
    local disk_info=()
    local live_root_src live_root_disk

    live_root_src="$(findmnt -n -o SOURCE / 2>/dev/null || true)"
    live_root_disk="$(lsblk -ndo PKNAME "$live_root_src" 2>/dev/null || true)"

    while IFS= read -r line; do
        local dname dsize dmodel dtype drm
        dname="$(echo "$line" | awk '{print $1}')"
        dsize="$(lsblk -ndo SIZE "/dev/$dname" 2>/dev/null | xargs)"
        dmodel="$(lsblk -ndo MODEL "/dev/$dname" 2>/dev/null | xargs)"
        dtype="$(lsblk -ndo TYPE "/dev/$dname" 2>/dev/null)"
        if [[ "$dtype" == "disk" ]]; then
            disks+=("/dev/$dname")
            disk_info+=("$dsize $dmodel")
        fi
    done < <(lsblk -ndpo NAME | sed 's|/dev/||')

    if [[ ${#disks[@]} -eq 0 ]]; then
        fail "No se detectaron discos"
    fi

    printf "\n[install] DISCOS DISPONIBLES:\n\n" > /dev/tty
    for i in "${!disks[@]}"; do
        local idx=$((i + 1))
        printf "  [%s] %s  (%s)\n" "$idx" "${disks[$i]}" "${disk_info[$i]}" > /dev/tty
        if [[ -n "$live_root_disk" ]] && [[ "${disks[$i]}" == "/dev/$live_root_disk" ]]; then
            printf "       ⚠  Puede ser el disco live actual\n" > /dev/tty
        fi
        if lsblk -n "${disks[$i]}" 2>/dev/null | grep -q part; then
            printf "       ⚠  Contiene particiones existentes\n" > /dev/tty
            lsblk -ln -o NAME,SIZE,FSTYPE,LABEL "${disks[$i]}" 2>/dev/null \
                | awk 'NR>1{printf "       %s %s %s %s\n",$1,$2,$3,$4}' > /dev/tty || true
        fi
    done
    printf "\n" > /dev/tty

    local selection candidate
    while true; do
        read -r -p "[install] Selecciona disco [1-${#disks[@]}]: " selection < /dev/tty
        selection="${selection:-1}"
        if [[ "$selection" =~ ^[0-9]+$ ]] && \
           (( selection >= 1 )) && (( selection <= ${#disks[@]} )); then
            candidate="${disks[$((selection - 1))]}"
            if lsblk -n "$candidate" 2>/dev/null | grep -q part; then
                printf "\n[install][warn] El disco %s contiene particiones. SERAN ELIMINADAS.\n" "$candidate" > /dev/tty
                local wipe_confirm
                read -r -p "[install] Continuar (S/N) [N]: " wipe_confirm < /dev/tty
                wipe_confirm="$(normalize_yes_no "${wipe_confirm:-N}")"
                if [[ "$wipe_confirm" != "S" ]]; then
                    printf "[install] Escoge otro disco.\n" > /dev/tty
                    continue
                fi
            fi
            DISK="$candidate"
            break
        fi
        printf "[install] Seleccion invalida.\n" > /dev/tty
    done

    ok "disco seleccionado: $INSTALL_DISK"
}

# ============================================
# 4 - PEDIR PASSWORD (interactivo en terminal)
# ============================================

ask_password() {
    step "4/15 - Definir password de usuario"

    local pw1 pw2
    printf "\n[install] Ingresa password para el usuario '%s':\n" "$USERNAME" > /dev/tty
    while true; do
        read -r -s -p "[install] Password: " pw1 < /dev/tty
        printf "\n" > /dev/tty
        if [[ -z "$pw1" ]]; then
            printf "[install][warn] La password no puede estar vacia.\n" > /dev/tty
            continue
        fi
        read -r -s -p "[install] Repite password: " pw2 < /dev/tty
        printf "\n" > /dev/tty
        if [[ "$pw1" == "$pw2" ]]; then
            USER_PASSWORD="$pw1"
            break
        fi
        printf "[install][warn] Las passwords no coinciden, intenta de nuevo.\n" > /dev/tty
    done
    ok "password de usuario definida"
}

# ============================================
# 5 - RESUMEN PRE-INSTALACION
# ============================================

print_install_summary() {
    step "5/15 - Resumen de instalacion"

    local system_num backup_calc
    system_num="$(echo "$INSTALL_SYSTEM_SIZE" | sed 's/[^0-9]//g')"
    backup_calc=$((DISK_SIZE_GB - system_num - 1))

    printf "\n[install] === RESUMEN ===\n\n"
    printf "[install] disco    --> %s (%sGB)\n" "$INSTALL_DISK" "$INSTALL_DISK_SIZE_GB"
    printf "\n[install] PARTICIONES:\n"
    printf "[install]   EFI    --> %s   FAT32   /boot/efi\n" "$INSTALL_EFI_SIZE"
    printf "[install]   SISTEMA--> %s   BTRFS   /\n" "$INSTALL_SYSTEM_SIZE"
    if [[ "$INSTALL_CREATE_BACKUP" == "S" ]]; then
        printf "[install]   BACKUP --> %sG   BTRFS   (desmontada)\n" "$backup_calc"
    else
        printf "[install]   BACKUP --> no crear\n"
    fi
    printf "[install]   SWAP   --> %s   (swapfile en @swap)\n" "$INSTALL_SWAP_SIZE"
    printf "\n[install] SUBVOLUMENES:\n"
    printf "[install]   @ @home @snapshots @cache @log @tmp @swap\n"
    printf "\n[install] SISTEMA:\n"
    printf "[install]   Debian:   %s\n" "$DEBIAN_RELEASE"
    printf "[install]   Hostname: %s\n" "$HOSTNAME_VALUE"
    printf "[install]   Usuario:  %s (sudo, root bloqueado)\n" "$USERNAME"
    printf "[install]   Locale:   %s\n" "$LOCALE"
    printf "[install]   Timezone: %s\n" "$TIMEZONE"
    printf "[install]   Teclado:  %s\n" "$KEYBOARD"
    printf "\n[install] SOFTWARE:\n"
    printf "[install]   Modo:     %s\n" "$SOFTWARE_INSTALL_MODE"
    printf "[install]   SSH base: %s\n" "$INSTALL_SSH_IN_BASE"
    printf "[install]   non-free: %s  security: %s  updates: %s\n" \
        "$APT_ENABLE_NONFREE" "$APT_ENABLE_SECURITY" "$APT_ENABLE_UPDATES"
    printf "\n[install][warn] TODOS LOS DATOS EN %s SERAN ELIMINADOS.\n\n" "$INSTALL_DISK"

    local confirm
    read -r -p "[install] Escribe exactamente '$INSTALL_DISK' para confirmar: " confirm < /dev/tty
    if [[ "$confirm" != "$INSTALL_DISK" ]]; then
        fail "Confirmacion incorrecta. Instalacion cancelada."
    fi
    ok "confirmacion aceptada"
}

# ============================================
# 6 - PARTICIONADO
# ============================================

partition_disk() {
    step "6/15 - Particionando $INSTALL_DISK"

    unmount_disk_partitions

    local P=""
    [[ "$INSTALL_DISK" =~ nvme ]] && P="p"

    EFI_PART="${DISK}${P}1"
    SYSTEM_PART="${DISK}${P}2"
    BACKUP_PART="${DISK}${P}3"

    sgdisk -Z "$INSTALL_DISK" &>/dev/null || true
    sgdisk -og "$INSTALL_DISK" || fail "Error creando GPT"
    sgdisk -n "1::+${EFI_SIZE}"    -t 1:ef00 -c 1:"EFI"     "$INSTALL_DISK" || fail "Error particion EFI"
    sgdisk -n "2::+${SYSTEM_SIZE}" -t 2:8300 -c 2:"SISTEMA"  "$INSTALL_DISK" || fail "Error particion Sistema"

    if [[ "$INSTALL_CREATE_BACKUP" == "S" ]]; then
        sgdisk -n 3:: -t 3:8300 -c 3:"BACKUP" "$INSTALL_DISK" || fail "Error particion Backup"
    fi

    partprobe "$INSTALL_DISK" &>/dev/null || true
    sleep 2
    ok "disco particionado"
}

# ============================================
# 7 - FORMATEO
# ============================================

format_partitions() {
    step "7/15 - Formateando particiones"

    unmount_disk_partitions
    ensure_partition_unmounted "$INSTALL_EFI_PART"
    ensure_partition_unmounted "$INSTALL_SYSTEM_PART"
    [[ "$INSTALL_CREATE_BACKUP" == "S" ]] && ensure_partition_unmounted "$INSTALL_BACKUP_PART"

    mkfs.fat -F32 -n EFI    "$INSTALL_EFI_PART"    || fail "Error formateando EFI"
    mkfs.btrfs -f -L DEBIAN "$INSTALL_SYSTEM_PART" || fail "Error formateando Sistema"

    if [[ "$INSTALL_CREATE_BACKUP" == "S" ]]; then
        mkfs.btrfs -f -L BACKUP "$INSTALL_BACKUP_PART" || fail "Error formateando Backup"
        BACKUP_UUID="$(blkid -s UUID -o value "$INSTALL_BACKUP_PART")"
    fi

    EFI_UUID="$(blkid -s UUID -o value "$INSTALL_EFI_PART")"
    SYSTEM_UUID="$(blkid -s UUID -o value "$INSTALL_SYSTEM_PART")"
    ok "particiones formateadas"
}

# ============================================
# 8 - SUBVOLUMENES BTRFS
# ============================================

create_subvolumes() {
    step "8/15 - Creando subvolumenes btrfs"

    mount "$INSTALL_SYSTEM_PART" /mnt || fail "Error montando sistema"

    btrfs subvolume create /mnt/@          || fail "Error creando @"
    btrfs subvolume create /mnt/@home
    btrfs subvolume create /mnt/@snapshots
    btrfs subvolume create /mnt/@cache
    btrfs subvolume create /mnt/@log
    btrfs subvolume create /mnt/@tmp
    btrfs subvolume create /mnt/@swap

    umount /mnt
    ok "subvolumenes creados"
}

create_mount_structure() {
    step "8b/15 - Montando estructura"

    mount -o "$BTRFS_OPTS,subvol=@" "$INSTALL_SYSTEM_PART" /mnt

    mkdir -p /mnt/{home,boot/efi,.snapshots,var/{cache,log,tmp,swap}}

    mount -o "$BTRFS_OPTS,subvol=@home"      "$INSTALL_SYSTEM_PART" /mnt/home
    mount -o "$BTRFS_OPTS,subvol=@snapshots" "$INSTALL_SYSTEM_PART" /mnt/.snapshots
    mount -o "$BTRFS_OPTS,subvol=@cache"     "$INSTALL_SYSTEM_PART" /mnt/var/cache
    mount -o "$BTRFS_OPTS,subvol=@log"       "$INSTALL_SYSTEM_PART" /mnt/var/log
    mount -o "$BTRFS_OPTS,subvol=@tmp"       "$INSTALL_SYSTEM_PART" /mnt/var/tmp
    mount -o "defaults,noatime,subvol=@swap" "$INSTALL_SYSTEM_PART" /mnt/var/swap

    mount "$INSTALL_EFI_PART" /mnt/boot/efi
    MOUNTED_TARGET="true"
    ok "estructura montada"
}

# ============================================
# 9 - SISTEMA BASE (debootstrap)
# ============================================

install_base() {
    step "9/15 - Instalando sistema base con debootstrap (varios minutos)"

    debootstrap --arch=amd64 "$DEBIAN_RELEASE" /mnt "$DEBIAN_MIRROR" \
        || fail "Error en debootstrap"
    ok "sistema base instalado"
}

# ============================================
# 10 - CONFIGURACION (fstab + sistema + APT)
# ============================================

configure_fstab() {
    step "10/15 - Generando fstab"

    cat > /mnt/etc/fstab << EOF
# /etc/fstab - generado por install.sh (v008)
UUID=$SYSTEM_UUID  /              btrfs  $BTRFS_OPTS,subvol=@           0 0
UUID=$SYSTEM_UUID  /home          btrfs  $BTRFS_OPTS,subvol=@home       0 0
UUID=$SYSTEM_UUID  /.snapshots    btrfs  $BTRFS_OPTS,subvol=@snapshots  0 0
UUID=$SYSTEM_UUID  /var/cache     btrfs  $BTRFS_OPTS,subvol=@cache      0 0
UUID=$SYSTEM_UUID  /var/log       btrfs  $BTRFS_OPTS,subvol=@log        0 0
UUID=$SYSTEM_UUID  /var/tmp       btrfs  $BTRFS_OPTS,subvol=@tmp        0 0
UUID=$SYSTEM_UUID  /var/swap      btrfs  defaults,noatime,subvol=@swap  0 0
UUID=$EFI_UUID     /boot/efi      vfat   defaults,noatime               0 2
EOF

    if [[ "$INSTALL_CREATE_BACKUP" == "S" ]]; then
        echo "# UUID=$BACKUP_UUID  /mnt/backup  btrfs  defaults,noatime  0 0" >> /mnt/etc/fstab
    fi

    ok "fstab generado"
}

configure_system() {
    step "10b/15 - Configurando hostname, timezone y locale"

    echo "$HOSTNAME_VALUE" > /mnt/etc/hostname

    cat > /mnt/etc/hosts << EOF
127.0.0.1   localhost
127.0.1.1   $HOSTNAME_VALUE

::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOF

    ln -sf "/usr/share/zoneinfo/$TIMEZONE" /mnt/etc/localtime

    echo "$LOCALE UTF-8"   >> /mnt/etc/locale.gen
    echo "en_US.UTF-8 UTF-8" >> /mnt/etc/locale.gen

    # Teclado
    mkdir -p /mnt/etc/default
    cat > /mnt/etc/default/keyboard << EOF
XKBMODEL="pc105"
XKBLAYOUT="$KEYBOARD"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOF

    ok "hostname, timezone, locale y teclado configurados"
}

configure_apt_sources() {
    step "10c/15 - Configurando repositorios APT"

    local components="main"
    if [[ "$APT_ENABLE_NONFREE" == "S" ]]; then
        components="main contrib non-free non-free-firmware"
    fi

    : > /mnt/etc/apt/sources.list

    echo "deb $DEBIAN_MIRROR $DEBIAN_RELEASE $components" >> /mnt/etc/apt/sources.list
    if [[ "$APT_ENABLE_DEBSRC" == "S" ]]; then
        echo "deb-src $DEBIAN_MIRROR $DEBIAN_RELEASE $components" >> /mnt/etc/apt/sources.list
    fi

    if [[ "$APT_ENABLE_SECURITY" == "S" ]]; then
        printf "\ndeb http://deb.debian.org/debian-security %s-security %s\n" \
            "$DEBIAN_RELEASE" "$components" >> /mnt/etc/apt/sources.list
        if [[ "$APT_ENABLE_DEBSRC" == "S" ]]; then
            printf "deb-src http://deb.debian.org/debian-security %s-security %s\n" \
                "$DEBIAN_RELEASE" "$components" >> /mnt/etc/apt/sources.list
        fi
    fi

    if [[ "$APT_ENABLE_UPDATES" == "S" ]]; then
        printf "\ndeb %s %s-updates %s\n" \
            "$DEBIAN_MIRROR" "$DEBIAN_RELEASE" "$components" >> /mnt/etc/apt/sources.list
        if [[ "$APT_ENABLE_DEBSRC" == "S" ]]; then
            printf "deb-src %s %s-updates %s\n" \
                "$DEBIAN_MIRROR" "$DEBIAN_RELEASE" "$components" >> /mnt/etc/apt/sources.list
        fi
    fi

    if [[ -n "$APT_PROXY" ]]; then
        mkdir -p /mnt/etc/apt/apt.conf.d
        cat > /mnt/etc/apt/apt.conf.d/90proxy << EOF
Acquire::http::Proxy "$APT_PROXY";
Acquire::https::Proxy "$APT_PROXY";
EOF
    fi

    ok "repositorios configurados"
}

# ============================================
# 11 - USUARIO
# ============================================

create_user() {
    step "11/15 - Creando usuario y configurando locales"

    mount -t proc   /proc         /mnt/proc
    mount -t sysfs  /sys          /mnt/sys
    mount --rbind   /dev          /mnt/dev
    mount --rbind   /run          /mnt/run
    mkdir -p /mnt/dev/pts
    mount -t devpts devpts /mnt/dev/pts &>/dev/null || true
    MOUNTED_CHROOT_BIND="true"

    cp /etc/resolv.conf /mnt/etc/

    chroot /mnt apt-get update
    chroot /mnt apt-get install -y locales sudo

    chroot /mnt locale-gen

    if [[ "$ENABLE_POPCON" == "S" ]]; then
        chroot /mnt apt-get install -y popularity-contest || true
    fi

    chroot /mnt useradd -m -s /bin/bash -G sudo "$USERNAME"
    printf '%s:%s\n' "$USERNAME" "$USER_PASSWORD" | chroot /mnt chpasswd
    chroot /mnt passwd -l root

    ok "usuario $USERNAME creado (root bloqueado)"
}

# ============================================
# 12 - KERNEL, GRUB y GRUB-BTRFS
# ============================================

install_kernel_grub() {
    step "12/15 - Instalando kernel, GRUB y grub-btrfs"

    chroot /mnt apt-get update
    chroot /mnt apt-get install -y linux-image-amd64 linux-headers-amd64

    if [[ "$INSTALL_NONFREE_FIRMWARE" == "S" ]]; then
        chroot /mnt apt-get install -y firmware-linux firmware-linux-nonfree || true
    fi

    chroot /mnt apt-get install -y grub-efi-amd64 efibootmgr
    chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi \
        --bootloader-id=DEBIAN --no-nvram
    chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi \
        --bootloader-id=DEBIAN --removable

    chroot /mnt apt-get install -y btrfs-progs

    # grub-btrfs: intentar desde repos, fallback a GitHub
    if chroot /mnt apt-cache show grub-btrfs &>/dev/null; then
        chroot /mnt apt-get install -y grub-btrfs
        GRUB_BTRFS_INSTALLED="S"
    else
        warn "grub-btrfs no disponible en repos; intentando desde GitHub"
        chroot /mnt apt-get install -y git make
        if chroot /mnt bash -lc 'set -e
            tmpdir=$(mktemp -d)
            cd "$tmpdir"
            git clone https://github.com/Antynea/grub-btrfs.git
            cd grub-btrfs
            make install
            cd /
            rm -rf "$tmpdir"'; then
            GRUB_BTRFS_INSTALLED="S"
        else
            warn "No se pudo instalar grub-btrfs desde GitHub"
            GRUB_BTRFS_INSTALLED="N"
        fi
    fi

    if [[ "$GRUB_BTRFS_INSTALLED" == "S" ]]; then
        mkdir -p /mnt/etc/default/grub-btrfs
        cat > /mnt/etc/default/grub-btrfs/config << 'EOF'
GRUB_BTRFS_SUBMENUNAME="Debian Snapshots"
GRUB_BTRFS_LIMIT="10"
GRUB_BTRFS_SHOW_SNAPSHOTS_FOUND="true"
GRUB_BTRFS_SNAPSHOT_KERNEL_PARAMETERS=""
GRUB_BTRFS_IGNORE_SPECIFIC_PATH=("@")
EOF
        chroot /mnt systemctl enable grub-btrfsd.service || true
        ok "grub-btrfs instalado y configurado"
    else
        warn "grub-btrfs no instalado; el submenu de snapshots no estara disponible"
    fi

    chroot /mnt update-grub
    ok "kernel y GRUB instalados"
}

# ============================================
# 13 - SOFTWARE BASE
# ============================================

install_software() {
    step "13/15 - Instalando software base (modo: $SOFTWARE_INSTALL_MODE)"

    case "$SOFTWARE_INSTALL_MODE" in
        AUTO)
            if [[ "$INSTALL_TASKSEL_NOW" == "S" ]]; then
                chroot /mnt apt-get install -y tasksel
            fi
            chroot /mnt apt-get install -y tasksel
            if ! chroot /mnt tasksel install standard; then
                warn "tasksel no pudo completar; fallback con apt"
                chroot /mnt apt-get install -y task-standard
            fi
            if [[ "$INSTALL_SSH_IN_BASE" == "S" ]]; then
                chroot /mnt apt-get install -y openssh-server
            fi
            ;;
        INTERACTIVE)
            chroot /mnt apt-get install -y tasksel
            chroot /mnt tasksel --new-install
            if [[ "$INSTALL_SSH_IN_BASE" == "S" ]] && \
               ! chroot /mnt dpkg -l 2>/dev/null | grep -q "^ii.*openssh-server"; then
                chroot /mnt apt-get install -y openssh-server
            fi
            ;;
        POSTBOOT)
            if [[ "$INSTALL_TASKSEL_NOW" == "S" ]]; then
                chroot /mnt apt-get install -y tasksel
            fi
            if [[ "$INSTALL_SSH_IN_BASE" == "S" ]]; then
                chroot /mnt apt-get install -y openssh-server
            fi
            ;;
        *)
            warn "modo de software desconocido, no se instalan tareas adicionales"
            ;;
    esac

    if chroot /mnt dpkg -l 2>/dev/null | grep -q "^ii.*openssh-server"; then
        mkdir -p /mnt/etc/ssh/sshd_config.d
        cat > /mnt/etc/ssh/sshd_config.d/security.conf << 'EOF'
PermitRootLogin no
MaxAuthTries 3
EOF
        ok "SSH instalado y configurado (PermitRootLogin no)"
    fi

    ok "software base instalado"
}

# ============================================
# 14 - RED y SWAPFILE
# ============================================

configure_network() {
    step "14/15 - Configurando red (DHCP via systemd-networkd)"

    mkdir -p /mnt/etc/systemd/network
    cat > /mnt/etc/systemd/network/20-wired.network << 'EOF'
[Match]
Name=en* eth*

[Network]
DHCP=yes
EOF

    chroot /mnt systemctl enable systemd-networkd

    chroot /mnt apt-get install -y systemd-resolved &>/dev/null || true
    if chroot /mnt systemctl list-unit-files 2>/dev/null | grep -q '^systemd-resolved\.service'; then
        chroot /mnt systemctl enable systemd-resolved
        ln -sf /run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf
    else
        warn "systemd-resolved no disponible; se deja resolv.conf estatico"
        cat > /mnt/etc/resolv.conf << 'EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF
    fi

    ok "red configurada"
}

create_swapfile() {
    step "14b/15 - Creando swapfile ($INSTALL_SWAP_SIZE)"

    local swap_gb
    swap_gb="$(size_gib_to_int "$INSTALL_SWAP_SIZE")"
    (( swap_gb < 1 )) && swap_gb=1
    local swap_mb=$((swap_gb * 1024))

    chroot /mnt truncate -s 0 /var/swap/swapfile
    chroot /mnt chattr +C /var/swap/swapfile
    chroot /mnt dd if=/dev/zero of=/var/swap/swapfile bs=1M count="$swap_mb" status=progress
    chroot /mnt chmod 600 /var/swap/swapfile
    chroot /mnt mkswap /var/swap/swapfile

    echo "/var/swap/swapfile none swap defaults 0 0" >> /mnt/etc/fstab

    ok "swapfile creado"
}

# ============================================
# 15 - RESUMEN FINAL
# ============================================

final_cleanup() {
    chroot /mnt update-grub &>/dev/null || true
    cleanup_mounts
}

show_final_summary() {
    step "15/15 - Instalacion completada"

    printf "\n[install] ============================================\n"
    printf "[install] DEBIAN %s INSTALADO CORRECTAMENTE\n" "$DEBIAN_RELEASE"
    printf "[install] ============================================\n\n"

    printf "[install] disco    : %s\n" "$INSTALL_DISK"
    printf "[install] hostname : %s\n" "$HOSTNAME_VALUE"
    printf "[install] usuario  : %s (sudo, root bloqueado)\n" "$USERNAME"
    printf "[install] locale   : %s\n" "$LOCALE"
    printf "[install] timezone : %s\n" "$TIMEZONE"
    printf "[install] teclado  : %s\n" "$KEYBOARD"
    if [[ "$GRUB_BTRFS_INSTALLED" == "S" ]]; then
        printf "[install] grub-btrfs: instalado y habilitado\n"
    else
        printf "[install] grub-btrfs: NO instalado\n"
    fi
    if chroot /mnt dpkg -l 2>/dev/null | grep -q "^ii.*openssh-server"; then
        printf "[install] SSH     : instalado - ssh %s@<IP>\n" "$USERNAME"
    fi

    if [[ "$INSTALL_CREATE_BACKUP" == "S" ]]; then
        printf "\n[install] UUID particion backup:\n[install]   %s\n" "$BACKUP_UUID"
        printf "[install] (usar en /etc/btrbk/btrbk.conf)\n"
    fi

    printf "\n[install] SUBVOLUMENES:\n"
    printf "[install]   @ -> /  |  @home -> /home  |  @snapshots -> /.snapshots\n"
    printf "[install]   @cache @log @tmp @swap\n"

    printf "\n[install] PROXIMOS PASOS:\n"
    printf "[install]   1) sudo apt install snapper\n"
    printf "[install]      sudo snapper -c root create-config /\n"
    printf "[install]      sudo btrfs subvolume delete /.snapshots\n"
    printf "[install]      sudo mkdir /.snapshots && sudo mount -a\n"
    printf "[install]   2) sudo apt install btrbk\n"
    printf "[install]      sudo nano /etc/btrbk/btrbk.conf\n"

    printf "\n[install] ANTES DE REINICIAR:\n"
    printf "[install]   - Retira/desmonta el medio de instalacion (ISO/USB) en la VM.\n"
    printf "[install]   - Verifica que el disco instalado quede primero en el orden de booteo.\n"

    printf "\n[install] NOTA SOBRE GRUB:\n"
    printf "[install]   - La entrada 'UEFI Firmware Settings' puede no aparecer en algunas VMs.\n"
    printf "[install]   - Su presencia depende del soporte fwsetup del firmware virtual.\n"

    printf "\n[install] log completo: %s\n" "$LOG_FILE"
    printf "\n"
}

INTERNAL_MODE=""

# Compatibilidad para funciones heredadas de install/dry-run integradas.
step() {
    if [[ "$INTERNAL_MODE" == "dryrun" ]]; then
        dryrun_step "$@"
    else
        install_step "$@"
    fi
}

ok() {
    if [[ "$INTERNAL_MODE" == "dryrun" ]]; then
        dryrun_ok "$@"
    else
        install_ok "$@"
    fi
}

warn() {
    if [[ "$INTERNAL_MODE" == "dryrun" ]]; then
        dryrun_warn "$@"
    else
        install_warn "$@"
    fi
}

fail() {
    if [[ "$INTERNAL_MODE" == "dryrun" ]]; then
        dryrun_fail "$@"
    else
        install_fail "$@"
    fi
}

info() {
    if [[ "$INTERNAL_MODE" == "dryrun" ]]; then
        dryrun_info "$@"
    else
        install_info "$@"
    fi
}

have_cmd() {
    if [[ "$INTERNAL_MODE" == "dryrun" ]]; then
        dryrun_have_cmd "$@"
    else
        install_have_cmd "$@"
    fi
}

normalize_size_gib() {
    if [[ "$INTERNAL_MODE" == "dryrun" ]]; then
        dryrun_dryrun_normalize_size_gib "$@"
    else
        install_install_normalize_size_gib "$@"
    fi
}

size_gib_to_int() {
    if [[ "$INTERNAL_MODE" == "dryrun" ]]; then
        dryrun_dryrun_size_gib_to_int "$@"
    else
        install_install_size_gib_to_int "$@"
    fi
}

internal_dryrun_report() {
    printf "[dry-run] === DEBIAN BTRFS INSTALLER - INFORME INTERNO ===\n"
    printf "[dry-run] fecha: %s\n" "$(date '+%Y-%m-%d %H:%M:%S')"
    printf "[dry-run] disco objetivo: %s\n" "${DRYRUN_DISK:-no seleccionado}"
    printf "[dry-run] EFI: %s | Sistema: %s | Swap: %s | Backup: %s\n" \
        "${DRYRUN_EFI_SIZE:-1G}" "${DRYRUN_SYSTEM_SIZE:-64G}" "${DRYRUN_SWAP_SIZE:-8G}" "${DRYRUN_CREATE_BACKUP:-S}"
    printf "[dry-run] locale=%s keyboard=%s timezone=%s\n" \
        "${DRYRUN_LOCALE:-en_US.UTF-8}" "${DRYRUN_KEYBOARD:-us}" "${DRYRUN_TIMEZONE:-UTC}"
    printf "[dry-run] hostname=%s usuario=%s\n" \
        "${DRYRUN_HOSTNAME:-debian-pc}" "${DRYRUN_USERNAME:-usuario}"
    printf "[dry-run] non-free=%s security=%s updates=%s deb-src=%s\n" \
        "${DRYRUN_APT_ENABLE_NONFREE:-S}" "${DRYRUN_APT_ENABLE_SECURITY:-S}" "${DRYRUN_APT_ENABLE_UPDATES:-S}" "${DRYRUN_APT_ENABLE_DEBSRC:-N}"
    printf "[dry-run] modo software=%s ssh-base=%s tasksel-ahora=%s\n" \
        "${DRYRUN_SOFTWARE_INSTALL_MODE:-POSTBOOT}" "${DRYRUN_INSTALL_SSH_IN_BASE:-S}" "${DRYRUN_INSTALL_TASKSEL_NOW:-N}"
    printf "\n[dry-run] Hardware detectado:\n"
    lsblk -e7 -o NAME,TYPE,SIZE,FSTYPE,MOUNTPOINTS 2>/dev/null | sed 's/^/[dry-run]   /' || true
    printf "\n[dry-run] Ruta por defecto:\n"
    ip route show default 2>/dev/null | sed 's/^/[dry-run]   /' || printf "[dry-run]   sin ruta por defecto\n"
    printf "\n[dry-run] Analisis completado sin cambios destructivos.\n"
}

internal_install_pipeline() {
    INTERNAL_MODE="install"

    LOG_FILE="/tmp/debian-btrfs-install-$(date +%Y%m%d-%H%M%S).log"
    MOUNTED_TARGET="false"
    MOUNTED_CHROOT_BIND="false"
    GRUB_BTRFS_INSTALLED="N"

    DEBIAN_RELEASE="${DEBIAN_RELEASE:-bookworm}"
    DEBIAN_MIRROR="${DEBIAN_MIRROR:-http://deb.debian.org/debian}"
    BTRFS_OPTS="${BTRFS_OPTS:-defaults,noatime,compress=zstd:3,space_cache=v2,ssd}" 

    INSTALL_DISK="${DRYRUN_DISK:-}"
    [[ -z "$INSTALL_DISK" ]] && install_fail "No se recibio DRYRUN_DISK desde la UI"

    INSTALL_EFI_SIZE="${DRYRUN_EFI_SIZE:-1G}"
    INSTALL_SYSTEM_SIZE="${DRYRUN_SYSTEM_SIZE:-64G}"
    INSTALL_SWAP_SIZE="${DRYRUN_SWAP_SIZE:-8G}"
    INSTALL_CREATE_BACKUP="${DRYRUN_CREATE_BACKUP:-S}"

    INSTALL_LOCALE="${DRYRUN_LOCALE:-en_US.UTF-8}"
    INSTALL_KEYBOARD="${DRYRUN_KEYBOARD:-us}"
    INSTALL_TIMEZONE="${DRYRUN_TIMEZONE:-UTC}"
    HOSTNAME_VALUE="${DRYRUN_HOSTNAME:-debian-pc}"
    USERNAME="${DRYRUN_USERNAME:-usuario}"
    USER_PASSWORD="${INSTALL_USER_PASSWORD:-}"
    [[ -z "$USER_PASSWORD" ]] && install_fail "No se recibio INSTALL_USER_PASSWORD desde la UI"

    APT_ENABLE_NONFREE="${DRYRUN_APT_ENABLE_NONFREE:-S}"
    APT_ENABLE_SECURITY="${DRYRUN_APT_ENABLE_SECURITY:-S}"
    APT_ENABLE_UPDATES="${DRYRUN_APT_ENABLE_UPDATES:-S}"
    APT_ENABLE_DEBSRC="${DRYRUN_APT_ENABLE_DEBSRC:-N}"
    APT_PROXY="${DRYRUN_APT_PROXY:-}"
    INSTALL_NONFREE_FIRMWARE="${DRYRUN_INSTALL_NONFREE_FIRMWARE:-S}"
    ENABLE_POPCON="${DRYRUN_ENABLE_POPCON:-N}"
    SOFTWARE_INSTALL_MODE="${DRYRUN_SOFTWARE_INSTALL_MODE:-POSTBOOT}"
    INSTALL_SSH_IN_BASE="${DRYRUN_INSTALL_SSH_IN_BASE:-S}"
    INSTALL_TASKSEL_NOW="${DRYRUN_INSTALL_TASKSEL_NOW:-N}"

    # Compatibilidad con nombres heredados usados por funciones del bloque install.
    DISK="$INSTALL_DISK"
    EFI_SIZE="$INSTALL_EFI_SIZE"
    SYSTEM_SIZE="$INSTALL_SYSTEM_SIZE"
    SWAP_SIZE="$INSTALL_SWAP_SIZE"
    LOCALE="$INSTALL_LOCALE"
    KEYBOARD="$INSTALL_KEYBOARD"
    TIMEZONE="$INSTALL_TIMEZONE"

    check_requirements
    calculate_suggestions

    INSTALL_DISK_SIZE_GB="${DISK_SIZE_GB:-0}"
    INSTALL_RAM_GB="${RAM_GB:-0}"

    print_install_summary
    partition_disk

    INSTALL_EFI_PART="${EFI_PART:-}"
    INSTALL_SYSTEM_PART="${SYSTEM_PART:-}"
    INSTALL_BACKUP_PART="${BACKUP_PART:-}"

    format_partitions
    create_subvolumes
    create_mount_structure
    install_base
    configure_fstab
    configure_system
    configure_apt_sources
    create_user
    install_kernel_grub
    install_software
    configure_network
    create_swapfile
    show_final_summary
    final_cleanup
}

if [[ "${1:-}" == "--internal-dryrun-report" ]]; then
    INTERNAL_MODE="dryrun"
    internal_dryrun_report
    exit $?
fi

if [[ "${1:-}" == "--internal-install" ]]; then
    internal_install_pipeline
    exit $?
fi

# ============================================
# MAIN
# ============================================
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
