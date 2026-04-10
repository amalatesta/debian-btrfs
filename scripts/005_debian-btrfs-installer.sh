#!/bin/bash
#
# ============================================
# DEBIAN BTRFS INSTALLER
# ============================================
#
# Instalador automático de Debian 13 (Trixie) con btrfs y grub-btrfs
#
# Versión: 5.0
# Autor: Para amalatesta
# Repositorio: https://github.com/amalatesta/debian-btrfs
# Fecha: 2026-04-09
#
# ============================================
# OBJETIVO
# ============================================
#
# Este script automatiza la instalación de Debian con un sistema de archivos
# btrfs optimizado para snapshots y backups, dejando el sistema preparado
# para configurar snapper (snapshots locales) y btrbk (backups incrementales).
#
# El script:
#   - Particiona el disco con esquema EFI + Sistema + Backup
#   - Crea subvolúmenes btrfs optimizados para snapshots
#   - Instala Debian base con kernel y GRUB
#   - Configura grub-btrfs para bootear desde snapshots
#   - Deja el sistema listo para usar (terminal + SSH)
#   - Permite elegir cómo resolver preguntas no críticas (con sugerencias)
#   - Permite definir si tasksel/software va en instalación o post-boot
#
# NO instala entorno de escritorio (solo terminal).
# NO instala snapper/btrbk (se configuran después).
#
# DECISIÓN DE ALCANCE (IMPORTANTE):
# - Este instalador resuelve la base estructural del sistema (disco, subvolúmenes,
#   bootloader, fstab, red base y paquetes esenciales).
# - Snapper, btrbk y escritorio quedan fuera de este script a propósito, para poder
#   instalar/configurar esas capas después de forma independiente y flexible.
# - Cambios estructurales como usar @ y @home sí se hacen aquí, porque impactan
#   directamente en el filesystem y el arranque.
#
# PERFIL DE USO (GENÉRICO)
# - Este script está diseñado para funcionar igual en VM y notebook/PC física.
# - No tiene perfiles hardcodeados por tipo de máquina.
# - Primero analiza hardware y entorno (disco, RAM, UEFI, locale/timezone) y luego
#   propone sugerencias que siempre podés aceptar o modificar.
#
# OPCIONES DE SOFTWARE (NO CRÍTICAS)
# - AUTO: instala durante la instalación base (sin menú) las tareas seleccionadas.
# - INTERACTIVE: abre tasksel para que elijas manualmente.
# - POSTBOOT: deja tasksel/software para después del primer arranque.
#
# Recomendación base genérica:
# - Mantener foco en capa estructural (filesystem + boot + red).
# - Dejar software opcional para post-boot si querés máxima flexibilidad.
#
# ============================================
# REQUISITOS
# ============================================
#
# Hardware:
#   - PC/Laptop con soporte UEFI
#   - Disco con al menos 64GB (recomendado 128GB+)
#   - 2GB RAM mínimo (recomendado 4GB+)
#   - Conexión a internet (cable recomendado)
#
# Software:
#   - USB booteable con Debian 13 Live (GNOME/KDE/Xfce)
#   - Descargar desde: https://www.debian.org/CD/live/
#
# Conocimientos:
#   - Uso básico de terminal Linux
#   - Conocer el disco a usar (será COMPLETAMENTE BORRADO)
#
# Tiempo estimado:
#   - Descarga e instalación: 20-30 minutos
#   - Depende de velocidad de internet y hardware
#
# ============================================
# QUÉ VA A DEJAR INSTALADO
# ============================================
#
# Particiones:
#   1. EFI (FAT32, 1GB por defecto)
#      - Bootloader GRUB
#
#   2. SISTEMA (btrfs, ~80% del disco por defecto)
#      - Subvolúmenes:
#        @ → /                     (raíz del sistema)
#        @home → /home             (datos de usuarios)
#        @snapshots → /.snapshots  (para snapper)
#        @cache → /var/cache       (cachés del sistema)
#        @log → /var/log           (logs del sistema)
#        @tmp → /var/tmp           (temporales)
#        @swap → /var/swap         (swapfile)
#      - Compresión: zstd:1 (transparente)
#      - Opciones: noatime, space_cache=v2
#
#   3. BACKUP (btrfs, ~20% del disco por defecto)
#      - Para snapshots aislados con btrbk
#      - Normalmente DESMONTADA (seguridad)
#
# Sistema Operativo:
#   - Debian 13 "Trixie" (Testing)
#   - Kernel: linux-image-amd64 (último stable)
#   - Firmware: firmware-linux, firmware-linux-nonfree
#
# Bootloader:
#   - GRUB (UEFI)
#   - grub-btrfs: Detecta snapshots automáticamente
#   - grub-btrfsd: Servicio que actualiza GRUB al crear snapshots
#
# Filesystem:
#   - btrfs-progs: Herramientas para gestionar btrfs
#
# Red:
#   - systemd-networkd: Configuración de red (DHCP)
#   - systemd-resolved: Resolución DNS
#
# Software adicional:
#   - Se define por modo elegido:
#     AUTO        -> tasksel no interactivo
#     INTERACTIVE -> tasksel con menú
#     POSTBOOT    -> dejar software para después
#
# Usuarios:
#   - Usuario personalizado con permisos sudo
#   - Root BLOQUEADO (sin password, sin login directo)
#
# Swap:
#   - Swapfile en /var/swap/swapfile
#   - Tamaño calculado según RAM disponible
#
# ============================================
# NO INSTALADO (para configurar después)
# ============================================
#
# - snapper: Gestión de snapshots automáticos
# - btrbk: Backups incrementales a partición aislada
# - Entorno de escritorio (GNOME, KDE, etc.)
# - Docker, bases de datos, u otro software específico
#
# El sistema queda MINIMAL pero FUNCIONAL para trabajar
# vía terminal local o SSH.
#
# CÓMO RESUELVE PREGUNTAS DEL INSTALADOR ESTÁNDAR DE DEBIAN
#
# - Software no libre / firmware:
#   Se habilita en sources.list con "contrib non-free non-free-firmware"
#   y se instalan firmware-linux + firmware-linux-nonfree cuando aplica.
#
# - Orígenes de software:
#   Se genera /etc/apt/sources.list para Trixie con:
#   * repositorio principal
#   * security
#   * updates
#   incluyendo también entradas deb-src.
#
# - Selección de tareas (tasksel):
#   Se puede resolver en instalación (auto/interactivo) o diferir al primer boot.
#
# ============================================
# CÓMO EJECUTAR
# ============================================
#
# === CON VENTOY (RECOMENDADO) ===
#
# En Windows:
#   1. Descargar ISO Debian Live:
#      https://www.debian.org/CD/live/
#      Archivo: debian-live-13.0.0-amd64-gnome.iso
#
#   2. Copiar ISO al USB Ventoy:
#      - Conectar USB Ventoy
#      - Copiar ISO a raíz del USB (ejemplo: E:\)
#
#   3. Crear carpeta para scripts:
#      - En el USB crear: E:\scripts\
#
#   4. Guardar este script:
#      - Guardar como: E:\scripts\005_debian-btrfs-installer.sh
#      - ⚠️ Extensión .sh (no .txt)
#
# Bootear:
#   5. Reiniciar PC y bootear desde USB:
#      - Presionar F12 (o F9/F8/ESC según PC)
#      - Seleccionar USB Ventoy
#      - En menú Ventoy: seleccionar Debian ISO
#      - En menú Debian: seleccionar "Live system"
#
# En Debian Live:
#   6. Abrir terminal (Ctrl+Alt+T)
#
#   7. Copiar script desde USB:
#      cp /media/*/Ventoy/scripts/debian-btrfs-installer.sh ~
#      cd ~
#
#   8. Ejecutar:
#      chmod +x 005_debian-btrfs-installer.sh
#      sudo ./005_debian-btrfs-installer.sh
#
# === SIN VENTOY (MÉTODO TRADICIONAL) ===
#
# 1. Bootear Debian Live desde USB
#
# 2. Descargar script:
#    wget https://raw.githubusercontent.com/amalatesta/debian-btrfs/main/installer.sh
#    mv installer.sh 005_debian-btrfs-installer.sh
#
# 3. Ejecutar:
#    chmod +x 005_debian-btrfs-installer.sh
#    sudo ./005_debian-btrfs-installer.sh
#
# ============================================
# PASOS SIGUIENTES (después de instalación)
# ============================================
#
# Una vez que reinicies y arranques el nuevo sistema:
#
# --- CONFIGURACIÓN BÁSICA ---
#
# 1. Obtener dirección IP (si usas SSH):
#    $ ip addr show
#
# 2. Conectar desde otro equipo (opcional):
#    $ ssh usuario@<IP>
#
# 3. Actualizar sistema:
#    $ sudo apt update
#    $ sudo apt upgrade
#
# --- SNAPSHOTS CON SNAPPER ---
#
# 4. Instalar snapper:
#    $ sudo apt install snapper
#
# 5. Configurar snapper para el sistema:
#    $ sudo snapper -c root create-config /
#
# 6. Ajustar subvolumen snapshots:
#    (snapper crea su propio subvolumen, usar el nuestro)
#    $ sudo btrfs subvolume delete /.snapshots
#    $ sudo mkdir /.snapshots
#    $ sudo mount -a
#
# 7. Configurar retención de snapshots:
#    $ sudo nano /etc/snapper/configs/root
#
#    Editar:
#      TIMELINE_CREATE="no"              # Deshabilitar snapshots automáticos
#      NUMBER_LIMIT="10"                 # Mantener últimos 10 pares
#      NUMBER_LIMIT_IMPORTANT="10"
#
# 8. Habilitar limpieza automática:
#    $ sudo systemctl enable snapper-cleanup.timer
#
# 9. Configurar hooks de APT (snapshots antes/después de apt):
#    $ sudo nano /etc/apt/apt.conf.d/80snapper
#
#    Agregar:
#      DPkg::Pre-Invoke {"snapper --config root create --type pre --cleanup-algorithm number --print-number --description 'apt pre' > /tmp/snapper-pre-number";};
#      DPkg::Post-Invoke {"snapper --config root create --type post --cleanup-algorithm number --pre-number $(cat /tmp/snapper-pre-number) --description 'apt post'";};
#
# 10. Crear primer snapshot:
#    $ sudo snapper -c root create --description "Sistema base instalado"
#
# --- BACKUPS CON BTRBK ---
#
# 11. Instalar btrbk:
#    $ sudo apt install btrbk
#
# 12. El UUID de la partición backup se mostró al finalizar la instalación
#     O consultar con: sudo blkid | grep BACKUP
#
# 13. Crear script para montar/desmontar backup:
#    $ sudo nano /usr/local/bin/mount-backup
#
#    Contenido:
#      #!/bin/bash
#      BACKUP_UUID="<UUID-mostrado-al-final>"
#      case "$1" in
#        mount)
#          mount UUID=$BACKUP_UUID /mnt/backup
#          ;;
#        umount)
#          umount /mnt/backup
#          ;;
#      esac
#
#    $ sudo chmod +x /usr/local/bin/mount-backup
#
# 14. Configurar btrbk:
#    $ sudo nano /etc/btrbk/btrbk.conf
#
#    Contenido:
#      volume /
#        subvolume @
#          snapshot_dir /.snapshots
#          target /mnt/backup
#            snapshot_preserve 14d 8w 6m
#            target_preserve 14d 8w 6m
#
# 15. Crear timer systemd para btrbk diario:
#    Ver documentación completa en:
#    https://github.com/amalatesta/debian-btrfs
#
# ============================================
# NOTAS IMPORTANTES
# ============================================
#
# - BACKUP: Este script BORRARÁ completamente el disco seleccionado.
#
# - UEFI: Solo funciona en sistemas UEFI (no BIOS Legacy).
#
# - Internet: Requiere conexión activa durante instalación.
#
# - Tiempo: 20-30 minutos según conexión y hardware.
#
# - Log: Todo se registra en /tmp/debian-install-*.log
#
# ============================================

