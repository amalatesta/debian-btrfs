# Notas de Continuidad

Fecha: 2026-04-07

## Estado actual

- Se adaptaron secciones de la guía para discos NVMe (`nvme0n1pX`) y se dejaron alternativas para SATA (`sdaX`).
- Se aclaró en verificación de subvolúmenes que si `ls -la /mnt/btrfs/` muestra `@` y `@home`, está correcto.
- Se corrigió la sección 3.10 para indicar que aplica antes de reiniciar en Rescue Mode.
- Se agregó verificación corta alternativa para cuando ya reiniciaste en sistema normal.
- Se dejó explícito que antes de montar con `subvolid=5` hay que desmontar `/mnt/btrfs` si ya estaba montado.
- Validación corta post-reinicio completada (OK): `/` con `subvol=@`, `/home` con `subvol=@home` y `fstab` correcto con `/mnt/btrfs-root` y `/mnt/backup`.
- Sección 6.1 completada: paquetes `btrfs-progs`, `snapper`, `inotify-tools`, `vim`, `curl`, `wget`, `net-tools` instalados.
- Sección 6.2 completada: configuración `root` creada, snapshot `0 current` visible, `/.snapshots` presente y subvolumen `.snapshots` detectado (ID 258).
- Sección 6.3 completada: `TIMELINE_CREATE=no`, `NUMBER_LIMIT=10`, `NUMBER_LIMIT_IMPORTANT=10`.
- Sección 6.4 completada: hook APT Snapper creado en `/etc/apt/apt.conf.d/80snapper` y cargado por APT (`DPkg::Pre-Invoke` y `DPkg::Post-Invoke`).
- Sección 6.4.1 completada (opcional recomendado): trigger APT para lanzar `btrbk.service` en segundo plano creado en `/etc/apt/apt.conf.d/81btrbk-trigger` y cargado por APT.
- Sección 6.5 completada: `snapper-cleanup.timer` activo/habilitado y `snapper-timeline.timer` deshabilitado para alinear con `TIMELINE_CREATE=no`.
- Sección 6.6 completada: snapshot manual creado (`ID 1: Sistema base configurado`) y prueba APT exitosa con snapshots `pre/post` (`ID 2/3`). Verificación `status 2..3` y `diff 2..3` correcta.
- Sección 7.1 completada: `btrbk` instalado.
- Sección 7.2 completada: `/mnt/btrfs-root` montado con `subvolid=5` desde `/dev/nvme0n1p2`, verificado contenido `@` y `@home`, y `daemon-reload` ejecutado.
- Sección 7.3 completada: archivo `/etc/btrbk/btrbk.conf` creado y adaptado al esquema NVMe actual (`volume /mnt/btrfs-root`, `subvolume @`, `target /mnt/backup/snapshots`). Dry-run válido con advertencia esperada por falta de montaje de `/mnt/backup` (se resuelve en 7.4).
- Sección 7.4 completada: partición de recuperación montada en `/mnt/backup` (`/dev/nvme0n1p3`) y directorio `/mnt/backup/snapshots` creado.
- Sección 7.5 completada: prueba `btrbk` ejecutada; snapshot replicado en recuperación como `@.20260407T0328` (subvolumen en `/mnt/backup/snapshots`).
- Sección 7.6 completada: script `/usr/local/bin/btrbk-postrun.sh` creado, override en `/etc/systemd/system/btrbk.service.d/override.conf` aplicado (`ExecStartPre` + `ExecStartPost`) y `daemon-reload` ejecutado.
- Verificación funcional 7.6: `systemctl start btrbk.service` exitoso con `ExecStartPost` en estado `SUCCESS`; se creó/replicó snapshot `@.20260407T0330`.
- Sección 7.7 verificada: en estado normal `/mnt/backup` queda desmontado.
- Sección 7.8 completada: `btrbk.timer` habilitado/activo y próxima ejecución confirmada por `systemctl list-timers`.
- Sección 7.9 completada: comando `/usr/local/bin/snapcfg` creado y validado.
- Prueba `snapcfg --replicate` OK: snapshot local creado (`ID 6`, cleanup `number`) y réplica ejecutada por `btrbk.service` (`@.20260407T0333`), dejando `/mnt/backup` desmontado al finalizar.
- Sección 8.1 completada: `grub-btrfs` instalado desde GitHub con `make install`.
- Sección 8.2 completada: configuración activa en `/etc/default/grub-btrfs/config` con `GRUB_BTRFS_SUBMENUNAME="Debian snapshots"`, `GRUB_BTRFS_MKCONFIG=/usr/sbin/grub-mkconfig`, `GRUB_BTRFS_SCRIPT_CHECK=grub-script-check`, `GRUB_BTRFS_SNAPSHOT_KERNEL_PARAMETERS=""`, `GRUB_BTRFS_LIMIT="20"`.
- Sección 8.3 completada: `grub-btrfsd` habilitado y en ejecución.
- Sección 8.4 completada: se aplicó fix de compatibilidad en `/etc/grub.d/41_snapshots-btrfs` y `update-grub` detecta snapshots; archivo `/boot/grub/grub-btrfs.cfg` generado correctamente.
- Sección 8.5 validada post-reinicio: `grub-btrfsd` activo y corriendo, `/boot/grub/grub-btrfs.cfg` presente (31.8K, 26 entries), submenú "Debian snapshots" visible en GRUB.
- Validación adicional post-reinicio: menú de GRUB corregido para mostrar solo snapshots numerados de Snapper; se confirmaron 11 entradas válidas y quedaron excluidos los subvolúmenes `@.timestamp`.
- Warning observado al arrancar Debian: `EFI stub: WARNING: Failed to measure data for event ...`; validado como aviso de medición EFI/TPM con Secure Boot activo, sin impacto funcional sobre GRUB, Snapper ni el arranque normal.

