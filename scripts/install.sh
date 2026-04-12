#!/bin/bash
set -euo pipefail

# Opcion 1 (v008) - Instalacion real
# Motor de instalacion: recibe las decisiones ya tomadas por 008
# via variables de entorno DRYRUN_* y ejecuta la instalacion real.
#
# La seleccion de disco y password de usuario se hacen aqui mismo
# en terminal limpia, igual que dry_run.sh hace sus preguntas.
#
# Protocolo de entrada (variables de entorno pasadas por 008):
#   DRYRUN_LOCALE, DRYRUN_KEYBOARD, DRYRUN_TIMEZONE
#   DRYRUN_HOSTNAME, DRYRUN_USERNAME
#   DRYRUN_EFI_SIZE, DRYRUN_SYSTEM_SIZE, DRYRUN_SWAP_SIZE, DRYRUN_CREATE_BACKUP
#   DRYRUN_APT_ENABLE_NONFREE, DRYRUN_APT_ENABLE_SECURITY
#   DRYRUN_APT_ENABLE_UPDATES, DRYRUN_APT_ENABLE_DEBSRC, DRYRUN_APT_PROXY
#   DRYRUN_INSTALL_NONFREE_FIRMWARE, DRYRUN_ENABLE_POPCON
#   DRYRUN_SOFTWARE_INSTALL_MODE, DRYRUN_INSTALL_SSH_IN_BASE
#   DRYRUN_INSTALL_TASKSEL_NOW

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

LOG_FILE="/tmp/debian-install-$(date +%Y%m%d-%H%M%S).log"
DEBIAN_RELEASE="trixie"
DEBIAN_MIRROR="http://deb.debian.org/debian"
BTRFS_OPTS="defaults,noatime,space_cache=v2,compress=zstd:1"

# ============================================
# ESTADO RUNTIME
# ============================================

DISK=""
DISK_SIZE_GB=0
RAM_GB=0
EFI_PART=""
SYSTEM_PART=""
BACKUP_PART=""
EFI_UUID=""
SYSTEM_UUID=""
BACKUP_UUID=""
MOUNTED_TARGET="false"
MOUNTED_CHROOT_BIND="false"
GRUB_BTRFS_INSTALLED="N"

SUGGESTED_EFI="1G"
SUGGESTED_SYSTEM_GB=0
SUGGESTED_SYSTEM_PCT=0
SUGGESTED_BACKUP_GB=0
SUGGESTED_SWAP=""
SWAP_REASON=""
SUGGESTED_HOSTNAME="debian-pc"
SUGGESTED_USERNAME="usuario"

# Valores finales que se van a usar en la instalacion
EFI_SIZE=""
SYSTEM_SIZE=""
SWAP_SIZE=""
CREATE_BACKUP="S"
LOCALE=""
KEYBOARD=""
TIMEZONE=""
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

step() {
    local msg="[install][step] $*"
    printf "\n%s\n" "$msg" | tee -a "$LOG_FILE"
}

ok() {
    local msg="[install][ok] $*"
    printf "%s\n" "$msg" | tee -a "$LOG_FILE"
}

warn() {
    local msg="[install][warn] $*"
    printf "%s\n" "$msg" | tee -a "$LOG_FILE"
}

fail() {
    local msg="[install][error] $*"
    printf "%s\n" "$msg" | tee -a "$LOG_FILE" >&2
    exit 1
}

info() {
    local msg="[install][info] $*"
    printf "%s\n" "$msg" | tee -a "$LOG_FILE"
}

have_cmd() {
    command -v "$1" >/dev/null 2>&1
}

