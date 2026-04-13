#!/usr/bin/env bash
set -u

if [[ "${EUID}" -ne 0 ]]; then
   echo "Run as root: sudo $0"
   exit 1
fi

print_section() {
   echo
   echo "============================================================"
   echo " $1"
   echo "============================================================"
}

print_section "Backup Health Report"
date

print_section "Mount Context"
findmnt /
findmnt /home

print_section "Services"
systemctl is-active snapper-cleanup.timer >/dev/null 2>&1 && echo "snapper-cleanup.timer: active" || echo "snapper-cleanup.timer: inactive"
systemctl is-active btrbk.timer >/dev/null 2>&1 && echo "btrbk.timer: active" || echo "btrbk.timer: inactive"
systemctl is-active grub-btrfsd >/dev/null 2>&1 && echo "grub-btrfsd: active" || echo "grub-btrfsd: inactive"

print_section "Local Snapshots (last 8)"
snapper -c root list | tail -8 || echo "snapper not available"

mounted_here=0
if mountpoint -q /mnt/backup; then
   echo
   echo "/mnt/backup already mounted"
else
   if mount /mnt/backup 2>/dev/null; then
      mounted_here=1
      echo
      echo "/mnt/backup mounted temporarily"
   else
      echo
      echo "could not mount /mnt/backup"
   fi
fi

if mountpoint -q /mnt/backup; then
   print_section "Recovery Snapshots (last 10)"
   if [[ -d /mnt/backup/snapshots ]]; then
      ls -lt /mnt/backup/snapshots | head -10
   else
      echo "/mnt/backup/snapshots not found"
   fi

   print_section "Recovery Filesystem Usage"
   df -h /mnt/backup
fi

print_section "Last btrbk.service Log (last 30 lines)"
journalctl -u btrbk.service -n 30 --no-pager || echo "journalctl unavailable"

if [[ "$mounted_here" -eq 1 ]]; then
   if umount /mnt/backup 2>/dev/null; then
      echo
      echo "/mnt/backup unmounted (temporary mount cleaned up)"
   else
      echo
      echo "warning: could not unmount /mnt/backup"
   fi
fi

print_section "Done"
