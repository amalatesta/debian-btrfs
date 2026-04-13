#!/usr/bin/env bash
# =============================================================================
# btrfs-rename-subvols.sh
#
# Ejecutar desde Rescue Mode (como root, sin sudo) después de instalar Debian.
# Renombra @rootfs → @ y crea @home, luego mueve el contenido de /home.
#
# Uso:
#   bash btrfs-rename-subvols.sh [DEVICE]
#
# Ejemplos:
#   bash btrfs-rename-subvols.sh /dev/nvme0n1p2   ← NVMe (por defecto)
#   bash btrfs-rename-subvols.sh /dev/sda2         ← SATA
# =============================================================================

set -euo pipefail

# ─── Colores ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERR]${NC}   $*"; exit 1; }

# ─── Parámetros ──────────────────────────────────────────────────────────────
DEVICE="${1:-/dev/nvme0n1p2}"
MNT="/mnt/btrfs"

# ─── Verificaciones previas ───────────────────────────────────────────────────
[[ "$(id -u)" -eq 0 ]] || error "Ejecutar como root (estás en Rescue Mode)."
[[ -b "$DEVICE" ]]     || error "Dispositivo $DEVICE no existe o no es un bloque."

# ─── Paso 1: Montar partición Btrfs en la raíz real (subvolid=5) ─────────────
info "Montando $DEVICE en $MNT (subvolid=5)..."
mkdir -p "$MNT"
umount "$MNT" 2>/dev/null || true
mount -o subvolid=5 "$DEVICE" "$MNT"

# ─── Paso 2: Verificar estado actual ─────────────────────────────────────────
info "Subvolúmenes actuales en $DEVICE:"
btrfs subvolume list "$MNT"
echo ""

if [[ -d "$MNT/@" && ! -d "$MNT/@rootfs" ]]; then
    warn "Ya existe @ y no existe @rootfs. Nada que renombrar."
    btrfs subvolume list "$MNT"
    umount "$MNT"
    exit 0
fi

[[ -d "$MNT/@rootfs" ]] || error "No se encontró @rootfs en $DEVICE. Verificar que la partición sea correcta."

# ─── Paso 3: Renombrar @rootfs → @ ───────────────────────────────────────────
info "Renombrando @rootfs → @..."
mv "$MNT/@rootfs" "$MNT/@"

# Verificar que quedó bien
if [[ ! -d "$MNT/@" ]]; then
    error "El renombrado falló. No existe @ en $MNT."
fi
if [[ -d "$MNT/@rootfs" ]]; then
    error "@rootfs sigue existiendo. El renombrado no fue completo."
fi
info "Renombrado OK: @ presente, @rootfs eliminado."

# ─── Paso 4: Crear @home si no existe ────────────────────────────────────────
if [[ -d "$MNT/@home" ]]; then
    warn "@home ya existe, se omite la creación."
else
    info "Creando subvolumen @home..."
    btrfs subvolume create "$MNT/@home"
    info "@home creado."
fi

# ─── Paso 5: Mover contenido de /home al subvolumen @home ────────────────────
HOME_SRC="$MNT/@/home"
HOME_DST="$MNT/@home"

if [[ -n "$(ls -A "$HOME_SRC" 2>/dev/null)" ]]; then
    info "Moviendo contenido de $HOME_SRC → $HOME_DST..."
    mv "$HOME_SRC"/* "$HOME_DST/" 2>/dev/null || true
    info "Movimiento completado."
else
    warn "$HOME_SRC está vacío, nada que mover."
fi

# ─── Paso 6: Verificación final ──────────────────────────────────────────────
echo ""
info "─── Verificación final ──────────────────────────────────────────────────"
info "Contenido de $MNT:"
ls -la "$MNT/"

echo ""
info "Subvolúmenes en $DEVICE:"
btrfs subvolume list "$MNT"

echo ""
info "Contenido de @home:"
ls "$HOME_DST/" 2>/dev/null || warn "@home vacío (puede ser normal si no había usuarios)."

info "Contenido de @/home (debe estar vacío):"
ls "$HOME_SRC/" 2>/dev/null || true

# ─── Desmontar ───────────────────────────────────────────────────────────────
umount "$MNT"
echo ""
info "Listo. Ahora continuar con:"
echo "  - Sección 3.6: actualizar /etc/fstab"
echo "  - Sección 3.7: reinstalar GRUB (chroot)"