## Punto exacto alcanzado en la instalación física

- El sistema reinició sin errores tras la sección 3.8.
- Duda resuelta: en sistema normal no tiene por qué existir `/mnt/btrfs` montado.
- Sección 4 (SSH) completada: acceso remoto funcionando.
- Sección 5 (Guest Additions) no aplica en notebook física.
- Sección 9 completada: entrada de emergencia en GRUB creada y verificada (`submenu ⚠ Debian RECOVERY` presente en `/boot/grub/grub.cfg`).
- **Instalación base COMPLETA**: Debian 13 + Btrfs + Snapper + btrbk + grub-btrfs + entrada de emergencia, todo funcional.
- Estado operativo validado tras reboot: arranque normal, banner de contexto OK, menú de snapshots limpio y warning EFI clasificado como benigno.

## Próximos pasos (inmediatos)

### 1) Cerrar validación post-reinicio (3.10 corto) ✅

Ejecutar en la notebook:

```bash
findmnt /
findmnt /home
cat /etc/fstab | grep -E 'subvol=@|subvol=@home|/mnt/backup|/mnt/btrfs-root'
```

Resultado esperado:

- `/` montado con `subvol=@`
- `/home` montado con `subvol=@home`
- `fstab` con entradas para `/mnt/backup` y `/mnt/btrfs-root`

Resultado: validación completada correctamente en notebook física.

### 2) Sección 6.1 y 6.2 (arranque Snapper)

```bash
sudo apt install -y btrfs-progs snapper inotify-tools
sudo apt install -y vim curl wget net-tools
sudo snapper -c root create-config /
sudo snapper -c root list
sudo ls -la /.snapshots/
sudo btrfs subvolume list /
```

### 3) Sección 6.3 (retención por eventos)

```bash
sudo snapper -c root set-config "TIMELINE_CREATE=no"
sudo snapper -c root set-config "NUMBER_LIMIT=10"
sudo snapper -c root set-config "NUMBER_LIMIT_IMPORTANT=10"
sudo snapper -c root get-config | grep -E "TIMELINE|NUMBER"
```

### 4) Sección 6.4 a 6.6

- Crear hook APT de Snapper en `/etc/apt/apt.conf.d/80snapper`.
- (Opcional recomendado) crear trigger btrbk en `/etc/apt/apt.conf.d/81btrbk-trigger`.
- Habilitar `snapper-cleanup.timer`.
- Probar snapshot manual y snapshots pre/post con una instalación APT pequeña.
- Continuar con sección 7 (btrbk) y sección 8 (grub-btrfs) al terminar pruebas de sección 6.

## Comandos útiles para retomar sesión

```bash
cd /home/administrador/proyectos/debian-btrfs
git pull --ff-only
```

## Nota de operación

- En Rescue Mode, normalmente se ejecuta como `root` (sin `sudo`).
- Si un `mount -o subvolid=5 ...` falla con `invalid argument`, primero desmontar:

```bash
umount /mnt/btrfs 2>/dev/null || true
```

## Continuidad 2026-04-08 (rollback a pre-KDE)

Objetivo de esta sesión:

- Volver al estado previo a instalar entorno gráfico (snapshot `ID 13`) y seguir trabajando desde allí en modo normal de escritura.

### 1) Creación de snapshot backup del estado actual

Comando ejecutado:

```bash
sudo snapper -c root create -d "Punto de retorno antes de rollback a ID13"
```

Resultado final vigente:

- Snapshot de respaldo conservado: `ID 24`.

### 2) Eliminación de snapshot repetido

Durante la ejecución se creó un duplicado por reintento. Se limpió con:

```bash
sudo snapper -c root delete 23
```

### 3) Comando para traer `ID 13` como principal

```bash
sudo snapper -c root rollback 13
sudo reboot
```

Notas:

- Esto deja el sistema arrancando desde el estado de `ID 13` como raíz principal.
- Queda en modo escritura (no solo lectura) para seguir trabajando normalmente.

### 4) Reiniciar y luego validar

Después del reboot, validar estado activo y red/SSH:

```bash
findmnt /
sudo snapper -c root list | tail -n 30
ip -4 -brief addr
ip route | grep default
sudo systemctl status ssh || sudo systemctl status sshd
sudo ss -tlnp | grep ssh
```

### 5) Si hace falta volver al backup actual (`ID 24`)

Aplicar rollback al snapshot backup:

```bash
sudo snapper -c root rollback 24
sudo reboot
```

Luego validar nuevamente:

```bash
findmnt /
sudo snapper -c root list | tail -n 30
```
