#!/bin/bash
#
# ============================================
# DEBIAN BTRFS INSTALLER
# ============================================
#
# Instalador automático de Debian 13 (Trixie) con btrfs y grub-btrfs
#
# Versión: 7.0
# Autor: Para amalatesta
# Repositorio: https://github.com/amalatesta/debian-btrfs
# Fecha: 2026-04-11
#
# RESUMEN DE CAMBIOS (V7)
# - Se agregó interfaz visual opcional con whiptail (fallback a texto plano).
# - Se incorporó wizard inicial: Instalar / Dry-run / Ayuda / Salir.
# - El modo dry-run ahora funciona paso a paso (ENTER para avanzar, q para salir).
# - Se agregó barra de progreso por etapas en instalación real.
# - Se mejoró el manejo de errores con aviso visual en modo whiptail.
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

VERSION="7.0"
LOG_FILE="/tmp/debian-install-$(date +%Y%m%d-%H%M%S).log"
DEBIAN_RELEASE="trixie"
DEBIAN_MIRROR="http://deb.debian.org/debian"
DRY_RUN="N"
UI_MODE="AUTO"   # AUTO | TEXT | WHIPTAIL
USE_WHIPTAIL="N"
PROGRESS_WHIPTAIL_ACTIVE="N"
PROGRESS_LAST_PCT=-1
DRY_RUN_WHIPTAIL_NEXT="S"

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
GRUB_BTRFS_INSTALLED="N"

# ============================================
# FUNCIONES DE UTILIDAD
# ============================================

log() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg" >> "$LOG_FILE"
    if [[ "${USE_WHIPTAIL:-N}" != "S" ]]; then
        echo "$msg"
    fi
}

error() {
    echo "❌ ERROR: $*" | tee -a "$LOG_FILE" >&2
    exit 1
}

warning() {
    local msg="⚠️  ADVERTENCIA: $*"
    echo "$msg" >> "$LOG_FILE"
    if [[ "${USE_WHIPTAIL:-N}" != "S" ]]; then
        echo "$msg"
    fi
}

success() {
    local msg="✓ $*"
    echo "$msg" >> "$LOG_FILE"
    if [[ "${USE_WHIPTAIL:-N}" != "S" ]]; then
        echo "$msg"
    fi
}

separator() {
    local msg="========================================"
    echo "$msg" >> "$LOG_FILE"
    if [[ "${USE_WHIPTAIL:-N}" != "S" ]]; then
        echo "$msg"
    fi
}

ui_textbox_from_text() {
    local title="$1"
    local text="$2"

    if [[ "$USE_WHIPTAIL" == "S" ]]; then
        local tmpfile
        local term_cols term_lines
        local win_w win_h

        term_cols="$(tput cols 2>/dev/null || echo 120)"
        term_lines="$(tput lines 2>/dev/null || echo 40)"

        win_w=$(( term_cols * 75 / 100 ))
        (( win_w < 60 )) && win_w=60
        (( win_w > 96 )) && win_w=96
        (( win_w > term_cols - 4 )) && win_w=$(( term_cols - 4 ))

        win_h=$(( term_lines * 75 / 100 ))
        (( win_h < 14 )) && win_h=14
        (( win_h > 28 )) && win_h=28
        (( win_h > term_lines - 2 )) && win_h=$(( term_lines - 2 ))

        tmpfile="$(mktemp)"
        printf "%s\n" "$text" > "$tmpfile"
        whiptail --title "$title" --textbox "$tmpfile" "$win_h" "$win_w"
        rm -f "$tmpfile"
    else
        echo "$text"
    fi
}

setup_ui() {
    case "$UI_MODE" in
        TEXT)
            USE_WHIPTAIL="N"
            ;;
        WHIPTAIL)
            if command -v whiptail &>/dev/null && [[ -t 0 ]] && [[ -t 1 ]]; then
                USE_WHIPTAIL="S"
            else
                error "Se forzo --whiptail pero whiptail no esta disponible o no hay TTY interactiva"
            fi
            ;;
        AUTO|*)
            if command -v whiptail &>/dev/null && [[ -t 0 ]] && [[ -t 1 ]]; then
                USE_WHIPTAIL="S"
            else
                USE_WHIPTAIL="N"
            fi
            ;;
    esac

    if [[ "$USE_WHIPTAIL" == "S" ]]; then
        # Usar tema por defecto de whiptail para mantener el mismo foco visual
        # que el smoke test (lista y botones con colores de seleccion esperados).
        unset NEWT_COLORS || true
        log "UI: whiptail"
    else
        log "UI: texto plano"
    fi
}

ui_warn() {
    local msg="$1"
    if [[ "$USE_WHIPTAIL" == "S" ]]; then
        whiptail --title "Advertencia" --msgbox "$msg" 12 78
    else
        warning "$msg"
    fi
}

ask_input() {
    local title="$1"
    local prompt="$2"
    local default_value="$3"
    local answer=""

    if [[ "$USE_WHIPTAIL" == "S" ]]; then
        answer="$(whiptail --title "$title" --inputbox "$prompt" 12 78 "$default_value" 3>&1 1>&2 2>&3)" || return 1
        echo "$answer"
    else
        read -r -p "$prompt [$default_value]: " answer </dev/tty
        echo "${answer:-$default_value}"
    fi
}

