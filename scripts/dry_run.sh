#!/bin/bash
set -euo pipefail

# Opcion 2 (v008) - Modo prueba (dry-run)
# Flujo ampliado: validaciones, deteccion y preview sin cambios destructivos.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

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

step() {
    printf "\n[dry-run][step] %s\n" "$1"
}

ok() {
    printf "[dry-run][ok] %s\n" "$1"
}

warn() {
    printf "[dry-run][warn] %s\n" "$1"
}

fail() {
    printf "[dry-run][error] %s\n" "$1" >&2
    exit 1
}

info() {
    printf "[dry-run][info] %s\n" "$1"
}

have_cmd() {
    command -v "$1" >/dev/null 2>&1
}

normalize_size_gib() {
    local raw="$1"
    raw="${raw// /}"
    raw="${raw^^}"
    [[ -z "$raw" ]] && raw="1G"
    if [[ "$raw" =~ ^[0-9]+$ ]]; then
        raw="${raw}G"
    fi
    printf '%s\n' "$raw"
}

size_gib_to_int() {
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

calculate_recommendations() {
    if [[ -z "$DISK" ]]; then
        warn "no hay disco sugerido; no se pueden calcular recomendaciones"
        return 1
    fi

    RAM_GB="$(free -m 2>/dev/null | awk '/^Mem:/{print int($2/1024)}')"
    [[ -z "$RAM_GB" ]] && RAM_GB=0

    if [[ $DISK_SIZE_GB -lt 128 ]]; then
        SUGGESTED_SYSTEM_PCT=90
    elif [[ $DISK_SIZE_GB -lt 256 ]]; then
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

    if [[ $RAM_GB -le 2 ]]; then
        SUGGESTED_SWAP="${RAM_GB}G"
        SWAP_REASON="igual a RAM (sistema con poca memoria)"
    elif [[ $RAM_GB -le 8 ]]; then
        SUGGESTED_SWAP="$((RAM_GB * 2))G"
        SWAP_REASON="2x RAM (permite hibernacion)"
    elif [[ $RAM_GB -le 16 ]]; then
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
    [[ -z "$SUGGESTED_TIMEZONE" ]] && SUGGESTED_TIMEZONE="UTC"

    SUGGESTED_LOCALE="$(locale 2>/dev/null | awk -F= '/^LANG=/{print $2; exit}')"
    [[ -z "$SUGGESTED_LOCALE" ]] && SUGGESTED_LOCALE="en_US.UTF-8"

    if [[ -f /etc/default/keyboard ]]; then
        local kb_layout
        kb_layout="$(awk -F= '/^XKBLAYOUT=/{gsub(/"/,"",$2); print $2; exit}' /etc/default/keyboard 2>/dev/null || true)"
        if [[ -n "$kb_layout" ]]; then
            SUGGESTED_KEYBOARD="$kb_layout"
            SUGGESTED_KEYBOARD_SOURCE="system-file"
        fi
    fi

    if [[ "$SUGGESTED_KEYBOARD_SOURCE" != "system-file" ]]; then
        if [[ "$SUGGESTED_LOCALE" == es_* ]]; then
            SUGGESTED_KEYBOARD="es"
        else
            SUGGESTED_KEYBOARD="us"
        fi
        SUGGESTED_KEYBOARD_SOURCE="heuristica"
    fi

    SELECTED_EFI_SIZE="$(normalize_size_gib "${DRYRUN_EFI_SIZE:-$SUGGESTED_EFI}")"
    SELECTED_EFI_GB="$(size_gib_to_int "$SELECTED_EFI_SIZE")"
    if (( SELECTED_EFI_GB < 1 )); then
        SELECTED_EFI_SIZE="$SUGGESTED_EFI"
        SELECTED_EFI_GB="$(size_gib_to_int "$SELECTED_EFI_SIZE")"
    fi

    SELECTED_SYSTEM_SIZE="$(normalize_size_gib "${DRYRUN_SYSTEM_SIZE:-${SUGGESTED_SYSTEM_GB}G}")"
    SELECTED_SYSTEM_GB="$(size_gib_to_int "$SELECTED_SYSTEM_SIZE")"
    if (( SELECTED_SYSTEM_GB < 16 )); then
        SELECTED_SYSTEM_SIZE="${SUGGESTED_SYSTEM_GB}G"
        SELECTED_SYSTEM_GB="$SUGGESTED_SYSTEM_GB"
    fi

    SELECTED_SWAP_SIZE="$(normalize_size_gib "${DRYRUN_SWAP_SIZE:-$SUGGESTED_SWAP}")"
    if (( $(size_gib_to_int "$SELECTED_SWAP_SIZE") < 1 )); then
        SELECTED_SWAP_SIZE="$SUGGESTED_SWAP"
    fi

    SELECTED_CREATE_BACKUP="${DRYRUN_CREATE_BACKUP:-$CREATE_BACKUP}"
    SELECTED_CREATE_BACKUP="${SELECTED_CREATE_BACKUP^^}"
    if [[ "$SELECTED_CREATE_BACKUP" != "S" ]]; then
        SELECTED_CREATE_BACKUP="N"
    fi

    SELECTED_LOCALE="${DRYRUN_LOCALE:-$SUGGESTED_LOCALE}"
    SELECTED_TIMEZONE="${DRYRUN_TIMEZONE:-$SUGGESTED_TIMEZONE}"
    SELECTED_KEYBOARD="${DRYRUN_KEYBOARD:-$SUGGESTED_KEYBOARD}"
    SELECTED_HOSTNAME="${DRYRUN_HOSTNAME:-$SUGGESTED_HOSTNAME}"
    SELECTED_USERNAME="${DRYRUN_USERNAME:-$SUGGESTED_USERNAME}"

    SELECTED_USER_PASSWORD_SET="${DRYRUN_USER_PASSWORD_SET:-$SUGGESTED_USER_PASSWORD_SET}"
    SELECTED_USER_PASSWORD_SET="${SELECTED_USER_PASSWORD_SET^^}"
    [[ "$SELECTED_USER_PASSWORD_SET" != "S" ]] && SELECTED_USER_PASSWORD_SET="N"

    SELECTED_APT_ENABLE_NONFREE="${DRYRUN_APT_ENABLE_NONFREE:-$SUGGESTED_APT_ENABLE_NONFREE}"
    SELECTED_APT_ENABLE_NONFREE="${SELECTED_APT_ENABLE_NONFREE^^}"
    [[ "$SELECTED_APT_ENABLE_NONFREE" != "S" ]] && SELECTED_APT_ENABLE_NONFREE="N"

    SELECTED_APT_ENABLE_SECURITY="${DRYRUN_APT_ENABLE_SECURITY:-$SUGGESTED_APT_ENABLE_SECURITY}"
    SELECTED_APT_ENABLE_SECURITY="${SELECTED_APT_ENABLE_SECURITY^^}"
    [[ "$SELECTED_APT_ENABLE_SECURITY" != "S" ]] && SELECTED_APT_ENABLE_SECURITY="N"

    SELECTED_APT_ENABLE_UPDATES="${DRYRUN_APT_ENABLE_UPDATES:-$SUGGESTED_APT_ENABLE_UPDATES}"
    SELECTED_APT_ENABLE_UPDATES="${SELECTED_APT_ENABLE_UPDATES^^}"
    [[ "$SELECTED_APT_ENABLE_UPDATES" != "S" ]] && SELECTED_APT_ENABLE_UPDATES="N"

    SELECTED_APT_ENABLE_DEBSRC="${DRYRUN_APT_ENABLE_DEBSRC:-$SUGGESTED_APT_ENABLE_DEBSRC}"
    SELECTED_APT_ENABLE_DEBSRC="${SELECTED_APT_ENABLE_DEBSRC^^}"
    [[ "$SELECTED_APT_ENABLE_DEBSRC" != "S" ]] && SELECTED_APT_ENABLE_DEBSRC="N"

    SELECTED_APT_PROXY="${DRYRUN_APT_PROXY:-$SUGGESTED_APT_PROXY}"

    SELECTED_INSTALL_NONFREE_FIRMWARE="${DRYRUN_INSTALL_NONFREE_FIRMWARE:-$SUGGESTED_INSTALL_NONFREE_FIRMWARE}"
    SELECTED_INSTALL_NONFREE_FIRMWARE="${SELECTED_INSTALL_NONFREE_FIRMWARE^^}"
    [[ "$SELECTED_INSTALL_NONFREE_FIRMWARE" != "S" ]] && SELECTED_INSTALL_NONFREE_FIRMWARE="N"

    SELECTED_ENABLE_POPCON="${DRYRUN_ENABLE_POPCON:-$SUGGESTED_ENABLE_POPCON}"
    SELECTED_ENABLE_POPCON="${SELECTED_ENABLE_POPCON^^}"
    [[ "$SELECTED_ENABLE_POPCON" != "S" ]] && SELECTED_ENABLE_POPCON="N"

    SELECTED_SOFTWARE_INSTALL_MODE="${DRYRUN_SOFTWARE_INSTALL_MODE:-$SUGGESTED_SOFTWARE_INSTALL_MODE}"
    SELECTED_SOFTWARE_INSTALL_MODE="${SELECTED_SOFTWARE_INSTALL_MODE^^}"
    case "$SELECTED_SOFTWARE_INSTALL_MODE" in
        AUTO|INTERACTIVE|POSTBOOT) : ;;
        *) SELECTED_SOFTWARE_INSTALL_MODE="$SUGGESTED_SOFTWARE_INSTALL_MODE" ;;
    esac

    SELECTED_INSTALL_SSH_IN_BASE="${DRYRUN_INSTALL_SSH_IN_BASE:-$SUGGESTED_INSTALL_SSH_IN_BASE}"
    SELECTED_INSTALL_SSH_IN_BASE="${SELECTED_INSTALL_SSH_IN_BASE^^}"
    [[ "$SELECTED_INSTALL_SSH_IN_BASE" != "S" ]] && SELECTED_INSTALL_SSH_IN_BASE="N"

    SELECTED_INSTALL_TASKSEL_NOW="${DRYRUN_INSTALL_TASKSEL_NOW:-$SUGGESTED_INSTALL_TASKSEL_NOW}"
    SELECTED_INSTALL_TASKSEL_NOW="${SELECTED_INSTALL_TASKSEL_NOW^^}"
    [[ "$SELECTED_INSTALL_TASKSEL_NOW" != "S" ]] && SELECTED_INSTALL_TASKSEL_NOW="N"

    EFFECTIVE_BACKUP_GB=$((DISK_SIZE_GB - SELECTED_SYSTEM_GB - SELECTED_EFI_GB))
    if (( EFFECTIVE_BACKUP_GB <= 0 )); then
        EFFECTIVE_BACKUP_GB=0
        SELECTED_CREATE_BACKUP="N"
    fi
}

