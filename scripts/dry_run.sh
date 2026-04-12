#!/bin/bash
set -euo pipefail

# Opcion 2 (v008) - Modo prueba (dry-run)
# Flujo ampliado: validaciones, deteccion y preview sin cambios destructivos.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

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

analyze_memory() {
    step "1/7 - Analisis de memoria\n"

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
    step "2/7 - Analisis de CPU\n"

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

print_header() {
    printf "[dry-run] === DEBIAN BTRFS INSTALLER - DRY-RUN ANALYSIS ===\n"
    printf "[dry-run] repo: %s\n" "$REPO_ROOT"
    printf "[dry-run] objetivo: validar sistema sin tocar disco\n"
    printf "[dry-run] fecha: %s\n" "$(date '+%Y-%m-%d %H:%M:%S')"
    printf "\n"
}

check_environment() {
    step "3/7 - Validaciones de entorno"

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
    step "4/7 - Contexto de ejecucion"

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
    step "5/7 - Verificacion de espacio en disco"

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
    step "6/7 - Deteccion de hardware y particiones"

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
}

print_preview_plan() {
    step "7/7 - Preview de acciones (simuladas)"

    cat <<'EOF'
[dry-run] que se haria en instalacion real:
[dry-run]   1) confirmar disco objetivo y esquema GPT/UEFI.
[dry-run]   2) crear/validar particiones EFI + raiz btrfs (+ opcional recovery).
[dry-run]   3) crear subvolumenes estandar: @ y @home.
[dry-run]   4) montar con opciones recomendadas y generar fstab.
[dry-run]   5) instalar sistema base + grub + herramientas snapshot.
[dry-run]   6) validar arranque y preparar rollback.
EOF

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
    print_preview_plan

    printf "\n[dry-run] ==========================================\n"
    printf "[dry-run] RESULTADO: Analisis completado exitosamente\n"
    printf "[dry-run] ==========================================\n"
}

main
exit 0