# ============================================
# UTILIDADES
# ============================================

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
    [[ -z "$DISK" ]] && return 0

    while IFS= read -r part; do
        [[ -z "$part" ]] && continue
        swapoff "$part" &>/dev/null || true
        umount  "$part" &>/dev/null || true
    done < <(lsblk -ln -o NAME,TYPE "$DISK" 2>/dev/null | awk '$2=="part"{print "/dev/"$1}')

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

    DISK_SIZE_GB="$(lsblk -bdn -o SIZE "$DISK" 2>/dev/null | awk '{print int($1/1024/1024/1024)}')"
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
    (( SUGGESTED_BACKUP_GB <= 0 )) && SUGGESTED_BACKUP_GB=0

    if [[ $RAM_GB -le 2 ]]; then
        SUGGESTED_SWAP="${RAM_GB}G"
        SWAP_REASON="igual a RAM"
    elif [[ $RAM_GB -le 8 ]]; then
        SUGGESTED_SWAP="$((RAM_GB * 2))G"
        SWAP_REASON="2x RAM"
    elif [[ $RAM_GB -le 16 ]]; then
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

    ok "disco seleccionado: $DISK"
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
    system_num="$(echo "$SYSTEM_SIZE" | sed 's/[^0-9]//g')"
    backup_calc=$((DISK_SIZE_GB - system_num - 1))

    printf "\n[install] === RESUMEN ===\n\n"
    printf "[install] disco    --> %s (%sGB)\n" "$DISK" "$DISK_SIZE_GB"
    printf "\n[install] PARTICIONES:\n"
    printf "[install]   EFI    --> %s   FAT32   /boot/efi\n" "$EFI_SIZE"
    printf "[install]   SISTEMA--> %s   BTRFS   /\n" "$SYSTEM_SIZE"
    if [[ "$CREATE_BACKUP" == "S" ]]; then
        printf "[install]   BACKUP --> %sG   BTRFS   (desmontada)\n" "$backup_calc"
    else
        printf "[install]   BACKUP --> no crear\n"
    fi
    printf "[install]   SWAP   --> %s   (swapfile en @swap)\n" "$SWAP_SIZE"
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
    printf "\n[install][warn] TODOS LOS DATOS EN %s SERAN ELIMINADOS.\n\n" "$DISK"

    local confirm
    read -r -p "[install] Escribe exactamente '$DISK' para confirmar: " confirm < /dev/tty
    if [[ "$confirm" != "$DISK" ]]; then
        fail "Confirmacion incorrecta. Instalacion cancelada."
    fi
    ok "confirmacion aceptada"
}

# ============================================
# 6 - PARTICIONADO
# ============================================

partition_disk() {
    step "6/15 - Particionando $DISK"

    unmount_disk_partitions

    local P=""
    [[ "$DISK" =~ nvme ]] && P="p"

    EFI_PART="${DISK}${P}1"
    SYSTEM_PART="${DISK}${P}2"
    BACKUP_PART="${DISK}${P}3"

    sgdisk -Z "$DISK" &>/dev/null || true
    sgdisk -og "$DISK" || fail "Error creando GPT"
    sgdisk -n "1::+${EFI_SIZE}"    -t 1:ef00 -c 1:"EFI"     "$DISK" || fail "Error particion EFI"
    sgdisk -n "2::+${SYSTEM_SIZE}" -t 2:8300 -c 2:"SISTEMA"  "$DISK" || fail "Error particion Sistema"

    if [[ "$CREATE_BACKUP" == "S" ]]; then
        sgdisk -n 3:: -t 3:8300 -c 3:"BACKUP" "$DISK" || fail "Error particion Backup"
    fi

    partprobe "$DISK" &>/dev/null || true
    sleep 2
    ok "disco particionado"
}

# ============================================
# 7 - FORMATEO
# ============================================

format_partitions() {
    step "7/15 - Formateando particiones"

    unmount_disk_partitions
    ensure_partition_unmounted "$EFI_PART"
    ensure_partition_unmounted "$SYSTEM_PART"
    [[ "$CREATE_BACKUP" == "S" ]] && ensure_partition_unmounted "$BACKUP_PART"

    mkfs.fat -F32 -n EFI    "$EFI_PART"    || fail "Error formateando EFI"
    mkfs.btrfs -f -L DEBIAN "$SYSTEM_PART" || fail "Error formateando Sistema"

    if [[ "$CREATE_BACKUP" == "S" ]]; then
        mkfs.btrfs -f -L BACKUP "$BACKUP_PART" || fail "Error formateando Backup"
        BACKUP_UUID="$(blkid -s UUID -o value "$BACKUP_PART")"
    fi

    EFI_UUID="$(blkid -s UUID -o value "$EFI_PART")"
    SYSTEM_UUID="$(blkid -s UUID -o value "$SYSTEM_PART")"
    ok "particiones formateadas"
}

# ============================================
# 8 - SUBVOLUMENES BTRFS
# ============================================