set -Eeuo pipefail  # Salir si cualquier comando falla y propagar errores en pipes

# ============================================
# CONFIGURACIÓN Y VARIABLES GLOBALES
# ============================================

VERSION="5.0"
LOG_FILE="/tmp/debian-install-$(date +%Y%m%d-%H%M%S).log"
DEBIAN_RELEASE="trixie"
DEBIAN_MIRROR="http://deb.debian.org/debian"

# Variables de configuración (se llenan interactivamente)
DISK=""
DISK_SIZE_GB=0
RAM_GB=0

# Particiones
EFI_PART=""
SYSTEM_PART=""
BACKUP_PART=""
EFI_SIZE=""
SYSTEM_SIZE=""
CREATE_BACKUP="S"

# UUIDs
EFI_UUID=""
SYSTEM_UUID=""
BACKUP_UUID=""

# Sistema
HOSTNAME=""
USERNAME=""
USER_PASSWORD=""
TIMEZONE=""
LOCALE=""
SWAP_SIZE=""

# Preguntas no críticas (con sugerencias)
APT_ENABLE_NONFREE="S"
APT_ENABLE_DEBSRC="N"
APT_ENABLE_SECURITY="S"
APT_ENABLE_UPDATES="S"
APT_PROXY=""
INSTALL_NONFREE_FIRMWARE="S"
ENABLE_POPCON="N"
SOFTWARE_INSTALL_MODE="POSTBOOT"   # AUTO | INTERACTIVE | POSTBOOT
INSTALL_SSH_IN_BASE="S"
INSTALL_TASKSEL_NOW="N"

