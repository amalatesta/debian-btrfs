# Snapper and Btrbk Configuration Analysis

**Generated:** 2026-04-13  
**System:** Debian 13 with NVMe (nvme0n1)

---

## 1. SNAPPER CONFIGURATION

### 1.1 Snapper for Root Configuration

**Location:** `/etc/snapper/configs/root`

**Configuration Settings:**
```bash
TIMELINE_CREATE=no                 # Timeline snapshots DISABLED (only event-based)
NUMBER_LIMIT=10                    # Keep maximum 10 snapshot pairs
NUMBER_LIMIT_IMPORTANT=10          # Keep maximum 10 important snapshots
```

**What Snapper snapshots:**
- **Mount point:** `/`
- **Subvolume:** `@` (root filesystem)
- **Snapshots stored in:** `/.snapshots/` (subvolume `.snapshots`)
- **Cleanup type:** `number` (keep only last N snapshots, discard old ones)

### 1.2 Snapper Snapshot Triggers

**Trigger 1: APT Package Manager (PRE/POST)**
- **Location:** `/etc/apt/apt.conf.d/80snapper`
- **When it fires:** Before and after any `apt install`, `apt upgrade`, etc.
- **What it does:**
  - PRE hook: Creates snapshot BEFORE package installation
  - POST hook: Creates snapshot AFTER package installation  
  - Automatically runs cleanup with `snapper cleanup number`
- **Snapshot Types:** `pre` and `post` (linked pairs)
- **Description:** Labeled as `apt`

**Configuration:**
```
DPkg::Pre-Invoke  { "if [ -e /etc/default/snapper ]; then . /etc/default/snapper; fi; if [ -x /usr/bin/snapper ] && [ ! x$DISABLE_APT_SNAPSHOT = 'xyes' ] && [ -e /etc/snapper/configs/root ]; then rm -f /var/tmp/snapper-apt || true ; snapper create -d apt -c number -t pre -p > /var/tmp/snapper-apt || true ; snapper cleanup number || true ; fi"; };

DPkg::Post-Invoke { "if [ -e /etc/default/snapper ]; then . /etc/default/snapper; fi; if [ -x /usr/bin/snapper ] && [ ! x$DISABLE_APT_SNAPSHOT = 'xyes' ] && [ -e /var/tmp/snapper-apt ]; then snapper create -d apt -c number -t post --pre-number=`cat /var/tmp/snapper-apt` || true ; snapper cleanup number || true ; fi"; };
```

**Trigger 2: Manual Snapshots**
- **Command:** `sudo snapper -c root create -d "Description"`
- **When:** Manually executed before system changes
- **Type:** `single` or manual type
- **Use case:** Before manual configuration changes

**Trigger 3: Cleanup Timer**
- **Service:** `snapper-cleanup.timer`
- **Status:** ✅ **ENABLED and ACTIVE**
- **Function:** Runs cleanup algorithm on existing snapshots
- **Note:** `snapper-timeline.timer` is **DISABLED** (aligns with `TIMELINE_CREATE=no`)

### 1.3 Snapper Snapshot Types Observed

From the active system (reporte-20260413-142207.txt):

| ID  | Type   | Pre # | Description           | Cleanup |
|-----|--------|-------|----------------------|---------|
| 2   | pre    | -     | apt                  | number  |
| 3   | post   | 2     | apt                  | number  |
| 4   | pre    | -     | apt                  | number  |
| 5   | post   | 4     | apt                  | number  |
| 6   | single | -     | boot                 | number  |
| 10  | single | -     | GOLDEN antes de escritorio | -    |
| 12  | single | -     | boot                 | number  |

---

## 2. BTRBK CONFIGURATION

### 2.1 Btrbk Configuration File

**Location:** `/etc/btrbk/btrbk.conf`

