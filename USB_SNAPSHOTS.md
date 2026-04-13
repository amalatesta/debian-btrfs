# Snapshots en USB

Guía rápida para guardar snapshots de Btrfs/Snapper en un pendrive USB.

## Objetivo

- Crear un snapshot "golden" antes de cambios grandes.
- Guardarlo en USB para recuperación externa.
- Poder verificar integridad y restaurar en un entorno de prueba.

## Requisitos

- Sistema origen con Btrfs y Snapper.
- Acceso sudo.
- USB conectado y detectado con `lsblk`.
- Espacio suficiente en USB (igual o mayor al tamaño del snapshot exportado).

## Elegir método según filesystem del USB

1. USB en Btrfs: usar `btrfs send | btrfs receive` (ideal, incremental).
2. USB en exFAT/NTFS/FAT32: usar archivo stream `.btrfs-stream` (manual, portable).

## Detección del USB

```bash
lsblk -o NAME,MODEL,TRAN,SIZE,FSTYPE,MOUNTPOINTS,RM,UUID -e 7
```

## Paso 1: crear snapshot "golden"

```bash
SNAP_ID=$(sudo snapper -c root create -d "GOLDEN antes de cambios" --print-number)
echo "SNAP_ID=$SNAP_ID"
sudo snapper -c root list | tail -n 10
```

## Opción A: USB en Btrfs (recomendada)

```bash
NAME=golden-$(date +%Y%m%d-%H%M)
sudo mkdir -p /golden-exports
sudo btrfs subvolume snapshot -r /.snapshots/${SNAP_ID}/snapshot /golden-exports/${NAME}

sudo mkdir -p /mnt/usb
sudo mount /dev/sdX1 /mnt/usb
sudo mkdir -p /mnt/usb/snapshots

sudo btrfs send /golden-exports/${NAME} | sudo btrfs receive /mnt/usb/snapshots
sudo btrfs subvolume list /mnt/usb | grep "${NAME}"

sudo umount /mnt/usb
```

## Opción B: USB en exFAT/NTFS/FAT32 (stream a archivo)

```bash
NAME=golden-$(date +%Y%m%d-%H%M)
sudo mkdir -p /golden-exports
sudo btrfs subvolume snapshot -r /.snapshots/${SNAP_ID}/snapshot /golden-exports/${NAME}

sudo mkdir -p /mnt/usb
sudo mount /dev/sdX1 /mnt/usb
sudo mkdir -p /mnt/usb/btrfs-streams

sudo btrfs send /golden-exports/${NAME} | sudo tee /mnt/usb/btrfs-streams/${NAME}.btrfs-stream >/dev/null
sync
sudo sha256sum /mnt/usb/btrfs-streams/${NAME}.btrfs-stream | sudo tee /mnt/usb/btrfs-streams/${NAME}.sha256
sudo ls -lh /mnt/usb/btrfs-streams/${NAME}.btrfs-stream

sudo umount /mnt/usb
```

## Verificación recomendada

```bash
# Ver snapshots de Snapper
sudo snapper -c root list | tail -n 10

# Verificar que el USB quedó desmontado
mount | grep -E '/mnt/usb' || echo "USB desmontado"
```

## Restauración de prueba (sin tocar sistema productivo)

### Si guardaste subvolúmenes (Opción A)

```bash
sudo mount /dev/sdX1 /mnt/usb
sudo btrfs subvolume list /mnt/usb
sudo umount /mnt/usb
```

### Si guardaste stream (Opción B)

```bash
# En un volumen Btrfs de prueba:
sudo mkdir -p /mnt/test-restore
sudo mount /dev/sdY1 /mnt/test-restore
sudo btrfs receive /mnt/test-restore < /ruta/al/golden-YYYYMMDD-HHMM.btrfs-stream
sudo btrfs subvolume list /mnt/test-restore
sudo umount /mnt/test-restore
```

## Buenas prácticas

- Mantener al menos 2 snapshots "golden" en USB diferentes.
- Guardar checksum `.sha256` junto al stream.
- Etiquetar snapshot con fecha y propósito.
- Probar restauración en entorno de test antes de una emergencia real.
- No depender de un solo medio físico.

## Notas

- Cambiar `/dev/sdX1` por la partición real del USB.
- `btrfs send/receive` requiere destino Btrfs.
- El stream `.btrfs-stream` puede almacenarse en exFAT/NTFS/FAT32, pero para restaurarlo necesitás un destino Btrfs.

## Próxima prueba

- Hacer un simulacro de restore seguro en una carpeta/partición de prueba.
- No tocar el sistema actual en producción durante la validación.
