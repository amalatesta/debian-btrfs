# Quick Reference: Snapper & Btrbk Configuration

## SNAPPER ROOT (`/etc/snapper/configs/root`)

### What's Backing Up
- **Filesystem:** `/` (root drive)
- **Subvolume:** `@`
- **Storage Location:** `/.snapshots/`
- **Subvolume ID:** `.snapshots` (ID 258)

### Configuration Values
```
TIMELINE_CREATE=no              ← Timeline disabled (no time-based auto snapshots)
NUMBER_LIMIT=10                 ← Keep max 10 pairs
NUMBER_LIMIT_IMPORTANT=10       ← Keep max 10 important
```

### What Triggers Snapper Snapshots

| Trigger | Location | Rules | Result |
|---------|----------|-------|--------|
| **APT PRE** | `/etc/apt/apt.conf.d/80snapper` | Before apt install/upgrade | `pre` snapshot |
| **APT POST** | `/etc/apt/apt.conf.d/80snapper` | After apt install/upgrade | `post` snapshot |
| **Manual** | Command: `snapper -c root create -d "text"` | On-demand | `single` snapshot |
| **Cleanup** | `snapper-cleanup.timer` | After each action | Auto-cleanup (keeps 10) |
| **Timeline** | `snapper-timeline.timer` | **DISABLED** | Never fires |

### Current Active Snapshots
```
ID | Type   | Description
2  | pre    | apt (PRE)
3  | post   | apt (POST from pre 2)
4  | pre    | apt (PRE)
5  | post   | apt (POST from pre 4)
6  | single | boot
10 | single | GOLDEN antes de escritorio
12 | single | boot
... (total 12 kept by cleanup)
```

---

## BTRBK (`/etc/btrbk/btrbk.conf`)

### What's Backing Up
- **Source:** `/mnt/btrfs-root` (NVMe full root mounted as subvolid=5)
- **Subvolume:** `@`
- **Local Snapshots:** `@/.snapshots/` (same as Snapper)
- **Backup Destination:** `/mnt/backup/snapshots/` (on NVMe partition 3)

### Configuration Values
```
snapshot_create         onchange           ← Create on changes
snapshot_preserve_min   7d                 ← Keep min 7 days local
target_preserve_min     14d                ← Keep min 14 days on backup
target_preserve         14d 4w             ← Keep 14 days + 4 weeks
stream_compress         zstd               ← Compress during transfer
timestamp_format        long               ← YYYYMMDDTHHMMSS format
```

### What Triggers Btrbk Snapshots

| Trigger | Location | When | Result |
|---------|----------|------|--------|
| **APT Hook** | `/etc/apt/apt.conf.d/81btrbk-trigger` | After successful apt | Replicates to `/mnt/backup/` (background) |
| **Daily Timer** | `btrbk.timer` | Daily (systemd default) | Replicates to `/mnt/backup/` |
| **Manual** | Command: `snapcfg "text" --replicate` | On-demand | Immediate replication |

### Backup Workflow
```
Snapper creates snapshot
    ↓
btrbk.service (via trigger or timer)
    ↓
ExecStartPre: Mount /mnt/backup
    ↓
Replicate snapshot to /mnt/backup/snapshots/@.YYYYMMDDTHHMMSS
    ↓
Apply retention (14d + 4w)
    ↓
ExecStartPost: Run btrbk-postrun.sh
    ├─ Update GRUB emergency entry
    └─ Unmount /mnt/backup
```

### Retention Policy

**On Local System (nvme0n1p2):**
- Keep: Minimum 7 days of snapshots
- Cleanup: Automatic, keep last 10 pairs

**On Recovery Partition (nvme0n1p3):**
- Keep: 14 days + 4 weeks (6 weeks total)
- Cleanup: Automatic by btrbk

---

## SERVICE STATUS

| Service | Enabled | Active | Purpose |
|---------|---------|--------|---------|
| `snapper-cleanup.timer` | ✅ | ✅ | Clean up local snapshots |
| `snapper-timeline.timer` | ❌ | ❌ | Time-based snapshots (disabled by design) |
| `btrbk.timer` | ✅ | ✅ | Daily backup replication |
| `grub-btrfsd` | ✅ | ✅ | Monitor and update GRUB |