**Configuration:**
```
# Formato de timestamp
timestamp_format        long

# Cuándo crear snapshots
snapshot_create         onchange

# RETENCIÓN EN SISTEMA PRINCIPAL (nvme0n1p2)
# Mantener 7 snapshots más recientes (última semana)
snapshot_preserve_min   7d
snapshot_preserve       7d

# RETENCIÓN EN PARTICIÓN DE RECUPERACIÓN (nvme0n1p3)
# Mantener 14 diarios + 4 semanales (6 semanas total)
# target_preserve_min acepta un solo valor (no listas como "14d 4w")
target_preserve_min     14d
target_preserve         14d 4w

# Compresión durante transferencia
stream_compress         zstd

# Volumen a respaldar
volume /mnt/btrfs-root
  subvolume @
    snapshot_dir        @/.snapshots
    target              /mnt/backup/snapshots
```

### 2.2 What Btrbk Snapshots

- **Source mount point:** `/mnt/btrfs-root` (mounted with `subvolid=5` - full fs root)
- **Source subvolume:** `@` (same as root filesystem)
- **Snapshots stored in:** `@/.snapshots/` (LOCAL snapshots in same place as Snapper)
- **Backup destination:** `/mnt/backup/snapshots/` (ON nvme0n1p3 - recovery partition)
- **Snapshot naming:** `@.YYYYMMDDTHHMMSS` (using `long` timestamp format)

### 2.3 Btrbk Snapshot Triggers

**Trigger 1: APT Hook (optional but configured)**
- **Location:** `/etc/apt/apt.conf.d/81btrbk-trigger`
- **When it fires:** Immediately after successful APT transaction completes
- **What it does:** Launches `btrbk.service` in background (non-blocking with `--no-block`)
- **Effect:** Replicates the Snapper snapshot to recovery partition quickly

**Configuration:**
```
// Dispara btrbk.service en segundo plano luego de una transaccion dpkg.
DPkg::Post-Invoke {
   "if [ -x /usr/bin/systemctl ]; then /usr/bin/systemctl start --no-block btrbk.service || true; fi";
};
```

**Trigger 2: Btrbk Timer**
- **Service:** `btrbk.timer`
- **Status:** ✅ **ENABLED and ACTIVE**
- **Schedule:** Default systemd timer (typically daily, exact time depends on systemd default)
- **Function:** Runs periodic backup even if no APT activity occurs
- **Safety net:** If APT hook fails or for manual config changes, timer ensures backups still run

**Trigger 3: Manual Trigger**
- **Command:** `sudo btrbk -v run` or via snapcfg script
- **When:** Manually executed for immediate backup
- **Command:** `snapcfg "Description" --replicate` (executes btrbk.service)

### 2.4 Btrbk Service Configuration

**Service file override:** `/etc/systemd/system/btrbk.service.d/override.conf`

**ExecStartPre:** Mounts `/mnt/backup` before backup
```bash
ExecStartPre=/bin/sh -c 'if mountpoint -q /mnt/backup; then mount -o remount,rw /mnt/backup; else mount /mnt/backup; fi'
```

**ExecStartPost:** Post-backup script to update GRUB and unmount
```bash
ExecStartPost=/usr/local/bin/btrbk-postrun.sh
```

**Post-run script location:** `/usr/local/bin/btrbk-postrun.sh`

**Post-run script functions:**
1. Finds latest snapshot in `/mnt/backup/snapshots/`
2. Updates GRUB menu entry for emergency recovery
3. Unmounts `/mnt/backup` (or remounts as read-only if umount fails)

### 2.5 Retention Policy

**On local system (nvme0n1p2):**
- Keep: Last 7 days of snapshots

**On recovery partition (nvme0n1p3):**
- Keep: Last 14 days + 4 weeks (6 weeks total)
- Automatic cleanup of older snapshots

---

## 3. PARTITION LAYOUT