ask_password() {
    local title="$1"
    local prompt="$2"
    local answer=""

    if [[ "$USE_WHIPTAIL" == "S" ]]; then
        answer="$(whiptail --title "$title" --passwordbox "$prompt" 12 78 3>&1 1>&2 2>&3)" || return 1
        echo "$answer"
    else
        read -r -s -p "$prompt: " answer </dev/tty
        echo "" >/dev/tty
        echo "$answer"
    fi
}

ask_yes_no() {
    local title="$1"
    local prompt="$2"
    local default_yes_no="$3"
    local result=""

    if [[ "$USE_WHIPTAIL" == "S" ]]; then
        if [[ "$default_yes_no" == "N" ]]; then
            if whiptail --title "$title" --defaultno --yes-button "Si" --no-button "No" --yesno "$prompt" 12 78; then
                result="S"
            else
                result="N"
            fi
        else
            if whiptail --title "$title" --yes-button "Si" --no-button "No" --yesno "$prompt" 12 78; then
                result="S"
            else
                result="N"
            fi
        fi
        echo "$result"
    else
        read -r -p "$prompt [${default_yes_no}]: " result </dev/tty
        result="${result:-$default_yes_no}"
        result="$(normalize_yes_no "$result")"
        echo "$result"
    fi
}

ask_menu() {
    local title="$1"
    local prompt="$2"
    local default_value="$3"
    shift 3
    local answer=""

    if [[ "$USE_WHIPTAIL" == "S" ]]; then
        local term_cols term_lines
        local win_w win_h menu_h
        local option_count=$(( $# / 2 ))
        term_cols="$(tput cols 2>/dev/null || echo 120)"
        term_lines="$(tput lines 2>/dev/null || echo 40)"

        # Dimensiones adaptativas para mantener una apariencia mas centrada en distintas consolas.
        win_w=$(( term_cols * 50 / 100 ))
        (( win_w < 56 )) && win_w=56
        (( win_w > 72 )) && win_w=72
        (( win_w > term_cols - 4 )) && win_w=$(( term_cols - 4 ))

        win_h=$(( option_count + 10 ))
        (( win_h < 14 )) && win_h=14
        (( win_h > 24 )) && win_h=24
        (( win_h > term_lines - 2 )) && win_h=$(( term_lines - 2 ))

        menu_h=$(( win_h - 8 ))
        (( menu_h < 4 )) && menu_h=4
        (( menu_h > option_count )) && menu_h=$option_count

        answer="$(whiptail --title "$title" --menu "$prompt" "$win_h" "$win_w" "$menu_h" --default-item "$default_value" "$@" 3>&1 1>&2 2>&3)" || return 1
        echo "$answer"
    else
        local i=1
        echo "" >/dev/tty
        echo "=== $title ==="  >/dev/tty
        echo "$prompt" >/dev/tty
        while [[ $i -le $# ]]; do
            local key="${!i}"
            i=$((i + 1))
            local desc="${!i}"
            i=$((i + 1))
            echo "  [$key] $desc" >/dev/tty
        done
        read -r -p "Selecciona [$default_value]: " answer </dev/tty
        echo "${answer:-$default_value}"
    fi
}

show_usage() {
    cat << 'EOF'
Uso:
  sudo ./007_debian-btrfs-installer.sh [opciones]

Opciones:
  --dry-run, --preview   Muestra una simulacion del flujo sin tocar disco
  --text-ui              Fuerza interfaz de texto plano
  --whiptail             Fuerza interfaz visual whiptail
  -h, --help             Muestra esta ayuda
EOF
}

startup_wizard() {
    local action=""

    while true; do
        if [[ "$USE_WHIPTAIL" == "S" ]]; then
            clear
        fi

        action="$(ask_menu "Debian Btrfs Installer" "Seleccione una opcion." "1" \
            "1" "Iniciar instalacion" \
            "2" "Modo prueba (dry-run)" \
            "3" "Ayuda" \
            "4" "Salir")" || {
            echo "EXIT"
            return 0
        }

        # En algunos entornos TTY/whiptail pueden aparecer CR/LF o espacios residuales.
        # Normalizamos para que el case siempre reciba una opcion limpia (1-4).
        action="$(printf '%s' "$action" | tr -d '\r\n' | xargs)"

        case "$action" in
            1)
                echo "INSTALL"
                return 0
                ;;
            2)
                echo "DRYRUN"
                return 0
                ;;
            3)
                if [[ "$USE_WHIPTAIL" == "S" ]]; then
                    ui_textbox_from_text "Ayuda" "$(show_usage)"
                    clear
                else
                    separator
                    show_usage
                    separator
                    read -r -p "Presiona ENTER para volver al menu... " _
                fi
                ;;
            4)
                echo "EXIT"
                return 0
                ;;
            *)
                ui_warn "Opcion invalida"
                ;;
        esac
    done
}

progress_start() {
    PROGRESS_LAST_PCT=-1

    if [[ "$USE_WHIPTAIL" == "S" ]]; then
        coproc PROGRESS_GAUGE { whiptail --title "Instalacion en Progreso" --gauge "Preparando instalacion..." 10 78 0; }
        PROGRESS_GAUGE_FD="${PROGRESS_GAUGE[1]}"
        PROGRESS_WHIPTAIL_ACTIVE="S"
    else
        PROGRESS_WHIPTAIL_ACTIVE="N"
        separator
        echo "PROGRESO DE INSTALACION"
        separator
    fi
}