# Sugerencias calculadas
SUGGESTED_EFI="1G"
SUGGESTED_SYSTEM_GB=0
SUGGESTED_SYSTEM_PCT=0
SUGGESTED_BACKUP_GB=0
SUGGESTED_SWAP=""
SWAP_REASON=""
SUGGESTED_TIMEZONE=""
SUGGESTED_LOCALE=""
SUGGESTED_HOSTNAME="debian-pc"

# Opciones btrfs
BTRFS_OPTS="defaults,noatime,space_cache=v2,compress=zstd:1"

# Estado de montaje para limpieza segura
MOUNTED_TARGET="false"
MOUNTED_CHROOT_BIND="false"

# ============================================
# FUNCIONES DE UTILIDAD
# ============================================

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error() {
    echo "❌ ERROR: $*" | tee -a "$LOG_FILE" >&2
    exit 1
}

warning() {
    echo "⚠️  ADVERTENCIA: $*" | tee -a "$LOG_FILE"
}

success() {
    echo "✓ $*" | tee -a "$LOG_FILE"
}

separator() {
    echo "========================================" | tee -a "$LOG_FILE"
}

cleanup_mounts() {
    if [[ "$MOUNTED_CHROOT_BIND" == "true" ]]; then
        umount -R /mnt/proc &>/dev/null || true
        umount -R /mnt/sys &>/dev/null || true
        umount -R /mnt/dev &>/dev/null || true
        umount -R /mnt/run &>/dev/null || true
        MOUNTED_CHROOT_BIND="false"
    fi

    if [[ "$MOUNTED_TARGET" == "true" ]]; then
        umount -R /mnt &>/dev/null || true
        MOUNTED_TARGET="false"
    fi
}

handle_error() {
    local line="$1"
    echo "❌ ERROR inesperado en línea ${line}. Revisa el log: $LOG_FILE" | tee -a "$LOG_FILE" >&2
    cleanup_mounts
}

normalize_yes_no() {
    local input="${1:-}"
    input="${input^^}"
    case "$input" in
        S|SI|Y|YES)
            echo "S"
            ;;
        N|NO)
            echo "N"
            ;;
        *)
            echo ""
            ;;
    esac
}

normalize_software_mode() {
    local input="${1:-}"
    input="${input^^}"
    case "$input" in
        1|AUTO)
            echo "AUTO"
            ;;
        2|INTERACTIVE)
            echo "INTERACTIVE"
            ;;
        3|POSTBOOT|POST-BOOT)
            echo "POSTBOOT"
            ;;
        *)
            echo ""
            ;;
    esac
}

is_valid_size_gib() {
    [[ "$1" =~ ^[1-9][0-9]*G$ ]]
}

analyze_locale_timezone() {
    SUGGESTED_TIMEZONE="$(cat /etc/timezone 2>/dev/null || true)"
    if [[ -z "$SUGGESTED_TIMEZONE" ]]; then
        SUGGESTED_TIMEZONE="$(timedatectl show -p Timezone --value 2>/dev/null || true)"
    fi
    if [[ -z "$SUGGESTED_TIMEZONE" ]]; then
        SUGGESTED_TIMEZONE="UTC"
    fi

    SUGGESTED_LOCALE="$(locale 2>/dev/null | awk -F= '/^LANG=/{print $2}')"
    if [[ -z "$SUGGESTED_LOCALE" ]]; then
        SUGGESTED_LOCALE="en_US.UTF-8"
    fi

    return 0
}

trap 'handle_error $LINENO' ERR
trap cleanup_mounts EXIT

# ============================================
# VALIDACIONES
# ============================================

check_requirements() {
    log "Verificando requisitos..."
    
    # Verificar root
    if [[ $EUID -ne 0 ]]; then
        error "Este script debe ejecutarse como root (sudo)"
    fi

    # Verificar UEFI real
    if [[ ! -d /sys/firmware/efi ]]; then
        error "Entorno no UEFI detectado. Este instalador solo soporta UEFI."
    fi
    
    # Verificar internet
    if ! ping -c 1 deb.debian.org &>/dev/null; then
        error "Sin conexión a internet. Verificar red."
    fi
    
    # Instalar herramientas si faltan
    local tools_needed=false
    for tool in debootstrap gdisk mkfs.btrfs mkfs.fat lsblk blkid sgdisk partprobe; do
        if ! command -v "$tool" &>/dev/null; then
            tools_needed=true
            break
        fi
    done
    
    if [[ "$tools_needed" == true ]]; then
        log "Instalando herramientas necesarias..."
        apt update &>/dev/null
        apt install -y debootstrap gdisk btrfs-progs dosfstools util-linux &>/dev/null
    fi

    analyze_locale_timezone
    
    success "Requisitos verificados"
}

# ============================================
# DETECCIÓN DE HARDWARE
# ============================================