print_defaults() {
    detect_suggested_disk || return 1
    calculate_recommendations || return 1

    printf 'DRYRUN_DEFAULT_DISK=%s\n' "$DISK"
    printf 'DRYRUN_DEFAULT_EFI=%s\n' "$SUGGESTED_EFI"
    printf 'DRYRUN_DEFAULT_SYSTEM=%sG\n' "$SUGGESTED_SYSTEM_GB"
    printf 'DRYRUN_DEFAULT_BACKUP=%sG\n' "$SUGGESTED_BACKUP_GB"
    printf 'DRYRUN_DEFAULT_CREATE_BACKUP=%s\n' "$CREATE_BACKUP"
    printf 'DRYRUN_DEFAULT_SWAP=%s\n' "$SUGGESTED_SWAP"
    printf 'DRYRUN_DEFAULT_LOCALE=%s\n' "$SUGGESTED_LOCALE"
    printf 'DRYRUN_DEFAULT_TIMEZONE=%s\n' "$SUGGESTED_TIMEZONE"
    printf 'DRYRUN_DEFAULT_HOSTNAME=%s\n' "$SUGGESTED_HOSTNAME"
    printf 'DRYRUN_DEFAULT_KEYBOARD=%s\n' "$SUGGESTED_KEYBOARD"
    printf 'DRYRUN_DEFAULT_KEYBOARD_SOURCE=%s\n' "$SUGGESTED_KEYBOARD_SOURCE"
}