| Device        | Mountpoint    | Subvolume | Mount Type | Auto | Purpose |
|---------------|---------------|-----------|------------|------|---------|
| nvme0n1p1     | /boot/efi     | (vfat)    | rw         | yes  | EFI boot |
| nvme0n1p2     | `/`           | `@`       | rw,noatime | yes  | Root filesystem |
| nvme0n1p2     | `/home`       | `@home`   | rw,noatime | yes  | Home filesystem |
| nvme0n1p2     | `/mnt/btrfs-root` | (subvolid=5) | ro/rw | no    | Full filesystem (for btrbk) |
| nvme0n1p3     | `/mnt/backup` | (default) | noatime,noauto | no | Recovery partition |
| nvme0n1p4     | (swap)        | -         | -          | yes  | Swap |

**Mount Options:**
- All btrfs mounts: `compress=zstd:3` (zstd level 3 compression)
- System mounts: `rw,noatime,discard=async,space_cache=v2`
- Backup mount: `noatime,noauto` (only mounted when needed)

---

## 4. SNAPSHOT WORKFLOW

### 4.1 Normal APT Update Sequence

```
User runs: sudo apt upgrade
    ↓
DPkg::Pre-Invoke executes
    ↓
Snapper creates PRE snapshot (ID: N)
    ↓
Snapper runs cleanup NUMBER
    ↓
APT proceeds with update
    ↓
DPkg::Post-Invoke executes
    ↓
Snapper creates POST snapshot (ID: N+1, linked to PRE)
    ↓
Snapper runs cleanup NUMBER (keeps only 10 pairs)
    ↓
81btrbk-trigger Post-Invoke executes (optional)
    ↓
btrbk.service launched (--no-block, in background)
    ↓
btrbk-postrun.sh:
  - Mounts /mnt/backup if not mounted
  - Replicates snapshot to /mnt/backup/snapshots/
  - Updates GRUB emergency entry
  - Unmounts /mnt/backup
```

### 4.2 Manual Configuration Change Sequence

```
Using snapcfg before manual config change:

sudo snapcfg "Descripción del cambio"
    ↓
Creates Snapper snapshot locally
    ↓
Optionally: sudo snapcfg "Descripción" --replicate
    ↓
Runs btrbk.service immediately
    ↓
Follows same post-run steps as APT trigger
```

### 4.3 Periodic Backup Sequence (Timer-based)

```
Daily timer fires (btrbk.timer)
    ↓
btrbk.service starts
    ↓
ExecStartPre mounts /mnt/backup
    ↓
btrbk processes snapshots
    ↓
Replicates recent snapshots to recovery partition
    ↓
Applies retention policy (14d + 4w on target)
    ↓
ExecStartPost runs btrbk-postrun.sh
    ↓
Updates GRUB and unmounts /mnt/backup
```

---

## 5. SERVICE STATUS (Current System)

### 5.1 Active Services

- ✅ `snapper-cleanup.timer` - **ENABLED**
- ✅ `btrbk.timer` - **ENABLED**
- ✅ `grub-btrfsd` - **ENABLED**

### 5.2 Disabled Services

- ❌ `snapper-timeline.timer` - DISABLED (by design, `TIMELINE_CREATE=no`)

---

## 6. CURRENT SNAPSHOTS ON SYSTEM

From active system (2026-04-13):

**Local Snapshots (in `/.snapshots/`):**
- ID 3-5: APT snapshot pairs (pre/post)
- ID 6-9, 12: Boot-related snapshots
- ID 10-11: GOLDEN snapshots (pre-KDE installation)
- Total: 12 snapshots maintained

**Recovery Snapshots (in `/mnt/backup/snapshots/`):**
- Not fully listed in report (btrbk had a warning about missing mount)
- Typically: `@.20260407T0328`, `@.20260407T0330`, `@.20260407T0333`, etc.

---

## 7. CONFIGURATION FILES SUMMARY

