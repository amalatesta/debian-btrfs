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
CREATE_BACKUP="S"
SELECTED_EFI_SIZE=""
SELECTED_EFI_GB=1
SELECTED_SYSTEM_SIZE=""
SELECTED_SYSTEM_GB=0
SELECTED_CREATE_BACKUP="S"
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
    raw="${raw%G}"
    printf '%s\n' "$raw"
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

    SELECTED_CREATE_BACKUP="${DRYRUN_CREATE_BACKUP:-$CREATE_BACKUP}"
    SELECTED_CREATE_BACKUP="${SELECTED_CREATE_BACKUP^^}"
    if [[ "$SELECTED_CREATE_BACKUP" != "S" ]]; then
        SELECTED_CREATE_BACKUP="N"
    fi

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
}

analyze_memory() {
    step "1/8 - Analisis de memoria"

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
    step "2/8 - Analisis de CPU"

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
    step "7/8 - Calculo de sugerencias como opcion 1"
    calculate_recommendations || return 1

    printf "[dry-run] disco objetivo sugerido: %s\n" "$DISK"
    printf "[dry-run] capacidad usada para calculo: %sGB\n" "$DISK_SIZE_GB"
    printf "[dry-run] RAM usada para calculo: %sGB\n" "$RAM_GB"
    printf "[dry-run] --- sugerido por analisis ---\n"
    printf "[dry-run] EFI sugerido: %s\n" "$SUGGESTED_EFI"
    printf "[dry-run] Sistema sugerido: %sG (%s%% del disco)\n" "$SUGGESTED_SYSTEM_GB" "$SUGGESTED_SYSTEM_PCT"
    if [[ "$CREATE_BACKUP" == "S" ]]; then
        printf "[dry-run] Backup sugerido: %sG\n" "$SUGGESTED_BACKUP_GB"
    else
        printf "[dry-run] Backup sugerido: no crear (sin espacio suficiente)\n"
    fi
    printf "[dry-run] Swapfile sugerido: %s (%s)\n" "$SUGGESTED_SWAP" "$SWAP_REASON"
    printf "[dry-run] Hostname sugerido: %s\n" "$SUGGESTED_HOSTNAME"
    printf "[dry-run] Timezone sugerido: %s\n" "$SUGGESTED_TIMEZONE"
    printf "[dry-run] Locale sugerido: %s\n" "$SUGGESTED_LOCALE"
    printf "[dry-run] --- configuracion final elegida ---\n"
    printf "[dry-run] EFI final: %s\n" "$SELECTED_EFI_SIZE"
    printf "[dry-run] Sistema final: %s\n" "$SELECTED_SYSTEM_SIZE"
    if [[ "$SELECTED_CREATE_BACKUP" == "S" ]]; then
        printf "[dry-run] Backup final: %sG\n" "$EFFECTIVE_BACKUP_GB"
    else
        printf "[dry-run] Backup final: no crear\n"
    fi
    printf "[dry-run] Swapfile final: %s\n" "$SUGGESTED_SWAP"
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
    step "3/8 - Validaciones de entorno"

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
    step "4/8 - Contexto de ejecucion"

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
    step "5/8 - Verificacion de espacio en disco"

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
    step "6/8 - Deteccion de hardware y particiones"

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

print_preview_plan() {
    step "8/8 - Resultado simulado si aceptaras los recomendados"

    cat <<'EOF'
[dry-run] que se haria en instalacion real:
[dry-run]   1) confirmar disco objetivo y esquema GPT/UEFI.
[dry-run]   2) crear/validar particiones EFI + raiz btrfs (+ opcional recovery).
[dry-run]   3) crear subvolumenes estandar: @ y @home.
[dry-run]   4) montar con opciones recomendadas y generar fstab.
[dry-run]   5) instalar sistema base + grub + herramientas snapshot.
[dry-run]   6) validar arranque y preparar rollback.
EOF

    printf "\n[dry-run] simulacion de resultado esperado (informativo):\n"
    printf "[dry-run]   disco elegido por defecto: %s\n" "$DISK"
    printf "[dry-run]   --- sugerido ---\n"
    printf "[dry-run]   particion 1: EFI       %s   FAT32   /boot/efi\n" "$SUGGESTED_EFI"
    printf "[dry-run]   particion 2: SISTEMA   %sG   BTRFS   /\n" "$SUGGESTED_SYSTEM_GB"
    if [[ "$CREATE_BACKUP" == "S" ]]; then
        printf "[dry-run]   particion 3: BACKUP    %sG   BTRFS   (desmontada)\n" "$SUGGESTED_BACKUP_GB"
    else
        printf "[dry-run]   particion 3: BACKUP    omitida por espacio disponible\n"
    fi
    printf "[dry-run]   --- final (segun respuestas) ---\n"
    printf "[dry-run]   particion 1: EFI       %s   FAT32   /boot/efi\n" "$SELECTED_EFI_SIZE"
    printf "[dry-run]   particion 2: SISTEMA   %s   BTRFS   /\n" "$SELECTED_SYSTEM_SIZE"
    if [[ "$SELECTED_CREATE_BACKUP" == "S" ]]; then
        printf "[dry-run]   particion 3: BACKUP    %sG   BTRFS   (desmontada)\n" "$EFFECTIVE_BACKUP_GB"
    else
        printf "[dry-run]   particion 3: BACKUP    omitida por espacio disponible\n"
    fi

    cat <<'EOF'
[dry-run]
[dry-run]   subvolumenes propuestos dentro de BTRFS:
[dry-run]     - @           -> raiz del sistema
[dry-run]     - @home       -> datos de usuario
[dry-run]     - @snapshots  -> base sugerida para snapshots
[dry-run]     - @swap       -> contenedor del swapfile
[dry-run]
[dry-run]   montaje esperado:
[dry-run]     - /           -> subvol=@
[dry-run]     - /home       -> subvol=@home
[dry-run]     - /.snapshots -> subvol=@snapshots
EOF

    printf "[dry-run]     - /var/swap   -> subvol=@swap (swapfile %s)\n" "$SUGGESTED_SWAP"

    cat <<'EOF'
[dry-run] comandos de referencia (no ejecutados):
[dry-run]   - lsblk -f
[dry-run]   - blkid
[dry-run]   - btrfs subvolume list /
[dry-run]   - mount | grep btrfs
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
