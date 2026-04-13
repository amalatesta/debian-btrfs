#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPORT_DIR="${BASE_DIR}/reportes"
TS="$(date +%Y%m%d-%H%M%S)"
REPORT_FILE="${REPORT_DIR}/reporte-${TS}.txt"

mkdir -p "${REPORT_DIR}"

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

append_section() {
  local title="$1"
  {
    echo
    echo "============================================================"
    echo "$title"
    echo "============================================================"
  } >>"${REPORT_FILE}"
}

run_cmd() {
  local label="$1"
  shift
  {
    echo
    echo "> $label"
    "$@"
  } >>"${REPORT_FILE}" 2>&1 || {
    {
      echo
      echo "[WARN] Command failed: $label"
    } >>"${REPORT_FILE}"
  }
}

{
  echo "Debian BTRFS checklist report"
  echo "Generated: $(date -Is)"
  echo "Host: $(hostname)"
  echo "User: ${USER:-unknown}"
} >"${REPORT_FILE}"

append_section "System"
run_cmd "uname -a" uname -a
run_cmd "lsblk -f" lsblk -f

append_section "Mounts and subvolumes"
if have_cmd findmnt; then
  run_cmd "findmnt /" findmnt /
  run_cmd "findmnt /home" findmnt /home
fi
if have_cmd btrfs; then
  run_cmd "btrfs subvolume show /" sudo btrfs subvolume show /
  run_cmd "btrfs subvolume show /home" sudo btrfs subvolume show /home
fi

append_section "fstab"
run_cmd "grep btrfs/subvol in /etc/fstab" grep -E "\\s/\\s|\\s/home\\s|/mnt/backup|/mnt/btrfs-root|subvol=|@rootfs" /etc/fstab

append_section "Services"
if have_cmd systemctl; then
  run_cmd "systemctl is-enabled snapper-cleanup.timer" systemctl is-enabled snapper-cleanup.timer
  run_cmd "systemctl is-active snapper-cleanup.timer" systemctl is-active snapper-cleanup.timer
  run_cmd "systemctl is-enabled btrbk.timer" systemctl is-enabled btrbk.timer
  run_cmd "systemctl is-active btrbk.timer" systemctl is-active btrbk.timer
  run_cmd "systemctl is-enabled grub-btrfsd" systemctl is-enabled grub-btrfsd
  run_cmd "systemctl is-active grub-btrfsd" systemctl is-active grub-btrfsd
fi

append_section "Snapshots and backups"
if have_cmd snapper; then
  run_cmd "snapper -c root list (last 10)" bash -lc "sudo snapper -c root list | tail -n 10"
fi
if have_cmd btrbk; then
  run_cmd "btrbk list snapshots" sudo btrbk list snapshots
fi

append_section "Quick checks"
{
  echo
  if grep -Eq "^[[:space:]]*[^#].*@rootfs" /etc/fstab; then
    echo "[FAIL] /etc/fstab still contains @rootfs"
  else
    echo "[OK] /etc/fstab does not contain @rootfs"
  fi

  if grep -Eq "^[^#].*/mnt/backup.*noauto" /etc/fstab; then
    echo "[OK] /mnt/backup is configured with noauto"
  else
    echo "[WARN] /mnt/backup does not seem to use noauto"
  fi
} >>"${REPORT_FILE}"

echo "Report created: ${REPORT_FILE}"
