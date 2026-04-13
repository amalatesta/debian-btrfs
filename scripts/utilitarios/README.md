# Utilitarios de Administracion y Mantenimiento

Esta carpeta contiene scripts de uso operativo para validar estado, ejecutar backups y revisar contexto de arranque.

Interfaz recomendada:
- `sudo scripts/utilitarios/admin-tools.sh`

El launcher `admin-tools.sh` usa una UI tipo TTY inspirada en `008_debian-btrfs-installer.sh` y mantiene separadas estas capas:
- `admin-tools.sh`: menu principal
- `lib/admin_ui.sh`: motor visual y navegacion
- `lib/admin_actions.sh`: acciones que invocan los utilitarios reales
- `*.sh`: scripts operativos independientes

## Scripts disponibles

### 0) admin-tools.sh

Para que sirve:
- Centraliza en un solo menu las herramientas administrativas de esta carpeta.
- Muestra reportes con scroll y dispara acciones sobre backup, recovery y export a USB.
- Permite abrir este README directamente desde la UI.
- Incluye comparaciones entre snapshots locales, backups btrbk y copias en USB.

Uso:
- sudo scripts/utilitarios/admin-tools.sh

### 1) show-boot-context.sh

Para que sirve:
- Muestra al iniciar shell el contexto de arranque (NORMAL, SNAPSHOT o EMERGENCY), kernel y subvolumenes activos.

Uso:
- Ejecucion manual:
  - sudo scripts/utilitarios/show-boot-context.sh
- Mostrar solo una vez por boot:
  - sudo scripts/utilitarios/show-boot-context.sh --once-per-boot

### 2) backup-health-report.sh

Para que sirve:
- Genera un reporte rapido de salud del esquema Snapper + btrbk + grub-btrfs.
- Verifica montajes, timers/servicios, snapshots locales y snapshots en recovery.
- Si /mnt/backup no esta montado, lo monta temporalmente y lo desmonta al final.

Uso:
- sudo scripts/utilitarios/backup-health-report.sh

### 3) snapper-run-now.sh

Para que sirve:
- Crea un snapshot manual de Snapper con descripcion automática (fecha/hora).
- Muestra el ID del snapshot creado y los últimos 10 snapshots.
- Incluye detalles del snapshot creado.

Uso:
- sudo scripts/utilitarios/snapper-run-now.sh

### 4) btrbk-run-now.sh

Para que sirve:
- Ejecuta un backup inmediato usando systemd (btrbk.service), respetando el flujo seguro de montaje/desmontaje.
- Muestra log reciente de la corrida y el estado final de /mnt/backup.

Uso:
- sudo scripts/utilitarios/btrbk-run-now.sh

### 5) recovery-partition.sh

Para que sirve:
- Gestion rapida de /mnt/backup en tareas manuales de administracion.
- Permite consultar estado, montar, desmontar y remount en ro/rw.

Uso:
- Estado:
  - sudo scripts/utilitarios/recovery-partition.sh status
- Montar:
  - sudo scripts/utilitarios/recovery-partition.sh mount
- Desmontar:
  - sudo scripts/utilitarios/recovery-partition.sh umount
- Remontar read-only:
  - sudo scripts/utilitarios/recovery-partition.sh ro
- Remontar read-write:
  - sudo scripts/utilitarios/recovery-partition.sh rw

### 6) usb-golden-snapshot.sh

Para que sirve:
- Crea (o reutiliza) un snapshot de Snapper y lo exporta a un USB.
- Si el USB es Btrfs usa `btrfs send | btrfs receive`.
- Si el USB es exfat/ntfs/fat32 guarda un stream `.btrfs-stream` y su checksum `.sha256`.

Uso:
- Modo automatico (detecta filesystem del USB):
  - sudo scripts/utilitarios/usb-golden-snapshot.sh --device /dev/sdX1
- Forzar envio como stream:
  - sudo scripts/utilitarios/usb-golden-snapshot.sh --device /dev/sdX1 --mode stream
- Reusar snapshot existente (ID de snapper):
  - sudo scripts/utilitarios/usb-golden-snapshot.sh --device /dev/sdX1 --snap-id 123
- Limpiar export local luego de copiar al USB:
  - sudo scripts/utilitarios/usb-golden-snapshot.sh --device /dev/sdX1 --cleanup-local-export

### 7) snapshot-compare.sh

Para que sirve:
- Compara snapshots locales de Snapper.
- Compara snapshots de btrbk contra el estado actual montando y desmontando `/mnt/backup` cuando hace falta.
- Compara snapshots o streams almacenados en USB contra el estado actual.

Uso:
- Snapper vs actual:
  - sudo scripts/utilitarios/snapshot-compare.sh --mode snapper --from 123
- Snapper entre dos snapshots:
  - sudo scripts/utilitarios/snapshot-compare.sh --mode snapper --from 123 --to 145 --show-diff
- btrbk vs actual:
  - sudo scripts/utilitarios/snapshot-compare.sh --mode btrbk --backup-snapshot @.20260413T0203
- USB Btrfs vs actual:
  - sudo scripts/utilitarios/snapshot-compare.sh --mode usb-btrfs --device /dev/sdX1 --usb-snapshot golden-20260413-0210
- USB stream vs actual:
  - sudo scripts/utilitarios/snapshot-compare.sh --mode usb-stream --device /dev/sdX1 --stream-name golden-20260413-0210.btrfs-stream

## Recomendaciones operativas

- Usar siempre los utilitarios con sudo.
- Para snapshots manuales de Snapper, preferir snapper-run-now.sh.
- Para backups manuales de btrbk, preferir btrbk-run-now.sh en lugar de ejecutar btrbk run directo.
- Mantener /mnt/backup con noauto en fstab para minimizar exposicion.
