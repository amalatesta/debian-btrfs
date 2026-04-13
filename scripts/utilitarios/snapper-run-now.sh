#!/usr/bin/env bash
set -u

if [[ "${EUID}" -ne 0 ]]; then
   echo "Run as root: sudo $0"
   exit 1
fi

echo "Creating Snapper snapshot..."
SNAP_ID=$(snapper -c root create --description "Manual snapshot $(date +%Y-%m-%d\ %H:%M:%S)")

if [[ -z "$SNAP_ID" ]]; then
   echo "snapper create failed"
   exit 1
fi

echo "Snapshot created: ID $SNAP_ID"

echo
echo "Recent Snapper snapshots (last 10):"
snapper -c root list | tail -10

echo
echo "Snapshot details:"
snapper -c root info "$SNAP_ID"
