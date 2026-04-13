#!/usr/bin/env bash
set -euo pipefail

usage() {
   cat <<'EOF'
Usage:
  sudo scripts/utilitarios/snapshot-compare.sh --mode snapper --from ID [--to ID] [--show-diff]
  sudo scripts/utilitarios/snapshot-compare.sh --mode btrbk --backup-snapshot NAME
  sudo scripts/utilitarios/snapshot-compare.sh --mode usb-btrfs --device /dev/sdX1 --usb-snapshot NAME
  sudo scripts/utilitarios/snapshot-compare.sh --mode usb-stream --device /dev/sdX1 --stream-name NAME.btrfs-stream

Modes:
  snapper     Compare Snapper snapshots using snapper status/diff.
  btrbk       Compare a btrbk snapshot from /mnt/backup/snapshots against current /.
  usb-btrfs   Compare a Btrfs snapshot stored on USB against current /.
  usb-stream  Compare a .btrfs-stream stored on USB against current /.

Options:
  --mode MODE               Comparison mode.
  --from ID                 Source Snapper snapshot ID.
  --to ID                   Target Snapper snapshot ID (default: 0 = current system).
  --show-diff               Also show snapper diff for snapper mode.
  --backup-snapshot NAME    Snapshot name under /mnt/backup/snapshots/.
  --device DEV              USB partition device.
  --usb-snapshot NAME       Snapshot name under USB snapshots/.
  --stream-name NAME        Stream file name under USB btrfs-streams/.
  --mountpoint PATH         Temporary mountpoint for USB (default: /mnt/usb).
  -h, --help                Show this help.
EOF
}

require_root() {
   if [[ "${EUID}" -ne 0 ]]; then
      echo "Run as root: sudo $0 ..."
      exit 1
   fi
}

require_cmds() {
   local missing=0
   local cmd
   for cmd in diff findmnt mount umount lsblk snapper btrfs sha256sum; do
      if ! command -v "$cmd" >/dev/null 2>&1; then
         echo "Missing command: $cmd"
         missing=1
      fi
   done
   if [[ "$missing" -ne 0 ]]; then
      exit 1
   fi
}

print_section() {
   echo
   echo "============================================================"
   echo " $1"
   echo "============================================================"
}

cleanup() {
   if [[ -n "${RECEIVE_SUBVOL:-}" && -d "${RECEIVE_SUBVOL:-}" ]]; then
      btrfs subvolume delete "$RECEIVE_SUBVOL" >/dev/null 2>&1 || true
   fi
   if [[ -n "${RECEIVE_PARENT:-}" && -d "${RECEIVE_PARENT:-}" ]]; then
      rmdir "$RECEIVE_PARENT" >/dev/null 2>&1 || true
   fi
   if [[ "${USB_MOUNTED_HERE:-0}" -eq 1 ]] && mountpoint -q "$MOUNTPOINT"; then
      umount "$MOUNTPOINT" >/dev/null 2>&1 || true
   fi
   if [[ "${BACKUP_MOUNTED_HERE:-0}" -eq 1 ]] && mountpoint -q /mnt/backup; then
      umount /mnt/backup >/dev/null 2>&1 || true
   fi
}

