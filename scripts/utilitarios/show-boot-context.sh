#!/usr/bin/env bash
set -u

once_per_boot=0
if [[ "${1:-}" == "--once-per-boot" ]]; then
   once_per_boot=1
fi

uid_val="$(id -u)"
boot_id="$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || echo unknown)"
runtime_dir="${XDG_RUNTIME_DIR:-/run/user/${uid_val}}"
stamp_file="${runtime_dir}/.boot-context-${boot_id}"

if [[ "$once_per_boot" -eq 1 ]]; then
   if [[ -f "$stamp_file" ]]; then
      exit 0
   fi
   touch "$stamp_file" 2>/dev/null || true
fi

root_src="$(findmnt -n -o SOURCE / 2>/dev/null || echo '?')"
root_opts="$(findmnt -n -o OPTIONS / 2>/dev/null || echo '?')"
home_src="$(findmnt -n -o SOURCE /home 2>/dev/null || echo 'not-mounted')"
home_opts="$(findmnt -n -o OPTIONS /home 2>/dev/null || echo '-')"
root_subvol="$(echo "$root_opts" | tr ',' '\n' | grep '^subvol=' | head -1 | cut -d= -f2-)"
home_subvol="$(echo "$home_opts" | tr ',' '\n' | grep '^subvol=' | head -1 | cut -d= -f2-)"
kernel="$(uname -r 2>/dev/null || echo '?')"

mode="SNAPSHOT"
if [[ "$root_subvol" == "/@" || "$root_subvol" == "@" ]]; then
   mode="NORMAL"
elif echo "$root_src" | grep -Eq 'sda3|nvme.*p3'; then
   mode="EMERGENCY"
fi

if [[ "$mode" != "EMERGENCY" ]] && echo "$root_subvol" | grep -Eq '/snapshots/|@\.20[0-9]{8}T[0-9]{4}|@\.20[0-9]{6}T[0-9]{4}'; then
   mode="SNAPSHOT"
fi

if [[ "$mode" == "SNAPSHOT" ]] && echo "$root_src" | grep -Eq 'sda3|nvme.*p3'; then
   mode="EMERGENCY"
fi

color_ok=''
color_warn=''
color_danger=''
color_reset=''
if [[ -t 1 ]]; then
   color_ok='\033[1;32m'
   color_warn='\033[1;33m'
   color_danger='\033[1;31m'
   color_reset='\033[0m'
fi

status_line="${mode}"
case "$mode" in
   NORMAL) status_line="${color_ok}[OK] NORMAL${color_reset}" ;;
   SNAPSHOT) status_line="${color_warn}[WARN] SNAPSHOT${color_reset}" ;;
   EMERGENCY) status_line="${color_danger}[EMERG] EMERGENCY${color_reset}" ;;
esac

printf '\n'
echo "============================================================"
echo " Boot Context Check"
echo "============================================================"
echo -e " Mode      : ${status_line}"
echo " Kernel    : ${kernel}"
echo " Root      : ${root_src}  subvol=${root_subvol:-unknown}"
echo " Home      : ${home_src}  subvol=${home_subvol:-unknown}"
echo ""
echo " Quick commands:"
echo "   findmnt /"
echo "   findmnt /home"
echo "   sudo btrfs subvolume show / | grep 'Name:'"
echo "============================================================"

if [[ "$mode" == "SNAPSHOT" ]]; then
   echo "WARNING: You are running from snapshot mode."
   echo "         Changes in /home persist; root behavior depends on snapshot flow."
   echo "============================================================"
fi

if [[ "$mode" == "EMERGENCY" ]]; then
   echo "WARNING: You are running from EMERGENCY recovery snapshot."
   echo "         Verify before doing long-term changes."
   echo "============================================================"
fi