progress_update() {
    local pct="$1"
    local message="$2"

    (( pct < 0 )) && pct=0
    (( pct > 100 )) && pct=100

    if [[ "$PROGRESS_WHIPTAIL_ACTIVE" == "S" ]]; then
        {
            echo "$pct"
            echo "XXX"
            echo "$message"
            echo "XXX"
        } >&${PROGRESS_GAUGE_FD}
    else
        if [[ "$pct" -ne "$PROGRESS_LAST_PCT" ]]; then
            echo "[$pct%] $message"
            PROGRESS_LAST_PCT="$pct"
        fi
    fi
}

progress_finish() {
    if [[ "$PROGRESS_WHIPTAIL_ACTIVE" == "S" ]]; then
        {
            echo "100"
            echo "XXX"
            echo "Instalacion finalizada"
            echo "XXX"
        } >&${PROGRESS_GAUGE_FD} || true

        eval "exec ${PROGRESS_GAUGE_FD}>&-" || true
        wait "$PROGRESS_GAUGE_PID" 2>/dev/null || true
        PROGRESS_WHIPTAIL_ACTIVE="N"
    fi
}

run_install_stage() {
    local step_index="$1"
    local total_steps="$2"
    local step_label="$3"
    local step_fn="$4"
    local start_pct=$(( ( (step_index - 1) * 100 ) / total_steps ))
    local end_pct=$(( ( step_index * 100 ) / total_steps ))

    progress_update "$start_pct" "[$step_index/$total_steps] $step_label"
    log "Ejecutando etapa $step_index/$total_steps: $step_label"

    if [[ "$PROGRESS_WHIPTAIL_ACTIVE" == "S" ]]; then
        "$step_fn" >>"$LOG_FILE" 2>&1
    else
        "$step_fn"
    fi

    progress_update "$end_pct" "[$step_index/$total_steps] $step_label completado"
}

run_installation_pipeline() {
    local step_labels=(
        "Particionando disco"
        "Formateando particiones"
        "Creando subvolumenes btrfs"
        "Montando estructura"
        "Instalando sistema base"
        "Generando fstab"
        "Configurando sistema base"
        "Configurando repositorios APT"
        "Creando usuario"
        "Instalando kernel y GRUB"
        "Instalando software base"
        "Configurando red"
        "Creando swapfile"
        "Limpieza final"
        "Mostrando resumen final"
    )

    local step_functions=(
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
    )

    local total_steps="${#step_functions[@]}"
    local i

    progress_start

    for i in "${!step_functions[@]}"; do
        run_install_stage "$((i + 1))" "$total_steps" "${step_labels[$i]}" "${step_functions[$i]}"
    done

    progress_finish
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

unmount_disk_partitions() {
    [[ -z "$DISK" ]] && return 0

    while IFS= read -r part; do
        [[ -z "$part" ]] && continue
        swapoff "$part" &>/dev/null || true
        umount "$part" &>/dev/null || true
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

    error "No se pudo desmontar $part. Cierra el explorador de archivos del Live e intenta de nuevo."
}

handle_error() {
    local line="$1"
    echo "❌ ERROR inesperado en línea ${line}. Revisa el log: $LOG_FILE" | tee -a "$LOG_FILE" >&2
    if [[ "$USE_WHIPTAIL" == "S" ]] && [[ -t 1 ]]; then
        whiptail --title "Error" --msgbox "Error inesperado en linea ${line}.\n\nRevisa el log:\n$LOG_FILE" 12 78 || true
    fi
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

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run|--preview)
                DRY_RUN="S"
                ;;
                        --text-ui)
                                UI_MODE="TEXT"
                                ;;
                        --whiptail)
                                UI_MODE="WHIPTAIL"
                                ;;
            -h|--help)
                                show_usage
                exit 0
                ;;
            *)
                error "Opcion no reconocida: $1"
                ;;
        esac
        shift
    done
}

show_dry_run_steps() {
    separator
    echo "MODO PRUEBA (SIN CAMBIOS EN DISCO)"
    separator
    echo ""
    echo "Este modo NO ejecuta comandos destructivos ni instala paquetes."
    echo "Sirve para ver el orden de pantallas y pasos del instalador."
    echo ""
    echo "Flujo que se ejecutaria en instalacion real:"
    echo "  1. check_requirements"
    echo "  2. detect_disks"
    echo "  3. analyze_and_suggest"
    echo "  4. interactive_config"
    echo "  5. partition_disk"
    echo "  6. format_partitions"
    echo "  7. create_subvolumes"
    echo "  8. mount_structure"
    echo "  9. install_base"
    echo " 10. configure_fstab"
    echo " 11. configure_system"
    echo " 12. configure_apt_sources"
    echo " 13. create_user"
    echo " 14. install_kernel_grub"
    echo " 15. install_software"
    echo " 16. configure_network"
    echo " 17. create_swapfile"
    echo " 18. cleanup"
    echo " 19. show_final_summary"
    echo ""
    echo "Comandos criticos que normalmente correria:"
    echo "  - sgdisk / mkfs.fat / mkfs.btrfs"
    echo "  - debootstrap"
    echo "  - chroot ... apt install"
    echo "  - grub-install / update-grub"
    echo ""
    success "Preview completado"
}