create_subvolumes() {
    step "8/15 - Creando subvolumenes btrfs"

    mount "$SYSTEM_PART" /mnt || fail "Error montando sistema"

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

    mount -o "$BTRFS_OPTS,subvol=@" "$SYSTEM_PART" /mnt

    mkdir -p /mnt/{home,boot/efi,.snapshots,var/{cache,log,tmp,swap}}

    mount -o "$BTRFS_OPTS,subvol=@home"      "$SYSTEM_PART" /mnt/home
    mount -o "$BTRFS_OPTS,subvol=@snapshots" "$SYSTEM_PART" /mnt/.snapshots
    mount -o "$BTRFS_OPTS,subvol=@cache"     "$SYSTEM_PART" /mnt/var/cache
    mount -o "$BTRFS_OPTS,subvol=@log"       "$SYSTEM_PART" /mnt/var/log
    mount -o "$BTRFS_OPTS,subvol=@tmp"       "$SYSTEM_PART" /mnt/var/tmp
    mount -o "defaults,noatime,subvol=@swap" "$SYSTEM_PART" /mnt/var/swap

    mount "$EFI_PART" /mnt/boot/efi
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

    if [[ "$CREATE_BACKUP" == "S" ]]; then
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
    step "14b/15 - Creando swapfile ($SWAP_SIZE)"

    local swap_gb="${SWAP_SIZE%G}"
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

    printf "[install] disco    : %s\n" "$DISK"
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

    if [[ "$CREATE_BACKUP" == "S" ]]; then
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
    printf "\n[install] log completo: %s\n" "$LOG_FILE"
    printf "\n"
}

# ============================================
# MAIN
# ============================================

main() {
    printf "[install] === DEBIAN BTRFS INSTALLER - OPCION 1 ===\n"
    printf "[install] fecha: %s\n" "$(date '+%Y-%m-%d %H:%M:%S')"
    printf "[install] log  : %s\n\n" "$LOG_FILE"

    # Tomar los valores pasados por 008
    EFI_SIZE="$(normalize_size_gib "${DRYRUN_EFI_SIZE:-1G}")"
    SYSTEM_SIZE="$(normalize_size_gib "${DRYRUN_SYSTEM_SIZE:-80G}")"
    SWAP_SIZE="$(normalize_size_gib "${DRYRUN_SWAP_SIZE:-8G}")"
    CREATE_BACKUP="${DRYRUN_CREATE_BACKUP:-S}"
    CREATE_BACKUP="${CREATE_BACKUP^^}"
    [[ "$CREATE_BACKUP" != "S" ]] && CREATE_BACKUP="N"

    LOCALE="${DRYRUN_LOCALE:-es_AR.UTF-8}"
    KEYBOARD="${DRYRUN_KEYBOARD:-latam}"
    TIMEZONE="${DRYRUN_TIMEZONE:-America/Argentina/Buenos_Aires}"
    HOSTNAME_VALUE="${DRYRUN_HOSTNAME:-debian-pc}"
    USERNAME="${DRYRUN_USERNAME:-usuario}"

    APT_ENABLE_NONFREE="${DRYRUN_APT_ENABLE_NONFREE:-S}"; APT_ENABLE_NONFREE="${APT_ENABLE_NONFREE^^}"
    APT_ENABLE_SECURITY="${DRYRUN_APT_ENABLE_SECURITY:-S}"; APT_ENABLE_SECURITY="${APT_ENABLE_SECURITY^^}"
    APT_ENABLE_UPDATES="${DRYRUN_APT_ENABLE_UPDATES:-S}"; APT_ENABLE_UPDATES="${APT_ENABLE_UPDATES^^}"
    APT_ENABLE_DEBSRC="${DRYRUN_APT_ENABLE_DEBSRC:-N}"; APT_ENABLE_DEBSRC="${APT_ENABLE_DEBSRC^^}"
    APT_PROXY="${DRYRUN_APT_PROXY:-}"
    INSTALL_NONFREE_FIRMWARE="${DRYRUN_INSTALL_NONFREE_FIRMWARE:-S}"; INSTALL_NONFREE_FIRMWARE="${INSTALL_NONFREE_FIRMWARE^^}"
    ENABLE_POPCON="${DRYRUN_ENABLE_POPCON:-N}"; ENABLE_POPCON="${ENABLE_POPCON^^}"
    SOFTWARE_INSTALL_MODE="${DRYRUN_SOFTWARE_INSTALL_MODE:-POSTBOOT}"; SOFTWARE_INSTALL_MODE="${SOFTWARE_INSTALL_MODE^^}"
    INSTALL_SSH_IN_BASE="${DRYRUN_INSTALL_SSH_IN_BASE:-S}"; INSTALL_SSH_IN_BASE="${INSTALL_SSH_IN_BASE^^}"
    INSTALL_TASKSEL_NOW="${DRYRUN_INSTALL_TASKSEL_NOW:-N}"; INSTALL_TASKSEL_NOW="${INSTALL_TASKSEL_NOW^^}"

    # Pasos interactivos que no se pueden delegar a 008
    check_requirements
    select_disk
    calculate_suggestions
    ask_password
    print_install_summary

    # Pipeline de instalacion
    partition_disk
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
    final_cleanup
    show_final_summary

    printf "[install] Presiona ENTER para reiniciar el sistema...\n"
    read -r _ < /dev/tty || true
    reboot
}

main
exit 0
