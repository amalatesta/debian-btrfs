#!/usr/bin/env bash
set -u

usage() {
   cat <<'EOF'
Usage:
  sudo scripts/utilitarios/usb-golden-snapshot.sh --device /dev/sdX1 [options]

Options:
  --device DEV            USB partition device (required), example: /dev/sdb1
  --mode MODE             auto | btrfs | stream (default: auto)
  --name NAME             export name (default: golden-YYYYMMDD-HHMM)
  --description TEXT      snapper description (default: "GOLDEN antes de cambios")
  --snap-id ID            reuse existing snapper snapshot ID (skip snapshot creation)
  --mountpoint PATH       temporary mountpoint (default: /mnt/usb)
  --cleanup-local-export  delete local readonly export after copy
  -h, --help              show this help

Behavior:
  - Creates/reuses a snapper snapshot from /.snapshots/<ID>/snapshot.
  - Creates readonly export under /golden-exports/<NAME>.
  - If mode=auto:
    * USB btrfs  -> btrfs send | btrfs receive
    * Other fs   -> writes .btrfs-stream + .sha256
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
   for cmd in btrfs snapper mount umount lsblk sha256sum; do
      if ! command -v "$cmd" >/dev/null 2>&1; then
         echo "Missing command: $cmd"
         missing=1
      fi
   done
   if [[ "$missing" -ne 0 ]]; then
      exit 1
   fi
}

DEVICE=""
MODE="auto"
NAME="golden-$(date +%Y%m%d-%H%M)"
DESCRIPTION="GOLDEN antes de cambios"
SNAP_ID=""
MOUNTPOINT="/mnt/usb"
CLEANUP_LOCAL_EXPORT=0

while [[ "$#" -gt 0 ]]; do
   case "$1" in
      --device)
         DEVICE="${2:-}"
         shift 2
         ;;
      --mode)
         MODE="${2:-}"
         shift 2
         ;;
      --name)
         NAME="${2:-}"
         shift 2
         ;;
      --description)
         DESCRIPTION="${2:-}"
         shift 2
         ;;
      --snap-id)
         SNAP_ID="${2:-}"
         shift 2
         ;;
      --mountpoint)
         MOUNTPOINT="${2:-}"
         shift 2
         ;;
      --cleanup-local-export)
         CLEANUP_LOCAL_EXPORT=1
         shift
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

if [[ -z "$DEVICE" ]]; then
   echo "--device is required"
   usage
   exit 1
fi

if [[ "$MODE" != "auto" && "$MODE" != "btrfs" && "$MODE" != "stream" ]]; then
   echo "Invalid --mode: $MODE"
   exit 1
fi

if [[ ! -b "$DEVICE" ]]; then
   echo "Device not found or not a block device: $DEVICE"
   exit 1
fi

USB_FSTYPE="$(lsblk -no FSTYPE "$DEVICE" 2>/dev/null | head -1)"
if [[ -z "$USB_FSTYPE" ]]; then
   USB_FSTYPE="unknown"
fi

if [[ "$MODE" == "auto" ]]; then
   if [[ "$USB_FSTYPE" == "btrfs" ]]; then
      MODE="btrfs"
   else
      MODE="stream"
   fi
fi

if [[ "$MODE" == "btrfs" && "$USB_FSTYPE" != "btrfs" ]]; then
   echo "mode=btrfs requires USB filesystem btrfs (detected: $USB_FSTYPE)"
   exit 1
fi

if [[ -z "$SNAP_ID" ]]; then
   echo "Creating snapper snapshot..."
   SNAP_ID="$(snapper -c root create -d "$DESCRIPTION" --print-number)"
fi

SOURCE_SNAPSHOT="/.snapshots/${SNAP_ID}/snapshot"
if [[ ! -d "$SOURCE_SNAPSHOT" ]]; then
   echo "Source snapshot not found: $SOURCE_SNAPSHOT"
   exit 1
fi

EXPORT_BASE="/golden-exports"
EXPORT_PATH="${EXPORT_BASE}/${NAME}"

mkdir -p "$EXPORT_BASE"
if [[ -e "$EXPORT_PATH" ]]; then
   echo "Export path already exists: $EXPORT_PATH"
   exit 1
fi

echo "Creating readonly export: $EXPORT_PATH"
btrfs subvolume snapshot -r "$SOURCE_SNAPSHOT" "$EXPORT_PATH"

mounted_here=0
if mountpoint -q "$MOUNTPOINT"; then
   echo "Mountpoint already mounted: $MOUNTPOINT"
else
   mkdir -p "$MOUNTPOINT"
   mount "$DEVICE" "$MOUNTPOINT"
   mounted_here=1
   echo "Mounted $DEVICE at $MOUNTPOINT"
fi

stream_file=""
sha_file=""

if [[ "$MODE" == "btrfs" ]]; then
   echo "Transfer mode: btrfs send/receive"
   mkdir -p "$MOUNTPOINT/snapshots"
   btrfs send "$EXPORT_PATH" | btrfs receive "$MOUNTPOINT/snapshots"

   if btrfs subvolume list "$MOUNTPOINT" | grep -F "$NAME" >/dev/null 2>&1; then
      echo "Verified exported subvolume on USB: $NAME"
   else
      echo "Warning: could not verify subvolume by name in USB list"
   fi
else
   echo "Transfer mode: stream file"
   mkdir -p "$MOUNTPOINT/btrfs-streams"
   stream_file="$MOUNTPOINT/btrfs-streams/${NAME}.btrfs-stream"
   sha_file="$MOUNTPOINT/btrfs-streams/${NAME}.sha256"

   btrfs send "$EXPORT_PATH" > "$stream_file"
   sync
   sha256sum "$stream_file" > "$sha_file"

   ls -lh "$stream_file" "$sha_file"
fi

if [[ "$mounted_here" -eq 1 ]]; then
   if umount "$MOUNTPOINT"; then
      echo "Unmounted $MOUNTPOINT"
   else
      echo "Warning: could not unmount $MOUNTPOINT"
   fi
fi

if [[ "$CLEANUP_LOCAL_EXPORT" -eq 1 ]]; then
   echo "Removing local readonly export: $EXPORT_PATH"
   btrfs subvolume delete "$EXPORT_PATH"
fi

echo
echo "Done"
echo "  SNAP_ID     : $SNAP_ID"
echo "  NAME        : $NAME"
echo "  DEVICE      : $DEVICE"
echo "  USB_FSTYPE  : $USB_FSTYPE"
echo "  MODE        : $MODE"
echo "  LOCAL_EXPORT: $EXPORT_PATH"
if [[ -n "$stream_file" ]]; then
   echo "  STREAM_FILE : $stream_file"
   echo "  SHA256_FILE : $sha_file"
fi