wait_dry_run_next_step() {
    local current_step="$1"
    local total_steps="$2"
    local answer=""

    if [[ "$USE_WHIPTAIL" == "S" ]]; then
        if [[ "$DRY_RUN_WHIPTAIL_NEXT" == "S" ]]; then
            return 0
        fi
        return 1
    fi

    if [[ "$current_step" -ge "$total_steps" ]]; then
        read -r -p "Fin del preview. Presiona ENTER para salir... " answer
        return 1
    fi

    while true; do
        read -r -p "ENTER = siguiente paso | q = salir del preview: " answer
        answer="${answer:-}"
        case "${answer,,}" in
            "")
                return 0
                ;;
            q)
                return 1
                ;;
            *)
                echo "Opcion invalida. Usa ENTER o q"
                ;;
        esac
    done
}

show_dry_run_step() {
    local step_number="$1"
    local total_steps="$2"
    local step_name="$3"
    local step_desc="$4"
    local step_cmds="$5"

    if [[ "$USE_WHIPTAIL" == "S" ]]; then
        local msg
        msg="Funcion: ${step_name}\n\nQue haria en modo real:\n  ${step_desc}\n\nComandos clave:\n  ${step_cmds}\n\n(Simulacion: no se ejecuta ningun cambio)"

        if [[ "$step_number" -lt "$total_steps" ]]; then
            if whiptail --title "Modo prueba - Paso ${step_number}/${total_steps}" --yes-button "Siguiente" --no-button "Salir" --yesno "$msg\n\nDeseas continuar al siguiente paso?" 20 78; then
                DRY_RUN_WHIPTAIL_NEXT="S"
            else
                DRY_RUN_WHIPTAIL_NEXT="N"
            fi
        else
            whiptail --title "Modo prueba - Paso ${step_number}/${total_steps}" --msgbox "$msg\n\nUltimo paso del preview." 20 78
            DRY_RUN_WHIPTAIL_NEXT="N"
        fi

        return 0
    fi

    clear
    separator
    echo "MODO PRUEBA - PASO ${step_number}/${total_steps}"
    separator
    echo ""
    echo "Funcion: ${step_name}"
    echo ""
    echo "Que haria en modo real:"
    echo "  ${step_desc}"
    echo ""
    echo "Comandos clave que ejecutaria:"
    echo "  ${step_cmds}"
    echo ""
    echo "(Simulacion: no se ejecuta ningun cambio)"
    echo ""
}