compare_dirs_summary() {
   local source_dir="$1"
   local source_label="$2"
   local diff_rc
   local diff_out diff_err
   local diff_lines=()
   local err_lines=()
   local exclude_args=(
      --exclude=.snapshots
      --exclude=proc
      --exclude=sys
      --exclude=dev
      --exclude=run
      --exclude=tmp
      --exclude=mnt
      --exclude=media
      --exclude=lost+found
      --exclude=swapfile
   )

   if [[ ! -d "$source_dir" ]]; then
      echo "Source directory not found: $source_dir"
      return 1
   fi

   print_section "Comparison"
   echo "Source : $source_label"
   echo "Target : current root /"
   echo "Method : diff -qr (summary only)"
   echo "Excludes: .snapshots proc sys dev run tmp mnt media lost+found swapfile"

   print_section "Summary Differences"
   diff_out="$(mktemp)"
   diff_err="$(mktemp)"
   diff -qr --no-dereference "${exclude_args[@]}" "$source_dir" / >"$diff_out" 2>"$diff_err" || diff_rc=$?
   diff_rc="${diff_rc:-0}"

   mapfile -t diff_lines < "$diff_out"
   mapfile -t err_lines < "$diff_err"
   rm -f "$diff_out" "$diff_err"

   if (( ${#diff_lines[@]} > 0 )); then
      printf '%s\n' "${diff_lines[@]}"
   fi

   case "$diff_rc" in
      0)
         echo "No differences found in the compared paths."
         ;;
      1)
         echo
         echo "Differences were found and listed above."
         ;;
      2)
         echo
         echo "Partial comparison completed: diff found paths that could not be compared on the live system."
         if (( ${#err_lines[@]} > 0 )); then
            print_section "Comparison Warnings"
            printf '%s\n' "${err_lines[@]}"
         fi
         ;;
      *)
         echo
         echo "diff returned unexpected code: $diff_rc"
         if (( ${#err_lines[@]} > 0 )); then
            printf '%s\n' "${err_lines[@]}"
         fi
         return "$diff_rc"
         ;;
   esac

   return 0
}

mount_backup_if_needed() {
   BACKUP_MOUNTED_HERE=0
   if mountpoint -q /mnt/backup; then
      return 0
   fi
   mount /mnt/backup
   BACKUP_MOUNTED_HERE=1
}

mount_usb_if_needed() {
   USB_MOUNTED_HERE=0
   mkdir -p "$MOUNTPOINT"
   if mountpoint -q "$MOUNTPOINT"; then
      return 0
   fi
   mount "$DEVICE" "$MOUNTPOINT"
   USB_MOUNTED_HERE=1
}

receive_stream_to_temp() {
   local stream_path="$1"
   RECEIVE_PARENT="/golden-imports/receive-$$"
   mkdir -p /golden-imports
   mkdir -p "$RECEIVE_PARENT"

   btrfs receive "$RECEIVE_PARENT" < "$stream_path" >/dev/null
   RECEIVE_SUBVOL="$(find "$RECEIVE_PARENT" -mindepth 1 -maxdepth 1 -type d | head -1)"
   if [[ -z "$RECEIVE_SUBVOL" || ! -d "$RECEIVE_SUBVOL" ]]; then
      echo "Could not identify received snapshot from stream"
      return 1
   fi
}

MODE=""
FROM_ID=""
TO_ID="0"
SHOW_DIFF=0
BACKUP_SNAPSHOT=""
DEVICE=""
USB_SNAPSHOT=""
STREAM_NAME=""
MOUNTPOINT="/mnt/usb"
BACKUP_MOUNTED_HERE=0
USB_MOUNTED_HERE=0
RECEIVE_PARENT=""
RECEIVE_SUBVOL=""

trap cleanup EXIT

while [[ "$#" -gt 0 ]]; do
   case "$1" in
      --mode)
         MODE="${2:-}"
         shift 2
         ;;
      --from)
         FROM_ID="${2:-}"
         shift 2
         ;;
      --to)
         TO_ID="${2:-}"
         shift 2
         ;;
      --show-diff)
         SHOW_DIFF=1
         shift
         ;;
      --backup-snapshot)
         BACKUP_SNAPSHOT="${2:-}"
         shift 2
         ;;
      --device)
         DEVICE="${2:-}"
         shift 2
         ;;
      --usb-snapshot)
         USB_SNAPSHOT="${2:-}"
         shift 2
         ;;
      --stream-name)
         STREAM_NAME="${2:-}"
         shift 2
         ;;
      --mountpoint)
         MOUNTPOINT="${2:-}"
         shift 2
         ;;
      -h|--help)
         usage
         exit 0
         ;;
      *)
         echo "Unknown argument: $1"
         usage
         exit 1
         ;;
   esac
done

require_root
require_cmds

if [[ -z "$MODE" ]]; then
   echo "--mode is required"
   usage
   exit 1
fi

case "$MODE" in
   snapper)
      if [[ -z "$FROM_ID" ]]; then
         echo "snapper mode requires --from ID"
         exit 1
      fi

      print_section "Snapper Compare"
      echo "Range: ${FROM_ID}..${TO_ID}"

      print_section "Snapshot Status"
      snapper -c root status "${FROM_ID}..${TO_ID}"

      if [[ "$SHOW_DIFF" -eq 1 ]]; then
         print_section "Snapshot Diff"
         snapper -c root diff "${FROM_ID}..${TO_ID}"
      fi
      ;;
   btrbk)
      if [[ -z "$BACKUP_SNAPSHOT" ]]; then
         echo "btrbk mode requires --backup-snapshot NAME"
         exit 1
      fi

      mount_backup_if_needed
      compare_dirs_summary "/mnt/backup/snapshots/${BACKUP_SNAPSHOT}" "btrbk:${BACKUP_SNAPSHOT}"
      ;;
   usb-btrfs)
      if [[ -z "$DEVICE" || -z "$USB_SNAPSHOT" ]]; then
         echo "usb-btrfs mode requires --device DEV and --usb-snapshot NAME"
         exit 1
      fi
      mount_usb_if_needed
      compare_dirs_summary "${MOUNTPOINT}/snapshots/${USB_SNAPSHOT}" "usb-btrfs:${USB_SNAPSHOT}"
      ;;
   usb-stream)
      if [[ -z "$DEVICE" || -z "$STREAM_NAME" ]]; then
         echo "usb-stream mode requires --device DEV and --stream-name NAME"
         exit 1
      fi
      mount_usb_if_needed
      STREAM_PATH="${MOUNTPOINT}/btrfs-streams/${STREAM_NAME}"
      SHA_PATH="${STREAM_PATH%.btrfs-stream}.sha256"

      if [[ ! -f "$STREAM_PATH" ]]; then
         echo "Stream file not found: $STREAM_PATH"
         exit 1
      fi

      print_section "USB Stream Check"
      echo "Stream: $STREAM_PATH"
      if [[ -f "$SHA_PATH" ]]; then
         (cd "$(dirname "$STREAM_PATH")" && sha256sum -c "$(basename "$SHA_PATH")")
      else
         echo "Checksum file not found: $SHA_PATH"
      fi

      receive_stream_to_temp "$STREAM_PATH"
      compare_dirs_summary "$RECEIVE_SUBVOL" "usb-stream:${STREAM_NAME}"
      ;;
   *)
      echo "Unsupported mode: $MODE"
      usage
      exit 1
      ;;
esac
