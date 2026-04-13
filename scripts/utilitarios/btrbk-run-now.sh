#!/usr/bin/env bash
set -u

if [[ "${EUID}" -ne 0 ]]; then
   echo "Run as root: sudo $0"
   exit 1
fi

echo "Starting btrbk.service..."
if ! systemctl start btrbk.service; then
   echo "btrbk.service failed to start"
   journalctl -u btrbk.service -n 40 --no-pager
   exit 1
fi

echo "btrbk.service completed."

echo
if mountpoint -q /mnt/backup; then
   echo "/mnt/backup state after run: still mounted"
else
   echo "/mnt/backup state after run: unmounted"
fi

echo
echo "Recent btrbk log:"
journalctl -u btrbk.service -n 40 --no-pager