run_dry_run_preview() {
    DISK="$(lsblk -ndpo NAME 2>/dev/null | head -n1 || true)"
    DISK="${DISK:-/dev/sdX}"
    DISK_SIZE_GB=512
    RAM_GB=16
    EFI_SIZE="1G"
    SYSTEM_SIZE="410G"
    CREATE_BACKUP="S"
    SWAP_SIZE="16G"
    HOSTNAME="debian-pc"
    USERNAME="usuario"
    TIMEZONE="America/Argentina/Buenos_Aires"
    LOCALE="es_AR.UTF-8"
    APT_ENABLE_NONFREE="S"
    APT_ENABLE_DEBSRC="N"
    APT_ENABLE_SECURITY="S"
    APT_ENABLE_UPDATES="S"
    INSTALL_NONFREE_FIRMWARE="S"
    ENABLE_POPCON="N"
    SOFTWARE_INSTALL_MODE="POSTBOOT"
    INSTALL_SSH_IN_BASE="S"
    INSTALL_TASKSEL_NOW="N"
    GRUB_BTRFS_INSTALLED="S"

    clear
    separator
    echo "DEBIAN $DEBIAN_RELEASE - INSTALADOR AUTOMATICO"
    echo "btrfs + grub-btrfs"
    echo "Version: $VERSION"
    separator
    echo ""

    show_configuration_summary

    if [[ "$USE_WHIPTAIL" == "S" ]]; then
        if ! whiptail --title "Modo Prueba" --yes-button "Iniciar" --no-button "Volver" --yesno "Iniciar preview paso a paso?" 10 64; then
            return 0
        fi
    else
        read -r -p "Presiona ENTER para iniciar preview paso a paso... " _
    fi

    local total_steps=19
    local step=1

    show_dry_run_step "$step" "$total_steps" "check_requirements" \
        "Valida root, UEFI, internet y herramientas base necesarias." \
        "ping, command -v, apt update, apt install"
    wait_dry_run_next_step "$step" "$total_steps" || return 0
    step=$((step + 1))

    show_dry_run_step "$step" "$total_steps" "detect_disks" \
        "Enumera discos disponibles y muestra advertencias de borrado." \
        "lsblk, findmnt, awk"
    wait_dry_run_next_step "$step" "$total_steps" || return 0
    step=$((step + 1))

    show_dry_run_step "$step" "$total_steps" "analyze_and_suggest" \
        "Calcula sugerencias de particionado, swap, hostname y valores regionales." \
        "lsblk, free, reglas de calculo internas"
    wait_dry_run_next_step "$step" "$total_steps" || return 0
    step=$((step + 1))

    show_dry_run_step "$step" "$total_steps" "interactive_config" \
        "Pide parametros de instalacion y confirma borrado final del disco." \
        "read -p, validaciones y resumen"
    wait_dry_run_next_step "$step" "$total_steps" || return 0
    step=$((step + 1))

    show_dry_run_step "$step" "$total_steps" "partition_disk" \
        "Crea GPT y particiones EFI, SISTEMA y BACKUP (opcional)." \
        "sgdisk, partprobe"
    wait_dry_run_next_step "$step" "$total_steps" || return 0
    step=$((step + 1))

    show_dry_run_step "$step" "$total_steps" "format_partitions" \
        "Formatea EFI en FAT32 y sistema/backup en btrfs." \
        "mkfs.fat, mkfs.btrfs, blkid"
    wait_dry_run_next_step "$step" "$total_steps" || return 0
    step=$((step + 1))

    show_dry_run_step "$step" "$total_steps" "create_subvolumes" \
        "Crea subvolumenes btrfs (@, @home, @snapshots, etc.)." \
        "mount, btrfs subvolume create, umount"
    wait_dry_run_next_step "$step" "$total_steps" || return 0
    step=$((step + 1))

    show_dry_run_step "$step" "$total_steps" "mount_structure" \
        "Monta subvolumenes y la particion EFI en /mnt." \
        "mount -o subvol=..., mkdir -p"
    wait_dry_run_next_step "$step" "$total_steps" || return 0
    step=$((step + 1))

    show_dry_run_step "$step" "$total_steps" "install_base" \
        "Instala Debian base con debootstrap." \
        "debootstrap --arch=amd64"
    wait_dry_run_next_step "$step" "$total_steps" || return 0
    step=$((step + 1))

    show_dry_run_step "$step" "$total_steps" "configure_fstab" \
        "Genera /etc/fstab con UUID y subvolumenes." \
        "cat > /mnt/etc/fstab"
    wait_dry_run_next_step "$step" "$total_steps" || return 0
    step=$((step + 1))

    show_dry_run_step "$step" "$total_steps" "configure_system" \
        "Configura hostname, hosts, timezone y locale." \
        "echo, cat >, ln -sf"
    wait_dry_run_next_step "$step" "$total_steps" || return 0
    step=$((step + 1))

    show_dry_run_step "$step" "$total_steps" "configure_apt_sources" \
        "Genera sources.list segun respuestas (main, non-free, security, updates)." \
        "cat/echo > /mnt/etc/apt/sources.list"
    wait_dry_run_next_step "$step" "$total_steps" || return 0
    step=$((step + 1))

    show_dry_run_step "$step" "$total_steps" "create_user" \
        "Hace bind mounts, instala locales/sudo, crea usuario y bloquea root." \
        "mount --rbind, chroot apt, useradd, chpasswd, passwd -l"
    wait_dry_run_next_step "$step" "$total_steps" || return 0
    step=$((step + 1))

    show_dry_run_step "$step" "$total_steps" "install_kernel_grub" \
        "Instala kernel, firmware, GRUB UEFI y grub-btrfs si disponible." \
        "chroot apt install, grub-install, update-grub"
    wait_dry_run_next_step "$step" "$total_steps" || return 0
    step=$((step + 1))

    show_dry_run_step "$step" "$total_steps" "install_software" \
        "Instala software base segun modo AUTO/INTERACTIVE/POSTBOOT y ajusta SSH." \
        "tasksel, apt install, sshd_config.d"
    wait_dry_run_next_step "$step" "$total_steps" || return 0
    step=$((step + 1))

    show_dry_run_step "$step" "$total_steps" "configure_network" \
        "Configura DHCP con systemd-networkd y resolucion DNS." \
        "systemctl enable, archivos .network, resolv.conf"
    wait_dry_run_next_step "$step" "$total_steps" || return 0
    step=$((step + 1))

    show_dry_run_step "$step" "$total_steps" "create_swapfile" \
        "Crea swapfile en /var/swap con COW deshabilitado." \
        "truncate, chattr +C, dd, mkswap"
    wait_dry_run_next_step "$step" "$total_steps" || return 0
    step=$((step + 1))

    show_dry_run_step "$step" "$total_steps" "cleanup" \
        "Ejecuta limpieza final y desmonta estructura de instalacion." \
        "update-grub, umount -R"
    wait_dry_run_next_step "$step" "$total_steps" || return 0
    step=$((step + 1))

    show_dry_run_step "$step" "$total_steps" "show_final_summary" \
        "Muestra resumen final, UUID de backup y proximos pasos post-instalacion." \
        "echo/log del reporte final"

    if [[ "$USE_WHIPTAIL" == "S" ]]; then
        whiptail --title "Modo Prueba" --msgbox "Preview paso a paso completado." 10 64
    else
        echo ""
        success "Preview paso a paso completado"
        read -r -p "Presiona ENTER para salir... " _
    fi
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
    
    if [[ "$USE_WHIPTAIL" != "S" ]]; then
        separator
        echo "DISCOS DISPONIBLES:"
        echo ""
    fi
    
    for i in "${!disks[@]}"; do
        local idx=$((i + 1))
        if [[ "$USE_WHIPTAIL" != "S" ]]; then
            echo "[$idx] ${disks[$i]} (${disk_info[$i]})"
        fi

        if [[ -n "$live_root_disk" ]] && [[ "${disks[$i]}" == "/dev/$live_root_disk" ]]; then
            if [[ "$USE_WHIPTAIL" != "S" ]]; then
                echo "    ⚠️  Este parece ser el disco desde el que corre el sistema live actual"
            fi
        fi
        
        if lsblk -n "${disks[$i]}" | grep -q part; then
            if [[ "$USE_WHIPTAIL" != "S" ]]; then
                echo "    ⚠️  Contiene particiones:"
                lsblk -ln -o NAME,SIZE,FSTYPE,LABEL,TYPE "${disks[$i]}" 2>/dev/null | awk '$5=="part"{printf "    %s %s %s %s\n",$1,$2,$3,$4}' || warning "No se pudieron listar las particiones de ${disks[$i]}"
            fi
        fi
    done
    if [[ "$USE_WHIPTAIL" != "S" ]]; then
        echo ""
    fi
    
    local selection=""
    while true; do
        if [[ "$USE_WHIPTAIL" == "S" ]]; then
            local menu_options=()
            for i in "${!disks[@]}"; do
                local idx=$((i + 1))
                menu_options+=("$idx" "${disks[$i]} (${disk_info[$i]})")
            done
            selection="$(ask_menu "Seleccion de Disco" "Selecciona el disco destino" "1" "${menu_options[@]}")" || error "Seleccion de disco cancelada"
        else
            read -r -p "Selecciona disco [1-${#disks[@]}]: " selection
        fi

        if [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -le ${#disks[@]} ]]; then
            local candidate_disk="${disks[$((selection - 1))]}"

            if lsblk -n "$candidate_disk" | grep -q part; then
                echo ""
                warning "El disco $candidate_disk ya contiene particiones y serán ELIMINADAS."
                local wipe_confirm=""
                while true; do
                    wipe_confirm="$(ask_yes_no "Confirmar Borrado" "El disco $candidate_disk contiene particiones y se borrara por completo. Continuar?" "N")"
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
            EFI_SIZE="$(ask_input "Particion EFI" "Tamaño de EFI (ej: 1G)" "$SUGGESTED_EFI")" || error "Configuracion cancelada"
            if is_valid_size_gib "$EFI_SIZE"; then
                break
            fi
            ui_warn "Tamaño EFI invalido. Usa formato entero en GiB, por ejemplo: 1G"
        done
        
        echo ""
        echo "Partición Sistema (btrfs - sistema operativo):"
        echo "  Sugerencia: ${SUGGESTED_SYSTEM_GB}GB (${SUGGESTED_SYSTEM_PCT}% del disco)"
        while true; do
            SYSTEM_SIZE="$(ask_input "Particion Sistema" "Tamaño de sistema (ej: 80G)" "${SUGGESTED_SYSTEM_GB}G")" || error "Configuracion cancelada"
            if ! is_valid_size_gib "$SYSTEM_SIZE"; then
                ui_warn "Tamaño de sistema invalido. Usa formato entero en GiB, por ejemplo: 80G"
                continue
            fi

            SYSTEM_SIZE_NUM="${SYSTEM_SIZE%G}"
            if [[ "$SYSTEM_SIZE_NUM" -lt 16 ]]; then
                ui_warn "La particion de sistema debe ser al menos 16G"
                continue
            fi
            if [[ "$SYSTEM_SIZE_NUM" -ge $((DISK_SIZE_GB - 1)) ]]; then
                ui_warn "El tamaño del sistema deja sin espacio suficiente para EFI/backup"
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
            CREATE_BACKUP="$(ask_yes_no "Particion Backup" "Crear particion backup?" "S")"
            if [[ -n "$CREATE_BACKUP" ]]; then
                break
            fi
            ui_warn "Respuesta invalida. Usa Si o No"
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
            SWAP_SIZE="$(ask_input "Swap" "Tamaño de swap (ej: 8G)" "$SUGGESTED_SWAP")" || error "Configuracion cancelada"
            if is_valid_size_gib "$SWAP_SIZE"; then
                break
            fi
            ui_warn "Tamaño de swap invalido. Usa formato entero en GiB, por ejemplo: 8G"
        done
        
        # SISTEMA
        echo ""
        separator
        echo "CONFIGURACIÓN DEL SISTEMA"
        separator
        echo ""
        HOSTNAME="$(ask_input "Sistema" "Hostname" "$SUGGESTED_HOSTNAME")" || error "Configuracion cancelada"
        
        USERNAME="$(ask_input "Sistema" "Nombre de usuario" "usuario")" || error "Configuracion cancelada"
        
        while true; do
            USER_PASSWORD="$(ask_password "Password" "Password para $USERNAME")" || error "Configuracion cancelada"
            if [[ -z "$USER_PASSWORD" ]]; then
                ui_warn "Password no puede estar vacio"
                continue
            fi
            USER_PASSWORD2="$(ask_password "Password" "Repetir password")" || error "Configuracion cancelada"
            if [[ "$USER_PASSWORD" == "$USER_PASSWORD2" ]]; then
                break
            fi
            ui_warn "Los passwords no coinciden"
        done
        
        # REGIONAL
        echo ""
        TIMEZONE="$(ask_input "Regional" "Zona horaria" "$SUGGESTED_TIMEZONE")" || error "Configuracion cancelada"
        
        LOCALE="$(ask_input "Regional" "Locale" "$SUGGESTED_LOCALE")" || error "Configuracion cancelada"

        # PREGUNTAS NO CRÍTICAS (ESTILO INSTALADOR DEBIAN)
        echo ""
        separator
        echo "PREGUNTAS NO CRÍTICAS"
        separator
        echo "Si presionas ENTER, se usa la sugerencia."
        echo ""

        while true; do
            APT_ENABLE_NONFREE="$(ask_yes_no "Repositorios" "Habilitar software no libre (contrib/non-free/non-free-firmware)?" "S")"
            [[ -n "$APT_ENABLE_NONFREE" ]] && break
            ui_warn "Respuesta invalida"
        done

        while true; do
            APT_ENABLE_SECURITY="$(ask_yes_no "Repositorios" "Habilitar repositorio security?" "S")"
            [[ -n "$APT_ENABLE_SECURITY" ]] && break
            ui_warn "Respuesta invalida"
        done

        while true; do
            APT_ENABLE_UPDATES="$(ask_yes_no "Repositorios" "Habilitar repositorio updates?" "S")"
            [[ -n "$APT_ENABLE_UPDATES" ]] && break
            ui_warn "Respuesta invalida"
        done

        while true; do
            APT_ENABLE_DEBSRC="$(ask_yes_no "Repositorios" "Incluir repositorios de codigo fuente (deb-src)?" "N")"
            [[ -n "$APT_ENABLE_DEBSRC" ]] && break
            ui_warn "Respuesta invalida"
        done

        APT_PROXY="$(ask_input "APT" "Proxy HTTP para APT (vacio = sin proxy)" "")" || error "Configuracion cancelada"

        while true; do
            INSTALL_NONFREE_FIRMWARE="$(ask_yes_no "Firmware" "Instalar firmware no libre (si aplica)?" "S")"
            [[ -n "$INSTALL_NONFREE_FIRMWARE" ]] && break
            ui_warn "Respuesta invalida"
        done

        while true; do
            ENABLE_POPCON="$(ask_yes_no "Estadisticas" "Participar en popularity-contest?" "N")"
            [[ -n "$ENABLE_POPCON" ]] && break
            ui_warn "Respuesta invalida"
        done

        echo ""
        echo "Modo de software base:"
        echo "  [1] AUTO        -> instala standard (+SSH opcional)"
        echo "  [2] INTERACTIVE -> abre tasksel para elegir"
        echo "  [3] POSTBOOT    -> deja software para después del primer arranque"
        while true; do
            SOFTWARE_INSTALL_MODE="$(ask_menu "Software Base" "Selecciona modo" "3" \
                "1" "AUTO - instala standard (+SSH opcional)" \
                "2" "INTERACTIVE - abre tasksel para elegir" \
                "3" "POSTBOOT - dejar software para despues")" || error "Configuracion cancelada"
            SOFTWARE_INSTALL_MODE="$(normalize_software_mode "$SOFTWARE_INSTALL_MODE")"
            [[ -n "$SOFTWARE_INSTALL_MODE" ]] && break
            ui_warn "Opcion invalida. Usa 1, 2 o 3"
        done

        while true; do
            INSTALL_SSH_IN_BASE="$(ask_yes_no "SSH" "Instalar SSH en la base?" "S")"
            [[ -n "$INSTALL_SSH_IN_BASE" ]] && break
            ui_warn "Respuesta invalida"
        done

        while true; do
            INSTALL_TASKSEL_NOW="$(ask_yes_no "Tasksel" "Instalar paquete tasksel ahora?" "N")"
            [[ -n "$INSTALL_TASKSEL_NOW" ]] && break
            ui_warn "Respuesta invalida"
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
        choice="$(ask_menu "Confirmacion" "Selecciona una opcion" "C" \
            "C" "Confirmar y continuar con la instalacion" \
            "M" "Modificar configuracion" \
            "S" "Salir sin instalar")" || error "Instalacion cancelada por el usuario"
        choice="${choice:-C}"
        
        case "${choice^^}" in
            C)
                separator
                echo "CONFIRMACIÓN FINAL DE SEGURIDAD"
                separator
                echo ""
                echo "Vas a BORRAR completamente: $DISK"
                disk_confirm="$(ask_input "Confirmacion Final" "Escribe exactamente '$DISK' para continuar" "")" || error "Instalacion cancelada por el usuario"
                if [[ "$disk_confirm" == "$DISK" ]]; then
                    config_valid=true
                else
                    ui_warn "Confirmacion incorrecta. Volviendo a configuracion."
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
    if [[ "$USE_WHIPTAIL" == "S" ]]; then
        local system_num backup_calc summary_text
        system_num=$(echo "$SYSTEM_SIZE" | sed 's/[^0-9]//g')
        backup_calc=$((DISK_SIZE_GB - system_num - 1))

        summary_text="RESUMEN DE CONFIGURACION

HARDWARE
Disco: $DISK
Modelo: $(lsblk -ndo MODEL "$DISK" 2>/dev/null | xargs)
Capacidad: ${DISK_SIZE_GB}GB
RAM: ${RAM_GB}GB

PARTICIONES
EFI: $EFI_SIZE (/boot/efi)
SISTEMA: $SYSTEM_SIZE (btrfs, zstd:1)
"

        if [[ "$CREATE_BACKUP" == "S" ]]; then
            summary_text+="BACKUP: ${backup_calc}GB (resto del disco)\n"
        else
            summary_text+="BACKUP: no\n"
        fi

        summary_text+="\nSISTEMA\nDebian: $DEBIAN_RELEASE\nHostname: $HOSTNAME\nUsuario: $USERNAME (sudo)\n"
        summary_text+="\nREGIONAL\nTimezone: $TIMEZONE\nLocale: $LOCALE\n"
        summary_text+="\nSOFTWARE\nModo: $SOFTWARE_INSTALL_MODE\nSSH base: $INSTALL_SSH_IN_BASE\n"
        summary_text+="Repos: non-free=$APT_ENABLE_NONFREE, security=$APT_ENABLE_SECURITY, updates=$APT_ENABLE_UPDATES, deb-src=$APT_ENABLE_DEBSRC\n"
        summary_text+="\nATENCION: TODOS LOS DATOS EN $DISK SERAN ELIMINADOS"

        ui_textbox_from_text "Resumen de Configuracion" "$summary_text"
        return 0
    fi

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
    if [[ "$GRUB_BTRFS_INSTALLED" == "S" ]]; then
        echo "  ✓ GRUB + grub-btrfs"
    else
        echo "  ✓ GRUB (grub-btrfs no disponible en repos actuales)"
    fi
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

    unmount_disk_partitions
    
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

    unmount_disk_partitions
    ensure_partition_unmounted "$EFI_PART"
    ensure_partition_unmounted "$SYSTEM_PART"
    if [[ "$CREATE_BACKUP" == "S" ]]; then
        ensure_partition_unmounted "$BACKUP_PART"
    fi
    
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
    mkdir -p /mnt/dev/pts
    mount -t devpts devpts /mnt/dev/pts &>/dev/null || true
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
    chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=DEBIAN --no-nvram
    chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=DEBIAN --removable
    chroot /mnt apt install -y btrfs-progs
    
    if chroot /mnt apt-cache show grub-btrfs &>/dev/null; then
        chroot /mnt apt install -y grub-btrfs
        GRUB_BTRFS_INSTALLED="S"
    else
        warning "Paquete grub-btrfs no disponible en repos; intentando instalación desde GitHub"
        chroot /mnt apt install -y git make
        if chroot /mnt bash -lc 'set -e; tmpdir=$(mktemp -d); cd "$tmpdir"; git clone https://github.com/Antynea/grub-btrfs.git; cd grub-btrfs; make install; cd /; rm -rf "$tmpdir"'; then
            GRUB_BTRFS_INSTALLED="S"
        else
            warning "No se pudo instalar grub-btrfs desde GitHub"
            GRUB_BTRFS_INSTALLED="N"
        fi
    fi

    if [[ "$GRUB_BTRFS_INSTALLED" == "S" ]]; then
        mkdir -p /mnt/etc/default/grub-btrfs
        cat > /mnt/etc/default/grub-btrfs/config << 'EOF'
GRUB_BTRFS_SUBMENUNAME="Debian Snapshots"
GRUB_BTRFS_LIMIT="10"
GRUB_BTRFS_SHOW_SNAPSHOTS_FOUND="true"
GRUB_BTRFS_SNAPSHOT_KERNEL_PARAMETERS="systemd.volatile=state"
EOF

        chroot /mnt systemctl enable grub-btrfsd.service || true
    fi
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

    # En algunas instalaciones mínimas systemd-resolved no viene instalado
    chroot /mnt apt install -y systemd-resolved &>/dev/null || true
    if chroot /mnt systemctl list-unit-files 2>/dev/null | grep -q '^systemd-resolved\.service'; then
        chroot /mnt systemctl enable systemd-resolved
        ln -sf /run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf
    else
        warning "systemd-resolved no disponible; se deja resolv.conf estático"
        cat > /mnt/etc/resolv.conf << 'EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF
    fi
    
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
    if [[ "$USE_WHIPTAIL" == "S" ]]; then
        local final_text
        final_text="INSTALACION COMPLETADA\n\nDebian: $DEBIAN_RELEASE\nHostname: $HOSTNAME\nUsuario: $USERNAME\n"
        final_text+="\nParticiones:\n$EFI_PART -> /boot/efi\n$SYSTEM_PART -> /\n"
        if [[ "$CREATE_BACKUP" == "S" ]]; then
            final_text+="$BACKUP_PART -> backup\nUUID backup: $BACKUP_UUID\n"
        fi
        final_text+="\nLog: $LOG_FILE\n\nProximos pasos: snapper, btrbk y software post-boot segun corresponda."
        ui_textbox_from_text "Instalacion Completada" "$final_text"
        return 0
    fi

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
    if [[ "$GRUB_BTRFS_INSTALLED" == "S" ]]; then
        echo "  ✓ Kernel + GRUB + grub-btrfs"
    else
        echo "  ✓ Kernel + GRUB"
        echo "  ⚠ grub-btrfs no se instaló (no disponible en repos actuales)"
    fi
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
    parse_args "$@"
    setup_ui

    if [[ "$DRY_RUN" != "S" ]]; then
        local wizard_action=""
        wizard_action="$(startup_wizard)"
        case "$wizard_action" in
            INSTALL)
                ;;
            DRYRUN)
                DRY_RUN="S"
                ;;
            EXIT)
                clear
                echo "Instalador finalizado por el usuario"
                exit 0
                ;;
            *)
                error "Accion inicial invalida: $wizard_action"
                ;;
        esac
    fi

    if [[ "$DRY_RUN" == "S" ]]; then
        run_dry_run_preview
        exit 0
    fi

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

    run_installation_pipeline
    
    cleanup_mounts
    
    echo ""
    read -p "Presiona ENTER para reiniciar..." dummy
    reboot
}

main "$@"