---

## RECOVERY PARTITION BEHAVIOR

### Mount Status
- **Normal state:** **UNMOUNTED** (not accessible, safe from tampering)
- **During backup:** Mounted at `/mnt/backup` by `ExecStartPre`
- **After backup:** Unmounted by `btrbk-postrun.sh`
- **If unmount fails:** Remounted as read-only

### Protection Strategy
- Only mounted when needed for backup
- Automatically unmounted after
- GRUB entry updated point to latest snapshot
- No automatic access from running system

---

## SNAPSHOT NAMING

### Snapper Local Snapshots
```
/.snapshots/NN/snapshot
where NN = sequential ID (1, 2, 3, ...)
```

### Btrbk Remote Snapshots  
```
/mnt/backup/snapshots/@.20260413T142207
Format: @.YYYYMMDDTHHMMSS
```

---

## APT HOOKS EXPLAINED

### Hook 1: `/etc/apt/apt.conf.d/80snapper`
- **When:** Before and after APT operations
- **What:** Creates paired pre/post snapshots
- **Snapshots kept:** Last 10 pairs (cleanup=number)

### Hook 2: `/etc/apt/apt.conf.d/81btrbk-trigger` 
- **When:** After successful APT transaction
- **What:** Launches `btrbk.service --no-block`
- **Effect:** Non-blocking background backup to recovery partition

---

## KEY MOUNT POINTS

| Mount | Device | Subvolume | Auto | Purpose |
|-------|--------|-----------|------|---------|
| `/` | nvme0n1p2 | `@` | Yes | Root filesystem |
| `/home` | nvme0n1p2 | `@home` | Yes | Home filesystem |
| `/mnt/btrfs-root` | nvme0n1p2 | subvolid=5 | No | Full FS for btrbk |
| `/mnt/backup` | nvme0n1p3 | default | No | Recovery backups |

---

## TYPICAL BACKUP TIMELINE

```
Day 1, 10:00 AM
└─ sudo apt upgrade
   ├─ Snapper pre  (ID: 50)
   ├─ APT updates packages
   ├─ Snapper post (ID: 51, linked)
   └─ btrbk replicates @.20260413T100000

Day 1, 06:00 PM
└─ sudo apt install new-package
   ├─ Snapper pre  (ID: 52)
   ├─ APT installs
   ├─ Snapper post (ID: 53, linked)
   └─ btrbk replicates @.20260413T180000

Day 2, 03:00 AM (Daily timer)
└─ btrbk.timer fires
   └─ btrbk replicates latest snapshots
       (even if no APT activity)

Day 2-15
└─ Snapshots kept on both systems
└─ Old snapshots > 7 days cleaned locally
└─ Old snapshots kept on recovery until > 14d + 4w

Recovery partition
└─ Contains all backup snapshots
└─ GRUB entry points to latest
└─ Can boot from any snapshot
```

---

## MANUAL SNAPSHOT COMMANDS

### Create Local Snapshot Only
```bash
sudo snapper -c root create -d "Before database migration"
```

### Create + Backup Immediately
```bash
sudo snapcfg "Before database migration" --replicate
```

### View Local Snapshots
```bash
sudo snapper -c root list
```

### Backup Manually
```bash
sudo btrbk -v run
```

### Check Backup Status
```bash
sudo backup-health-report.sh
```

---

## POTENTIAL ISSUES & SOLUTIONS

| Issue | Cause | Fix |
|-------|-------|-----|
| No APT snapshots created | Hook disabled or file missing | Check `/etc/apt/apt.conf.d/80snapper` exists |
| Backups not running | btrbk.timer inactive | `sudo systemctl enable --now btrbk.timer` |
| `/mnt/backup` stays mounted | btrbk-postrun failed | Check `/usr/local/bin/btrbk-postrun.sh` permissions |
| Old snapshots not removed | Cleanup not running | Check `snapper-cleanup.timer` status |
| GRUB entry not updating | btrbk-postrun issue | Check journalctl logs for btrbk.service |

---

**Configuration valid as of:** 2026-04-13