detect_disks() {
    log "Detectando discos disponibles..."
    
    local disks=()
    local disk_info=()
    
    local live_root_src=""
    local live_root_disk=""
    live_root_src="$(findmnt -n -o SOURCE / 2>/dev/null || true)"
    if [[ -n "$live_root_src" ]]; then
        live_root_disk="$(lsblk -ndo PKNAME "$live_root_src" 2>/dev/null || true)"
    fi

    while IFS= read -r line; do
        local disk=$(echo "$line" | awk '{print $1}')
        local size=$(lsblk -ndo SIZE "/dev/$disk" 2>/dev/null | xargs)
        local model=$(lsblk -ndo MODEL "/dev/$disk" 2>/dev/null | xargs)
        local type=$(lsblk -ndo TYPE "/dev/$disk" 2>/dev/null)
        local rm=$(lsblk -ndo RM "/dev/$disk" 2>/dev/null | xargs)
        
        if [[ "$type" == "disk" ]]; then
            disks+=("/dev/$disk")
            disk_info+=("$size $model (removable=$rm)")
        fi
    done < <(lsblk -ndpo NAME -I 8,259,254 | sed 's|/dev/||')
    
    if [[ ${#disks[@]} -eq 0 ]]; then
        error "No se detectaron discos"
    fi
    
    separator
    echo "DISCOS DISPONIBLES:"
    echo ""
    
    for i in "${!disks[@]}"; do
        local idx=$((i + 1))
        echo "[$idx] ${disks[$i]} (${disk_info[$i]})"

        if [[ -n "$live_root_disk" ]] && [[ "${disks[$i]}" == "/dev/$live_root_disk" ]]; then
            echo "    ⚠️  Este parece ser el disco desde el que corre el sistema live actual"
        fi
        
        if lsblk -n "${disks[$i]}" | grep -q part; then
            echo "    ⚠️  Contiene particiones:"
            lsblk -ln -o NAME,SIZE,FSTYPE,LABEL,TYPE "${disks[$i]}" 2>/dev/null | awk '$5=="part"{printf "    %s %s %s %s\n",$1,$2,$3,$4}' || warning "No se pudieron listar las particiones de ${disks[$i]}"
        fi
    done
    echo ""
    
    local selection=""
    while true; do
        read -p "Selecciona disco [1-${#disks[@]}]: " selection
        if [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -le ${#disks[@]} ]]; then
            local candidate_disk="${disks[$((selection - 1))]}"

            if lsblk -n "$candidate_disk" | grep -q part; then
                echo ""
                warning "El disco $candidate_disk ya contiene particiones y serán ELIMINADAS."
                local wipe_confirm=""
                while true; do
                    read -p "¿Continuar con este disco? [s/N]: " wipe_confirm
                    wipe_confirm="${wipe_confirm:-N}"
                    wipe_confirm="$(normalize_yes_no "$wipe_confirm")"
                    if [[ -n "$wipe_confirm" ]]; then
                        break
                    fi
                    echo "Respuesta inválida. Usa S o N"
                done

                if [[ "$wipe_confirm" != "S" ]]; then
                    echo "Seleccioná otro disco."
                    continue
                fi
            fi

            DISK="$candidate_disk"
            break
        fi
        echo "Selección inválida"
    done
    
    success "Disco seleccionado: $DISK"
}

analyze_and_suggest() {
    log "Analizando hardware y calculando sugerencias..."
    
    # Tamaño del disco
    DISK_SIZE_GB=$(lsblk -bdn -o SIZE "$DISK" | awk '{print int($1/1024/1024/1024)}')
    
    # RAM
    RAM_GB=$(free -m | awk '/^Mem:/{print int($2/1024)}')
    
    # Calcular particiones
    if [[ $DISK_SIZE_GB -lt 128 ]]; then
        SUGGESTED_SYSTEM_PCT=90
    elif [[ $DISK_SIZE_GB -lt 256 ]]; then
        SUGGESTED_SYSTEM_PCT=85
    else
        SUGGESTED_SYSTEM_PCT=80
    fi
    
    SUGGESTED_SYSTEM_GB=$((DISK_SIZE_GB * SUGGESTED_SYSTEM_PCT / 100))
    SUGGESTED_BACKUP_GB=$((DISK_SIZE_GB - SUGGESTED_SYSTEM_GB - 1))
    
    # Calcular swap
    if [[ $RAM_GB -le 2 ]]; then
        SUGGESTED_SWAP="${RAM_GB}G"
        SWAP_REASON="igual a RAM (sistema con poca memoria)"
    elif [[ $RAM_GB -le 8 ]]; then
        SUGGESTED_SWAP="$((RAM_GB * 2))G"
        SWAP_REASON="2x RAM (permite hibernación)"
    elif [[ $RAM_GB -le 16 ]]; then
        SUGGESTED_SWAP="${RAM_GB}G"
        SWAP_REASON="igual a RAM (permite hibernación)"
    else
        SUGGESTED_SWAP="8G"
        SWAP_REASON="8GB fijo (RAM suficiente)"
    fi
    
    # Hostname según tipo hardware
    if grep -q "laptop\|notebook" /sys/class/dmi/id/chassis_type 2>/dev/null || \
       grep -qi "laptop\|notebook" /sys/class/dmi/id/product_name 2>/dev/null; then
        SUGGESTED_HOSTNAME="debian-laptop"
    else
        SUGGESTED_HOSTNAME="debian-pc"
    fi

    # Ajustar locale/timezone según entorno detectado
    [[ -z "$SUGGESTED_TIMEZONE" ]] && SUGGESTED_TIMEZONE="UTC"
    [[ -z "$SUGGESTED_LOCALE" ]] && SUGGESTED_LOCALE="en_US.UTF-8"
    
    success "Análisis completado (Disco: ${DISK_SIZE_GB}GB, RAM: ${RAM_GB}GB)"
}

# ============================================
# CONFIGURACIÓN INTERACTIVA
# ============================================

interactive_config() {
    local config_valid=false
    
    while [[ "$config_valid" == false ]]; do
        separator
        echo "CONFIGURACIÓN DEL SISTEMA"
        separator
        echo ""
        echo "Disco seleccionado: $DISK"
        echo "  Capacidad: ${DISK_SIZE_GB}GB"
        echo "  Modelo: $(lsblk -ndo MODEL "$DISK" 2>/dev/null | xargs)"
        echo ""
        
        # PARTICIONES
        separator
        echo "CONFIGURACIÓN DE PARTICIONES"
        separator
        echo ""
        echo "Partición EFI (bootloader):"
        while true; do
            read -p "  Tamaño [$SUGGESTED_EFI]: " EFI_SIZE
            EFI_SIZE="${EFI_SIZE:-$SUGGESTED_EFI}"
            if is_valid_size_gib "$EFI_SIZE"; then
                break
            fi
            warning "Tamaño EFI inválido. Usar formato entero en GiB, por ejemplo: 1G"
        done
        
        echo ""
        echo "Partición Sistema (btrfs - sistema operativo):"
        echo "  Sugerencia: ${SUGGESTED_SYSTEM_GB}GB (${SUGGESTED_SYSTEM_PCT}% del disco)"
        while true; do
            read -p "  Tamaño [${SUGGESTED_SYSTEM_GB}G]: " SYSTEM_SIZE
            SYSTEM_SIZE="${SYSTEM_SIZE:-${SUGGESTED_SYSTEM_GB}G}"
            if ! is_valid_size_gib "$SYSTEM_SIZE"; then
                warning "Tamaño de sistema inválido. Usar formato entero en GiB, por ejemplo: 80G"
                continue
            fi

            SYSTEM_SIZE_NUM="${SYSTEM_SIZE%G}"
            if [[ "$SYSTEM_SIZE_NUM" -lt 16 ]]; then
                warning "La partición de sistema debe ser al menos 16G"
                continue
            fi
            if [[ "$SYSTEM_SIZE_NUM" -ge $((DISK_SIZE_GB - 1)) ]]; then
                warning "El tamaño del sistema deja sin espacio suficiente para EFI/backup"
                continue
            fi
            break
        done

        local backup_size_calc=$((DISK_SIZE_GB - SYSTEM_SIZE_NUM - 1))
        
        echo ""
        echo "Partición Backup (btrfs - snapshots aislados):"
        echo "  Espacio restante: ${backup_size_calc}GB"
        echo "  Nota: Esta partición estará normalmente desmontada (seguridad)"
        while true; do
            read -p "  ¿Crear partición backup? [S/n]: " CREATE_BACKUP
            CREATE_BACKUP="${CREATE_BACKUP:-S}"
            CREATE_BACKUP="$(normalize_yes_no "$CREATE_BACKUP")"
            if [[ -n "$CREATE_BACKUP" ]]; then
                break
            fi
            warning "Respuesta inválida. Usa S o N"
        done
        
        # SWAP
        echo ""
        separator
        echo "CONFIGURACIÓN DE SWAP"
        separator
        echo "  RAM detectada: ${RAM_GB}GB"
        echo "  Sugerencia: $SUGGESTED_SWAP ($SWAP_REASON)"
        echo ""
        while true; do
            read -p "Tamaño de swap [$SUGGESTED_SWAP]: " SWAP_SIZE
            SWAP_SIZE="${SWAP_SIZE:-$SUGGESTED_SWAP}"
            if is_valid_size_gib "$SWAP_SIZE"; then
                break
            fi
            warning "Tamaño de swap inválido. Usar formato entero en GiB, por ejemplo: 8G"
        done
        
        # SISTEMA
        echo ""
        separator
        echo "CONFIGURACIÓN DEL SISTEMA"
        separator
        echo ""
        read -p "Hostname [$SUGGESTED_HOSTNAME]: " HOSTNAME
        HOSTNAME="${HOSTNAME:-$SUGGESTED_HOSTNAME}"
        
        read -p "Nombre de usuario [usuario]: " USERNAME
        USERNAME="${USERNAME:-usuario}"
        
        while true; do
            read -s -p "Password para $USERNAME: " USER_PASSWORD
            echo ""
            if [[ -z "$USER_PASSWORD" ]]; then
                echo "  ⚠️  Password no puede estar vacío"
                continue
            fi
            read -s -p "Repetir password: " USER_PASSWORD2
            echo ""
            if [[ "$USER_PASSWORD" == "$USER_PASSWORD2" ]]; then
                break
            fi
            echo "  ⚠️  Los passwords no coinciden"
        done
        
        # REGIONAL
        echo ""
        read -p "Zona horaria [$SUGGESTED_TIMEZONE]: " TIMEZONE
        TIMEZONE="${TIMEZONE:-$SUGGESTED_TIMEZONE}"
        
        read -p "Locale [$SUGGESTED_LOCALE]: " LOCALE
        LOCALE="${LOCALE:-$SUGGESTED_LOCALE}"

        # PREGUNTAS NO CRÍTICAS (ESTILO INSTALADOR DEBIAN)
        echo ""
        separator
        echo "PREGUNTAS NO CRÍTICAS"
        separator
        echo "Si presionas ENTER, se usa la sugerencia."
        echo ""

        while true; do
            read -p "Habilitar software no libre en repositorios? [S/n]: " APT_ENABLE_NONFREE
            APT_ENABLE_NONFREE="${APT_ENABLE_NONFREE:-S}"
            APT_ENABLE_NONFREE="$(normalize_yes_no "$APT_ENABLE_NONFREE")"
            [[ -n "$APT_ENABLE_NONFREE" ]] && break
            warning "Respuesta inválida. Usa S o N"
        done

        while true; do
            read -p "Habilitar repositorio security? [S/n]: " APT_ENABLE_SECURITY
            APT_ENABLE_SECURITY="${APT_ENABLE_SECURITY:-S}"
            APT_ENABLE_SECURITY="$(normalize_yes_no "$APT_ENABLE_SECURITY")"
            [[ -n "$APT_ENABLE_SECURITY" ]] && break
            warning "Respuesta inválida. Usa S o N"
        done

        while true; do
            read -p "Habilitar repositorio updates? [S/n]: " APT_ENABLE_UPDATES
            APT_ENABLE_UPDATES="${APT_ENABLE_UPDATES:-S}"
            APT_ENABLE_UPDATES="$(normalize_yes_no "$APT_ENABLE_UPDATES")"
            [[ -n "$APT_ENABLE_UPDATES" ]] && break
            warning "Respuesta inválida. Usa S o N"
        done

        while true; do
            read -p "Incluir repositorios de código fuente (deb-src)? [s/N]: " APT_ENABLE_DEBSRC
            APT_ENABLE_DEBSRC="${APT_ENABLE_DEBSRC:-N}"
            APT_ENABLE_DEBSRC="$(normalize_yes_no "$APT_ENABLE_DEBSRC")"
            [[ -n "$APT_ENABLE_DEBSRC" ]] && break
            warning "Respuesta inválida. Usa S o N"
        done

        read -p "Proxy HTTP para APT (vacío = sin proxy): " APT_PROXY

        while true; do
            read -p "Instalar firmware no libre (si aplica)? [S/n]: " INSTALL_NONFREE_FIRMWARE
            INSTALL_NONFREE_FIRMWARE="${INSTALL_NONFREE_FIRMWARE:-S}"
            INSTALL_NONFREE_FIRMWARE="$(normalize_yes_no "$INSTALL_NONFREE_FIRMWARE")"
            [[ -n "$INSTALL_NONFREE_FIRMWARE" ]] && break
            warning "Respuesta inválida. Usa S o N"
        done

        while true; do
            read -p "Participar en popularity-contest? [s/N]: " ENABLE_POPCON
            ENABLE_POPCON="${ENABLE_POPCON:-N}"
            ENABLE_POPCON="$(normalize_yes_no "$ENABLE_POPCON")"
            [[ -n "$ENABLE_POPCON" ]] && break
            warning "Respuesta inválida. Usa S o N"
        done

        echo ""
        echo "Modo de software base:"
        echo "  [1] AUTO        -> instala standard (+SSH opcional)"
        echo "  [2] INTERACTIVE -> abre tasksel para elegir"
        echo "  [3] POSTBOOT    -> deja software para después del primer arranque"
        while true; do
            read -p "Selecciona modo [3]: " SOFTWARE_INSTALL_MODE
            SOFTWARE_INSTALL_MODE="${SOFTWARE_INSTALL_MODE:-3}"
            SOFTWARE_INSTALL_MODE="$(normalize_software_mode "$SOFTWARE_INSTALL_MODE")"
            [[ -n "$SOFTWARE_INSTALL_MODE" ]] && break
            warning "Opción inválida. Usa 1, 2 o 3"
        done

        while true; do
            read -p "Instalar SSH en la base? [S/n]: " INSTALL_SSH_IN_BASE
            INSTALL_SSH_IN_BASE="${INSTALL_SSH_IN_BASE:-S}"
            INSTALL_SSH_IN_BASE="$(normalize_yes_no "$INSTALL_SSH_IN_BASE")"
            [[ -n "$INSTALL_SSH_IN_BASE" ]] && break
            warning "Respuesta inválida. Usa S o N"
        done

        while true; do
            read -p "Instalar paquete tasksel ahora? [s/N]: " INSTALL_TASKSEL_NOW
            INSTALL_TASKSEL_NOW="${INSTALL_TASKSEL_NOW:-N}"
            INSTALL_TASKSEL_NOW="$(normalize_yes_no "$INSTALL_TASKSEL_NOW")"
            [[ -n "$INSTALL_TASKSEL_NOW" ]] && break
            warning "Respuesta inválida. Usa S o N"
        done
        
        # RESUMEN
        show_configuration_summary
        
        # OPCIONES
        echo ""
        echo "Opciones:"
        echo "  [C] Confirmar y continuar con la instalación"
        echo "  [M] Modificar configuración"
        echo "  [S] Salir sin instalar"
        echo ""
        read -p "Selecciona [C/m/s]: " choice
        choice="${choice:-C}"
        
        case "${choice^^}" in
            C)
                separator
                echo "CONFIRMACIÓN FINAL DE SEGURIDAD"
                separator
                echo ""
                echo "Vas a BORRAR completamente: $DISK"
                read -p "Escribe exactamente '$DISK' para continuar: " disk_confirm
                if [[ "$disk_confirm" == "$DISK" ]]; then
                    config_valid=true
                else
                    warning "Confirmación incorrecta. Volviendo a configuración."
                    sleep 2
                fi
                ;;
            M)
                echo ""
                echo "Reconfigurando..."
                sleep 1
                ;;
            S)
                error "Instalación cancelada por el usuario"
                ;;
            *)
                echo "Opción inválida"
                sleep 2
                ;;
        esac
    done
}

show_configuration_summary() {
    separator
    echo "RESUMEN DE CONFIGURACIÓN"
    separator
    echo ""
    
    echo "═══ HARDWARE ═══"
    echo "Disco: $DISK"
    echo "  Modelo: $(lsblk -ndo MODEL "$DISK" 2>/dev/null | xargs)"
    echo "  Capacidad: ${DISK_SIZE_GB}GB"
    echo "  RAM: ${RAM_GB}GB"
    echo ""
    
    echo "═══ PARTICIONES ═══"
    local system_num=$(echo "$SYSTEM_SIZE" | sed 's/[^0-9]//g')
    local backup_calc=$((DISK_SIZE_GB - system_num - 1))
    
    echo "  1. EFI (FAT32)"
    echo "     Tamaño: $EFI_SIZE"
    echo "     Montaje: /boot/efi"
    echo ""
    
    echo "  2. SISTEMA (btrfs)"
    echo "     Tamaño: $SYSTEM_SIZE"
    echo "     Compresión: zstd:1"
    echo "     Subvolúmenes:"
    echo "       @ → /"
    echo "       @home → /home"
    echo "       @snapshots → /.snapshots"
    echo "       @cache → /var/cache"
    echo "       @log → /var/log"
    echo "       @tmp → /var/tmp"
    echo "       @swap → /var/swap"
    echo ""
    
    if [[ "$CREATE_BACKUP" == "S" ]]; then
        echo "  3. BACKUP (btrfs)"
        echo "     Tamaño: ${backup_calc}GB (resto del disco)"
        echo "     Montaje: /mnt/backup (desmontado por defecto)"
        echo ""
    else
        echo "  3. Sin partición backup"
        echo ""
    fi
    
    echo "═══ SWAP ═══"
    echo "  Archivo: /var/swap/swapfile"
    echo "  Tamaño: $SWAP_SIZE"
    echo ""
    
    echo "═══ SISTEMA OPERATIVO ═══"
    echo "  Debian: $DEBIAN_RELEASE"
    echo "  Hostname: $HOSTNAME"
    echo "  Usuario: $USERNAME (grupo sudo)"
    echo "  Root: bloqueado"
    echo ""
    
    echo "═══ REGIONAL ═══"
    echo "  Timezone: $TIMEZONE"
    echo "  Locale: $LOCALE"
    echo ""
    
    echo "═══ SOFTWARE ═══"
    echo "  ✓ Debian minimal + kernel"
    echo "  ✓ GRUB + grub-btrfs"
    echo "  ✓ btrfs-progs"
    echo "  Modo software: $SOFTWARE_INSTALL_MODE"
    if [[ "$INSTALL_SSH_IN_BASE" == "S" ]]; then
        echo "  SSH en base: sí"
    else
        echo "  SSH en base: no"
    fi
    if [[ "$INSTALL_TASKSEL_NOW" == "S" ]]; then
        echo "  tasksel: se instala ahora"
    else
        echo "  tasksel: se deja para post-boot"
    fi
    if [[ "$INSTALL_NONFREE_FIRMWARE" == "S" ]]; then
        echo "  Firmware no libre: sí"
    else
        echo "  Firmware no libre: no"
    fi
    echo "  Repos: non-free=$APT_ENABLE_NONFREE, security=$APT_ENABLE_SECURITY, updates=$APT_ENABLE_UPDATES, deb-src=$APT_ENABLE_DEBSRC"
    echo ""
    
    echo "═══ RED ═══"
    echo "  DHCP automático (systemd-networkd)"
    echo ""
    
    warning "TODOS LOS DATOS EN $DISK SERÁN ELIMINADOS"
    echo ""
    separator
}

# ============================================
# PARTICIONADO Y FORMATEO
# ============================================

partition_disk() {
    log "Particionando $DISK..."
    
    if [[ "$DISK" =~ nvme ]]; then
        local P="p"
    else
        local P=""
    fi
    
    EFI_PART="${DISK}${P}1"
    SYSTEM_PART="${DISK}${P}2"
    BACKUP_PART="${DISK}${P}3"
    
    sgdisk -Z "$DISK" &>/dev/null || true
    sgdisk -og "$DISK" || error "Error creando GPT"
    sgdisk -n "1::+${EFI_SIZE}" -t 1:ef00 -c 1:"EFI" "$DISK" || error "Error partición EFI"
    sgdisk -n "2::+${SYSTEM_SIZE}" -t 2:8300 -c 2:"SISTEMA" "$DISK" || error "Error partición Sistema"
    
    if [[ "$CREATE_BACKUP" == "S" ]]; then
        sgdisk -n 3:: -t 3:8300 -c 3:"BACKUP" "$DISK" || error "Error partición Backup"
    fi
    
    partprobe "$DISK" &>/dev/null || true
    sleep 2
    
    success "Disco particionado"
}

format_partitions() {
    log "Formateando particiones..."
    
    mkfs.fat -F32 -n EFI "$EFI_PART" || error "Error formateando EFI"
    mkfs.btrfs -f -L DEBIAN "$SYSTEM_PART" || error "Error formateando Sistema"
    
    if [[ "$CREATE_BACKUP" == "S" ]]; then
        mkfs.btrfs -f -L BACKUP "$BACKUP_PART" || error "Error formateando Backup"
        BACKUP_UUID=$(blkid -s UUID -o value "$BACKUP_PART")
    fi
    
    EFI_UUID=$(blkid -s UUID -o value "$EFI_PART")
    SYSTEM_UUID=$(blkid -s UUID -o value "$SYSTEM_PART")
    
    success "Particiones formateadas"
}

# ============================================
# SUBVOLÚMENES BTRFS
# ============================================

create_subvolumes() {
    log "Creando subvolúmenes btrfs..."
    
    mount "$SYSTEM_PART" /mnt || error "Error montando sistema"
    
    btrfs subvolume create /mnt/@ || error "Error creando @"
    btrfs subvolume create /mnt/@home
    btrfs subvolume create /mnt/@snapshots
    btrfs subvolume create /mnt/@cache
    btrfs subvolume create /mnt/@log
    btrfs subvolume create /mnt/@tmp
    btrfs subvolume create /mnt/@swap
    
    umount /mnt
    
    success "Subvolúmenes creados"
}

mount_structure() {
    log "Montando estructura..."
    
    mount -o "$BTRFS_OPTS,subvol=@" "$SYSTEM_PART" /mnt
    
    mkdir -p /mnt/{home,boot/efi,.snapshots,var/{cache,log,tmp,swap}}
    
    mount -o "$BTRFS_OPTS,subvol=@home" "$SYSTEM_PART" /mnt/home
    mount -o "$BTRFS_OPTS,subvol=@snapshots" "$SYSTEM_PART" /mnt/.snapshots
    mount -o "$BTRFS_OPTS,subvol=@cache" "$SYSTEM_PART" /mnt/var/cache
    mount -o "$BTRFS_OPTS,subvol=@log" "$SYSTEM_PART" /mnt/var/log
    mount -o "$BTRFS_OPTS,subvol=@tmp" "$SYSTEM_PART" /mnt/var/tmp
    mount -o "defaults,noatime,subvol=@swap" "$SYSTEM_PART" /mnt/var/swap
    
    mount "$EFI_PART" /mnt/boot/efi
    MOUNTED_TARGET="true"
    
    success "Estructura montada"
}

# ============================================
# INSTALACIÓN BASE
# ============================================

install_base() {
    log "Instalando sistema base (varios minutos)..."
    
    debootstrap --arch=amd64 "$DEBIAN_RELEASE" /mnt "$DEBIAN_MIRROR" || error "Error en debootstrap"
    
    success "Sistema base instalado"
}

# ============================================
# CONFIGURACIÓN
# ============================================

configure_fstab() {
    log "Generando fstab..."
    
    cat > /mnt/etc/fstab << EOF
# /etc/fstab
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
    
    success "fstab generado"
}

configure_system() {
    log "Configurando sistema..."
    
    echo "$HOSTNAME" > /mnt/etc/hostname
    
    cat > /mnt/etc/hosts << EOF
127.0.0.1       localhost
127.0.1.1       $HOSTNAME

::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
EOF
    
    ln -sf "/usr/share/zoneinfo/$TIMEZONE" /mnt/etc/localtime
    
    echo "$LOCALE UTF-8" >> /mnt/etc/locale.gen
    echo "en_US.UTF-8 UTF-8" >> /mnt/etc/locale.gen
    
    success "Sistema configurado"
}

configure_apt_sources() {
    log "Configurando repositorios..."

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
        echo "" >> /mnt/etc/apt/sources.list
        echo "deb http://deb.debian.org/debian-security $DEBIAN_RELEASE-security $components" >> /mnt/etc/apt/sources.list
        if [[ "$APT_ENABLE_DEBSRC" == "S" ]]; then
            echo "deb-src http://deb.debian.org/debian-security $DEBIAN_RELEASE-security $components" >> /mnt/etc/apt/sources.list
        fi
    fi

    if [[ "$APT_ENABLE_UPDATES" == "S" ]]; then
        echo "" >> /mnt/etc/apt/sources.list
        echo "deb $DEBIAN_MIRROR ${DEBIAN_RELEASE}-updates $components" >> /mnt/etc/apt/sources.list
        if [[ "$APT_ENABLE_DEBSRC" == "S" ]]; then
            echo "deb-src $DEBIAN_MIRROR ${DEBIAN_RELEASE}-updates $components" >> /mnt/etc/apt/sources.list
        fi
    fi

    if [[ -n "$APT_PROXY" ]]; then
        cat > /mnt/etc/apt/apt.conf.d/90proxy << EOF
Acquire::http::Proxy "$APT_PROXY";
Acquire::https::Proxy "$APT_PROXY";
EOF
    fi
    
    success "Repositorios configurados"
}

create_user() {
    log "Creando usuario..."
    
    mount -t proc /proc /mnt/proc
    mount -t sysfs /sys /mnt/sys
    mount --rbind /dev /mnt/dev
    mount --rbind /run /mnt/run
    MOUNTED_CHROOT_BIND="true"
    
    cp /etc/resolv.conf /mnt/etc/
    
    chroot /mnt apt update
    chroot /mnt apt install -y locales sudo
    chroot /mnt locale-gen
    if [[ "$ENABLE_POPCON" == "S" ]]; then
        chroot /mnt apt install -y popularity-contest || true
    fi
    chroot /mnt useradd -m -s /bin/bash -G sudo "$USERNAME"
    echo "$USERNAME:$USER_PASSWORD" | chroot /mnt chpasswd
    chroot /mnt passwd -l root
    
    success "Usuario $USERNAME creado (root bloqueado)"
}

# ============================================
# KERNEL Y BOOTLOADER
# ============================================

install_kernel_grub() {
    log "Instalando kernel y GRUB..."
    
    chroot /mnt apt update
    chroot /mnt apt install -y linux-image-amd64 linux-headers-amd64
    if [[ "$INSTALL_NONFREE_FIRMWARE" == "S" ]]; then
        chroot /mnt apt install -y firmware-linux firmware-linux-nonfree || true
    fi
    chroot /mnt apt install -y grub-efi-amd64 efibootmgr
    chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=DEBIAN
    chroot /mnt apt install -y btrfs-progs
    chroot /mnt apt install -y grub-btrfs
    
    mkdir -p /mnt/etc/default/grub-btrfs
    cat > /mnt/etc/default/grub-btrfs/config << 'EOF'
GRUB_BTRFS_SUBMENUNAME="Debian Snapshots"
GRUB_BTRFS_LIMIT="10"
GRUB_BTRFS_SHOW_SNAPSHOTS_FOUND="true"
GRUB_BTRFS_SNAPSHOT_KERNEL_PARAMETERS="systemd.volatile=state"
EOF
    
    chroot /mnt systemctl enable grub-btrfsd.service || true
    chroot /mnt update-grub
    
    success "Kernel y GRUB instalados"
}

# ============================================
# SOFTWARE
# ============================================

install_software() {
    separator
    echo "INSTALACIÓN DE SOFTWARE BASE"
    separator
    echo ""
    case "$SOFTWARE_INSTALL_MODE" in
        AUTO)
            echo "Modo AUTO: instalación no interactiva de tareas seleccionadas"
            if [[ "$INSTALL_TASKSEL_NOW" == "S" ]]; then
                chroot /mnt apt install -y tasksel
            fi

            if [[ "$INSTALL_SSH_IN_BASE" == "S" ]]; then
                chroot /mnt apt install -y tasksel
                if ! chroot /mnt tasksel install standard ssh-server; then
                    warning "tasksel no pudo completar, aplicando fallback con apt"
                    chroot /mnt apt install -y task-standard openssh-server
                fi
            else
                chroot /mnt apt install -y tasksel
                if ! chroot /mnt tasksel install standard; then
                    warning "tasksel no pudo completar, aplicando fallback con apt"
                    chroot /mnt apt install -y task-standard
                fi
            fi
            ;;
        INTERACTIVE)
            echo "Modo INTERACTIVE: se abrirá tasksel para elección manual"
            chroot /mnt apt install -y tasksel
            chroot /mnt tasksel --new-install

            if [[ "$INSTALL_SSH_IN_BASE" == "S" ]] && ! chroot /mnt dpkg -l 2>/dev/null | grep -q "^ii.*openssh-server"; then
                chroot /mnt apt install -y openssh-server
            fi
            ;;
        POSTBOOT)
            echo "Modo POSTBOOT: no se instalan tareas ahora"
            if [[ "$INSTALL_TASKSEL_NOW" == "S" ]]; then
                chroot /mnt apt install -y tasksel
            fi
            if [[ "$INSTALL_SSH_IN_BASE" == "S" ]]; then
                chroot /mnt apt install -y openssh-server
            fi
            ;;
        *)
            warning "Modo de software desconocido, no se instalarán tareas"
            ;;
    esac
    
    if chroot /mnt dpkg -l 2>/dev/null | grep -q "^ii.*openssh-server"; then
        mkdir -p /mnt/etc/ssh/sshd_config.d
        cat > /mnt/etc/ssh/sshd_config.d/security.conf << 'EOF'
