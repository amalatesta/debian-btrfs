# Notas de Continuidad

Fecha: 2026-04-07

## Estado actual

- Se adaptaron secciones de la guía para discos NVMe (`nvme0n1pX`) y se dejaron alternativas para SATA (`sdaX`).
- Se aclaró en verificación de subvolúmenes que si `ls -la /mnt/btrfs/` muestra `@` y `@home`, está correcto.
- Se corrigió la sección 3.10 para indicar que aplica antes de reiniciar en Rescue Mode.
- Se agregó verificación corta alternativa para cuando ya reiniciaste en sistema normal.
- Se dejó explícito que antes de montar con `subvolid=5` hay que desmontar `/mnt/btrfs` si ya estaba montado.

## Punto exacto alcanzado en la instalación física

- El sistema reinició sin errores tras la sección 3.8.
- Duda resuelta: en sistema normal no tiene por qué existir `/mnt/btrfs` montado.
- Próximo control recomendado: validación corta de 3.10 (post-reinicio).

## Próximos pasos (inmediatos)

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

Si todo da bien:

- Continuar con sección 4 (SSH) y luego 6-8 (Snapper, btrbk, grub-btrfs).

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