| File | Location | Purpose | Status |
|------|----------|---------|--------|
| Snapper root config | `/etc/snapper/configs/root` | Root FS snapshots settings | Configured |
| APT Snapper hook | `/etc/apt/apt.conf.d/80snapper` | Pre/Post APT snapshots | Active |
| APT Btrbk trigger | `/etc/apt/apt.conf.d/81btrbk-trigger` | Background backup after APT | Active |
| Btrbk config | `/etc/btrbk/btrbk.conf` | Backup settings & retention | Configured |
| Btrbk service override | `/etc/systemd/system/btrbk.service.d/override.conf` | Mount/unmount logic | Configured |
| Btrbk post-run script | `/usr/local/bin/btrbk-postrun.sh` | GRUB update & cleanup | Configured |

---

## 8. KEY PARAMETERS

| Parameter | Snapper (root) | Btrbk |
|-----------|---|---|
| **Main subvolume** | `@` | `@` (from `/mnt/btrfs-root`) |
| **Local storage** | `/.snapshots/` | `@/.snapshots/` (same as Snapper) |
| **Remote storage** | N/A | `/mnt/backup/snapshots/` |
| **Retention policy** | 10 snapshots (number cleanup) | Local: 7d; Remote: 14d + 4w |
| **Auto-create trigger** | APT only (TIMELINE_CREATE=no) | APT hook + daily timer |
| **Timestamp format** | Varies | `long` (YYYYMMDDTHHMMSS) |
| **Compression** | zstd:3 | zstd (transfer only) |

---

## 9. DIAGRAM: Snapshot Flow

```
System Changes
    │
    ├─→ APT Package Update
    │   ├─→ Snapper PRE snapshot
    │   ├─→ APT proceeds
    │   ├─→ Snapper POST snapshot
    │   └─→ btrbk.service (background) → /mnt/backup/snapshots/
    │
    ├─→ Manual System Config (snapcfg)
    │   ├─→ Snapper local snapshot
    │   └─→ [Optional] btrbk.service → /mnt/backup/snapshots/
    │
    └─→ Daily Timer (btrbk.timer)
        └─→ btrbk.service → /mnt/backup/snapshots/
            ├─→ Apply retention (14d + 4w)
            ├─→ Update GRUB
            └─→ Unmount /mnt/backup

Local: /.snapshots/ (kept in sync with number cleanup)
Remote: /mnt/backup/snapshots/ (kept in sync with date-based cleanup)
```

---

## 10. RECOVERY ENTRY

**GRUB Emergency Entry:** `/etc/grub.d/40_custom`

Updated by `btrbk-postrun.sh` to point to latest recovery snapshot:
```bash
submenu ⚠ Debian RECOVERY (snapshots/@.YYYYMMDDTHHMMSS) {
    insmod search_fs_uuid
    search --fs-uuid <uuid> --set root
    linux /vmlinuz root=/dev/mapper/... ro quiet
    initrd /initrd.img
}
```

---

## 11. NOTES

### Design Choices
1. **Event-driven, not time-driven:** Snapper timeline disabled. Snapshots only on APT changes.
2. **Hybrid trigger for btrbk:** Both APT hook (immediate) and timer (fallback).
3. **Recovery partition managed:** Automatically mounted/unmounted to maintain security.
4. **Automatic cleanup:** Both local and remote snapshots cleaned per policy.
5. **GRUB integration:** Recovery boot entry auto-updated to latest snapshot.

### Critical Paths
- **Snapshot creation:** Any APT operation → automatic pre/post snapshots
- **Backup replication:** APT hook → btrbk service → /mnt/backup/snapshots/
- **Cleanup trigger:** Snapper cleanup (number), btrbk cleanup (date-based)
- **Recovery boot:** GRUB entry updated after each successful backup

### Potential Issues
- Recovery partition must be mounted for btrbk to work
- btrbk-postrun.sh must complete or partition remains mounted
- If APT hook fails, timer provides fallback daily backup

---

**End of Configuration Analysis**