PermitRootLogin no
MaxAuthTries 3
EOF
        success "SSH configurado"
    fi
    
    success "Software instalado"
}

# ============================================
# RED
# ============================================

configure_network() {
    log "Configurando red..."
    
    cat > /mnt/etc/systemd/network/20-wired.network << 'EOF'
[Match]
Name=en* eth*

[Network]
DHCP=yes
EOF
    
    chroot /mnt systemctl enable systemd-networkd
    chroot /mnt systemctl enable systemd-resolved
    ln -sf /run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf
    
    success "Red configurada (DHCP)"
}

# ============================================
# SWAPFILE
# ============================================

create_swapfile() {
    log "Creando swapfile ($SWAP_SIZE)..."
    
    local swap_gb="${SWAP_SIZE%G}"
    local swap_mb=$((swap_gb * 1024))
    
    chroot /mnt truncate -s 0 /var/swap/swapfile
    chroot /mnt chattr +C /var/swap/swapfile
    chroot /mnt dd if=/dev/zero of=/var/swap/swapfile bs=1M count="$swap_mb" status=progress
    chroot /mnt chmod 600 /var/swap/swapfile
    chroot /mnt mkswap /var/swap/swapfile
    
    echo "/var/swap/swapfile none swap defaults 0 0" >> /mnt/etc/fstab
    
    success "Swapfile creado"
}