analyze_memory() {
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

analyze_cpu() {
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

detect_suggested_disk() {
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

    if [[ -z "$DISK" ]]; then
        IFS='|' read -r candidate_name candidate_size <<< "${candidates[0]}"
        DISK="/dev/${candidate_name}"
        best_size=$candidate_size
    fi

    DISK_SIZE_GB=$best_size
    ok "disco sugerido para simulacion: ${DISK} (${DISK_SIZE_GB}GB)"
}

analyze_and_suggest() {
    step "8/9 - Calculo de sugerencias como opcion 1"
    calculate_recommendations || return 1

    printf "[dry-run] disco objetivo sugerido: %s\n" "$DISK"
    printf "[dry-run] capacidad usada para calculo: %sGB\n" "$DISK_SIZE_GB"
    printf "[dry-run] RAM usada para calculo: %sGB\n" "$RAM_GB"
    printf "[dry-run] Sugerido --> EFI: %s\n" "$SUGGESTED_EFI"
    printf "[dry-run] Elegido  --> EFI: %s\n" "$SELECTED_EFI_SIZE"

    printf "[dry-run] Sugerido --> Sistema: %sG (%s%% del disco)\n" "$SUGGESTED_SYSTEM_GB" "$SUGGESTED_SYSTEM_PCT"
    printf "[dry-run] Elegido  --> Sistema: %s\n" "$SELECTED_SYSTEM_SIZE"

    if [[ "$CREATE_BACKUP" == "S" ]]; then
        printf "[dry-run] Sugerido --> Backup: %sG\n" "$SUGGESTED_BACKUP_GB"
    else
        printf "[dry-run] Sugerido --> Backup: no crear (sin espacio suficiente)\n"
    fi

    if [[ "$SELECTED_CREATE_BACKUP" == "S" ]]; then
        printf "[dry-run] Elegido  --> Backup: %sG\n" "$EFFECTIVE_BACKUP_GB"
    else
        printf "[dry-run] Elegido  --> Backup: no crear\n"
    fi

    printf "[dry-run] Sugerido --> Swapfile: %s (%s)\n" "$SUGGESTED_SWAP" "$SWAP_REASON"
    printf "[dry-run] Elegido  --> Swapfile: %s\n" "$SELECTED_SWAP_SIZE"

    printf "[dry-run] Sugerido --> Hostname: %s\n" "$SUGGESTED_HOSTNAME"
    printf "[dry-run] Elegido  --> Hostname: %s\n" "$SELECTED_HOSTNAME"
    printf "[dry-run] Sugerido --> Usuario: %s\n" "$SUGGESTED_USERNAME"
    printf "[dry-run] Elegido  --> Usuario: %s\n" "$SELECTED_USERNAME"
    printf "[dry-run] Sugerido --> Password usuario definida: %s\n" "$SUGGESTED_USER_PASSWORD_SET"
    printf "[dry-run] Elegido  --> Password usuario definida: %s\n" "$SELECTED_USER_PASSWORD_SET"

    printf "[dry-run] Sugerido --> Timezone: %s\n" "$SUGGESTED_TIMEZONE"
    printf "[dry-run] Elegido  --> Timezone: %s\n" "$SELECTED_TIMEZONE"

    printf "[dry-run] Sugerido --> Locale: %s\n" "$SUGGESTED_LOCALE"
    printf "[dry-run] Elegido  --> Locale: %s\n" "$SELECTED_LOCALE"
    printf "[dry-run] Sugerido --> Teclado: %s\n" "$SUGGESTED_KEYBOARD"
    printf "[dry-run] Elegido  --> Teclado: %s\n" "$SELECTED_KEYBOARD"

    printf "[dry-run] Sugerido --> APT non-free: %s\n" "$SUGGESTED_APT_ENABLE_NONFREE"
    printf "[dry-run] Elegido  --> APT non-free: %s\n" "$SELECTED_APT_ENABLE_NONFREE"
    printf "[dry-run] Sugerido --> APT security: %s\n" "$SUGGESTED_APT_ENABLE_SECURITY"
    printf "[dry-run] Elegido  --> APT security: %s\n" "$SELECTED_APT_ENABLE_SECURITY"
    printf "[dry-run] Sugerido --> APT updates: %s\n" "$SUGGESTED_APT_ENABLE_UPDATES"
    printf "[dry-run] Elegido  --> APT updates: %s\n" "$SELECTED_APT_ENABLE_UPDATES"
    printf "[dry-run] Sugerido --> APT deb-src: %s\n" "$SUGGESTED_APT_ENABLE_DEBSRC"
    printf "[dry-run] Elegido  --> APT deb-src: %s\n" "$SELECTED_APT_ENABLE_DEBSRC"
    printf "[dry-run] Sugerido --> APT proxy: %s\n" "${SUGGESTED_APT_PROXY:-<sin proxy>}"
    printf "[dry-run] Elegido  --> APT proxy: %s\n" "${SELECTED_APT_PROXY:-<sin proxy>}"
    printf "[dry-run] Sugerido --> Firmware no libre: %s\n" "$SUGGESTED_INSTALL_NONFREE_FIRMWARE"
    printf "[dry-run] Elegido  --> Firmware no libre: %s\n" "$SELECTED_INSTALL_NONFREE_FIRMWARE"
    printf "[dry-run] Sugerido --> popularity-contest: %s\n" "$SUGGESTED_ENABLE_POPCON"
    printf "[dry-run] Elegido  --> popularity-contest: %s\n" "$SELECTED_ENABLE_POPCON"
    printf "[dry-run] Sugerido --> Modo software: %s\n" "$SUGGESTED_SOFTWARE_INSTALL_MODE"
    printf "[dry-run] Elegido  --> Modo software: %s\n" "$SELECTED_SOFTWARE_INSTALL_MODE"
    printf "[dry-run] Sugerido --> SSH en base: %s\n" "$SUGGESTED_INSTALL_SSH_IN_BASE"
    printf "[dry-run] Elegido  --> SSH en base: %s\n" "$SELECTED_INSTALL_SSH_IN_BASE"
    printf "[dry-run] Sugerido --> tasksel ahora: %s\n" "$SUGGESTED_INSTALL_TASKSEL_NOW"
    printf "[dry-run] Elegido  --> tasksel ahora: %s\n" "$SELECTED_INSTALL_TASKSEL_NOW"

    ok "recomendaciones calculadas con la misma base de opcion 1"
}

print_header() {
    printf "[dry-run] === DEBIAN BTRFS INSTALLER - DRY-RUN ANALYSIS ===\n"
    printf "[dry-run] repo: %s\n" "$REPO_ROOT"
    printf "[dry-run] objetivo: validar sistema sin tocar disco\n"
    printf "[dry-run] fecha: %s\n" "$(date '+%Y-%m-%d %H:%M:%S')"
    printf "\n"
}

check_environment() {
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

detect_runtime_context() {
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

verify_disk_space() {
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

detect_storage() {
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

analyze_network() {
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
    printf "[dry-run] ruta por defecto: %s\n" "$NETWORK_DEFAULT_ROUTE"
    printf "[dry-run] DNS funcional: %s\n" "$NETWORK_DNS_OK"
    printf "[dry-run] requisito actual: salida a Internet preferentemente por Ethernet\n"

    if [[ "$NETWORK_DEFAULT_ROUTE" == "S" ]]; then
        ok "red operativa para continuar"
    elif [[ -n "$NETWORK_ETH_IFACE" ]]; then
        warn "hay interfaz ethernet, pero sin conectividad valida"
    elif [[ -n "$NETWORK_WIFI_IFACE" ]]; then
        warn "hay Wi-Fi detectada, pero este flujo queda como requisito del entorno live"
    else
        warn "sin conectividad lista; la instalacion debe asumir Ethernet/Internet como requisito"
    fi
}

print_preview_plan() {
    step "9/9 - Simulacion del plan de instalacion"

    printf "\n[dry-run] === PLAN DE PARTICIONES ===\n\n"
    printf "[dry-run] EFI:\n"
    printf "[dry-run]   Sugerido --> %s   FAT32   /boot/efi\n" "$SUGGESTED_EFI"
    printf "[dry-run]   Elegido  --> %s   FAT32   /boot/efi\n" "$SELECTED_EFI_SIZE"

    printf "\n[dry-run] SISTEMA (BTRFS raiz):\n"
    printf "[dry-run]   Sugerido --> %sG   BTRFS   /\n" "$SUGGESTED_SYSTEM_GB"
    printf "[dry-run]   Elegido  --> %s   BTRFS   /\n" "$SELECTED_SYSTEM_SIZE"

    printf "\n[dry-run] BACKUP (BTRFS opcional):\n"
    if [[ "$CREATE_BACKUP" == "S" ]]; then
        printf "[dry-run]   Sugerido --> %sG   BTRFS   (desmontada)\n" "$SUGGESTED_BACKUP_GB"
    else
        printf "[dry-run]   Sugerido --> omitida por espacio\n"
    fi
    if [[ "$SELECTED_CREATE_BACKUP" == "S" ]]; then
        printf "[dry-run]   Elegido  --> %sG   BTRFS   (desmontada)\n" "$EFFECTIVE_BACKUP_GB"
    else
        printf "[dry-run]   Elegido  --> omitida\n"
    fi

    printf "\n[dry-run] === SWAP ===\n"
    printf "[dry-run]   Sugerido --> %s   (en subvol @swap)\n" "$SUGGESTED_SWAP"
    printf "[dry-run]   Elegido  --> %s   (en subvol @swap)\n" "$SELECTED_SWAP_SIZE"

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

main() {
    print_header
    analyze_memory
    printf "\n"
    analyze_cpu
    printf "\n"
    check_environment
    printf "\n"
    detect_runtime_context
    printf "\n"
    verify_disk_space
    printf "\n"
    detect_storage
    printf "\n"
    analyze_network
    printf "\n"
    analyze_and_suggest
    printf "\n"
    print_preview_plan

    printf "\n[dry-run] ==========================================\n"
    printf "[dry-run] RESULTADO: Analisis completado exitosamente\n"
    printf "[dry-run] ==========================================\n"
}

if [[ "${1:-}" == "--defaults" ]]; then
    print_defaults
    exit 0
fi

main
exit 0
