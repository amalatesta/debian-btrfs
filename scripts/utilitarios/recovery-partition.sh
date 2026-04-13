#!/usr/bin/env bash
set -u

usage() {
   echo "Usage: $0 {status|mount|umount|ro|rw}"
}

if [[ "${EUID}" -ne 0 ]]; then
   echo "Run as root: sudo $0 <action>"
   exit 1
fi

action="${1:-status}"

case "$action" in
   status)
      if mountpoint -q /mnt/backup; then
         echo "/mnt/backup is mounted"
         findmnt /mnt/backup
      else
         echo "/mnt/backup is unmounted"
      fi
      ;;
   mount)
      if mountpoint -q /mnt/backup; then
         echo "/mnt/backup already mounted"
      else
         mount /mnt/backup && echo "/mnt/backup mounted"
      fi
      ;;
   umount)
      if mountpoint -q /mnt/backup; then
         umount /mnt/backup && echo "/mnt/backup unmounted"
      else
         echo "/mnt/backup already unmounted"
      fi
      ;;
   ro)
      if mountpoint -q /mnt/backup; then
         mount -o remount,ro /mnt/backup && echo "/mnt/backup remounted read-only"
      else
         echo "/mnt/backup is not mounted"
      fi
      ;;
   rw)
      if mountpoint -q /mnt/backup; then
         mount -o remount,rw /mnt/backup && echo "/mnt/backup remounted read-write"
      else
         echo "/mnt/backup is not mounted"
      fi
      ;;
   *)
      usage
      exit 1
      ;;
esac