# ============================================
# FINALIZACIÓN
# ============================================

cleanup() {
    log "Limpiando..."
    
    chroot /mnt update-grub &>/dev/null || true
    cleanup_mounts
    
    success "Limpieza completada"
}

show_final_summary() {
    separator
    echo "✓ INSTALACIÓN COMPLETADA EXITOSAMENTE"
    separator
    echo ""
    
    echo "═══ SISTEMA INSTALADO ═══"
    echo "  Debian: $DEBIAN_RELEASE"
    echo "  Hostname: $HOSTNAME"
    echo "  Usuario: $USERNAME (sudo)"
    echo "  Root: bloqueado"
    echo ""
    
    echo "═══ PARTICIONES ═══"
    echo "  $EFI_PART → /boot/efi"
    echo "  $SYSTEM_PART → / (btrfs)"
    if [[ "$CREATE_BACKUP" == "S" ]]; then
        echo "  $BACKUP_PART → backup (desmontado)"
        echo ""
        echo "  UUID partición backup:"
        echo "  $BACKUP_UUID"
        echo "  (Usar en btrbk)"
    fi
    echo ""
    
    echo "═══ SUBVOLÚMENES ═══"
    echo "  @ → /"
    echo "  @home → /home"
    echo "  @snapshots → /.snapshots"
    echo "  @cache, @log, @tmp, @swap"
    echo ""
    
    echo "═══ SOFTWARE ═══"
    echo "  ✓ Kernel + GRUB + grub-btrfs"
    if chroot /mnt dpkg -l 2>/dev/null | grep -q "^ii.*openssh-server"; then
        echo "  ✓ SSH server (puerto 22)"
        echo "    ssh $USERNAME@<IP>"
    fi
    echo ""
    
    separator
    echo "PRÓXIMOS PASOS"
    separator
    echo ""
    echo "1. Instalar snapper:"
    echo "   \$ sudo apt install snapper"
    echo "   \$ sudo snapper -c root create-config /"
    echo "   \$ sudo btrfs subvolume delete /.snapshots"
    echo "   \$ sudo mkdir /.snapshots && sudo mount -a"
    echo ""
    echo "2. Configurar APT hooks:"
    echo "   \$ sudo nano /etc/apt/apt.conf.d/80snapper"
    echo ""
    echo "3. Instalar btrbk:"
    echo "   \$ sudo apt install btrbk"
    echo "   \$ sudo nano /etc/btrbk/btrbk.conf"
    if [[ "$CREATE_BACKUP" == "S" ]]; then
        echo ""
        echo "   volume /"
        echo "     subvolume @"
        echo "       snapshot_dir /.snapshots"
        echo "       target /mnt/backup"
    fi
    echo ""
    if [[ "$SOFTWARE_INSTALL_MODE" == "POSTBOOT" ]]; then
        echo "4. Software diferido (post-boot):"
        echo "   \$ sudo apt update"
        echo "   \$ sudo apt install tasksel"
        echo "   \$ sudo tasksel"
        if [[ "$INSTALL_SSH_IN_BASE" == "N" ]]; then
            echo "   # Si necesitas SSH remoto:"
            echo "   \$ sudo apt install openssh-server"
        fi
        echo ""
    fi

    echo "Documentación:"
    echo "  https://github.com/amalatesta/debian-btrfs"
    echo ""
    echo "Log: $LOG_FILE"
    echo ""
    separator
}

# ============================================
# MAIN
# ============================================

main() {
    clear
    separator
    echo "DEBIAN $DEBIAN_RELEASE - INSTALADOR AUTOMÁTICO"
    echo "btrfs + grub-btrfs"
    echo "Versión: $VERSION"
    separator
    echo ""
    
    check_requirements
    detect_disks
    analyze_and_suggest
    interactive_config
    
    log "Iniciando instalación..."
    
    partition_disk
    format_partitions
    create_subvolumes
    mount_structure
    install_base
    configure_fstab
    configure_system
    configure_apt_sources
    create_user
    install_kernel_grub
    install_software
    configure_network
    create_swapfile
    cleanup
    
    show_final_summary
    
    cleanup_mounts
    
    echo ""
    read -p "Presiona ENTER para reiniciar..." dummy
    reboot
}

main "$@"
