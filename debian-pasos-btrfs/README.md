# Bitácora de trabajo

Fecha de inicio: 2026-04-15

## Objetivo de esta bitácora

Este archivo registra el punto de partida y cada paso realizado fuera del repositorio `debian-btrfs`, para mantener una trazabilidad simple de lo que se va haciendo.

Regla de trabajo acordada:

- avanzar paso a paso;
- no ejecutar cambios nuevos sin confirmación previa del usuario;
- dejar asentado qué se hizo y qué queda pendiente.

## Punto de partida

- Sistema operativo en uso: Linux.
- Se verificó el entorno para bajar repositorios desde GitHub.
- `git` no estaba instalado inicialmente.
- `ssh` ya estaba instalado.
- El gestor de paquetes disponible es `apt`.

## Acciones realizadas hasta ahora

1. Se verificó qué herramientas estaban instaladas para trabajar con GitHub.
2. Se instaló `git` con `apt`.
3. Se clonó el repositorio:

   `https://github.com/amalatesta/debian-btrfs.git`

4. El repositorio se movió a esta ubicación:

   `/home/nippur/proyectos/debian-btrfs`

5. Se revisó la documentación existente del proyecto para entender el estado actual de:

   - `snapper`
   - `btrbk`
   - `grub-btrfs`
   - la entrada de recuperación en GRUB

## Estado actual

- El repositorio ya está descargado y ubicado dentro de `proyectos`.
- No se hicieron cambios en archivos del repositorio durante esta etapa de revisión.
- Se definió que el siguiente frente de trabajo será `Snapper`.
- `grub-btrfs` queda para una etapa posterior, después de validar `Snapper` y `btrbk`.

## Snapper

### Instalacion

Objetivo de esta etapa:

- verificar si `snapper` ya está instalado;
- instalarlo solo si hace falta;
- dejar asentado exactamente qué comando se ejecutó y qué resultado dio.

Lo que hacemos en esta etapa:

- revisar presencia del paquete y del comando `snapper`;
- confirmar si el sistema ya tiene base mínima para snapshots Btrfs;
- documentar el resultado antes de pasar a configuración.

Estado actual:

- instalación completada;
- `snapper` ya está disponible en el sistema.

Comandos ejecutados:

```bash
# Verificar si el paquete snapper está instalado y, si existe, mostrar su estado y versión
dpkg-query -W -f='PACKAGE snapper: ${Status} ${Version}\n' snapper 2>/dev/null || echo 'PACKAGE snapper: not-installed'

# Verificar si el comando snapper existe en el sistema y, si existe, mostrar ruta y versión
command -v snapper >/dev/null 2>&1 && { echo "COMMAND snapper: $(command -v snapper)"; echo -n 'VERSION snapper: '; snapper --version; } || { echo 'COMMAND snapper: not-found'; echo 'VERSION snapper: unavailable'; }
```

Resultado obtenido:

```text
PACKAGE snapper: not-installed
COMMAND snapper: not-found
VERSION snapper: unavailable
```

Instalación ejecutada:

```bash
# Actualizar el índice de paquetes e instalar snapper desde los repositorios de Debian
sudo apt update && sudo apt install -y snapper
```

Resultado relevante de la instalación:

```text
Installing:
   snapper

Installing dependencies:
   libboost-thread1.83.0  libbtrfs0t64  libsnapper7t64

Configurando snapper (0.10.6-1.2) ...
Created symlink '/etc/systemd/system/timers.target.wants/snapper-boot.timer' → '/usr/lib/systemd/system/snapper-boot.timer'.
Created symlink '/etc/systemd/system/timers.target.wants/snapper-cleanup.timer' → '/usr/lib/systemd/system/snapper-cleanup.timer'.
Created symlink '/etc/systemd/system/timers.target.wants/snapper-timeline.timer' → '/usr/lib/systemd/system/snapper-timeline.timer'.
Created symlink '/etc/systemd/system/sysinit.target.wants/snapperd.service' → '/usr/lib/systemd/system/snapperd.service'.
```

Verificación posterior:

```bash
# Confirmar que el paquete snapper quedó instalado, que el binario existe y qué versión quedó disponible
dpkg-query -W -f='PACKAGE snapper: ${Status} ${Version}\n' snapper && echo "COMMAND snapper: $(command -v snapper)" && echo -n 'VERSION snapper: ' && snapper --version
```

Resultado de la verificación posterior:

```text
PACKAGE snapper: install ok installed 0.10.6-1.2
COMMAND snapper: /usr/bin/snapper
VERSION snapper: snapper 0.10.6
libsnapper 7.2.0
flags btrfs,lvm,no-ext4,xattrs,rollback,btrfs-quota,no-selinux
```

Conclusión de esta etapa:

- `snapper` quedó instalado correctamente;
- el siguiente paso, si se confirma, es iniciar la etapa de configuración.

### Configuracion

Objetivo de esta etapa:

- crear o verificar la configuración `root` de `snapper`;
- revisar la política de snapshots que se quiere usar;
- dejar documentados los cambios antes de pasar a pruebas.

Lo que hacemos en esta etapa:

- validar si existe `/etc/snapper/configs/root`;
- crear la configuración sobre `/` si todavía no existe;
- revisar y ajustar los parámetros básicos de retención y comportamiento.

Estado actual:

- verificación inicial completada;
- la configuración `root` todavía no existe.

Comandos ejecutados:

```bash
# Verificar si ya existe el archivo de configuración principal de Snapper para la raíz del sistema
if [[ -f /etc/snapper/configs/root ]]; then
   echo 'CONFIG root: exists'
   ls -l /etc/snapper/configs/root
else
   echo 'CONFIG root: missing'
fi
```

Resultado obtenido:

```text
CONFIG root: missing
```

Creación ejecutada:

```bash
# Crear la configuración root de Snapper para el filesystem montado en /
sudo snapper -c root create-config /
```

Resultado de la creación:

```text
Command produced no output
```

Verificación posterior:

```bash
# Verificar que se creó el archivo de configuración root y que Snapper ya puede listar el estado inicial
if [[ -f /etc/snapper/configs/root ]]; then echo 'CONFIG root: exists'; ls -l /etc/snapper/configs/root; else echo 'CONFIG root: missing'; fi

# Mostrar el listado inicial de snapshots de la configuración root
sudo snapper -c root list | sed -n '1,6p'
```

Resultado de la verificación posterior:

```text
CONFIG root: exists
-rw-r----- 1 root root 1203 abr 15 01:04 /etc/snapper/configs/root

 # | Tipo   | Pre número | Fecha | Usuario | Limpieza | Descripción | Información del usuario
---+--------+------------+-------+---------+----------+-------------+------------------------
0  | single |            |       | root    |          | current     |
```

Conclusión de esta etapa:

- la configuración `root` de `Snapper` quedó creada correctamente;
- el snapshot base `0 current` ya aparece en el listado;
- el siguiente paso, si se confirma, es revisar y ajustar la política de configuración inicial.

Revisión de configuración actual:

```bash
# Mostrar la configuración actual de Snapper para la configuración root antes de hacer cambios
sudo snapper -c root get-config
```

Resultado obtenido:

```text
Clave                  | Valor
-----------------------+------
ALLOW_GROUPS           |
ALLOW_USERS            |
BACKGROUND_COMPARISON  | yes
EMPTY_PRE_POST_CLEANUP | yes
EMPTY_PRE_POST_MIN_AGE | 1800
FREE_LIMIT             | 0.2
FSTYPE                 | btrfs
NUMBER_CLEANUP         | yes
NUMBER_LIMIT           | 50
NUMBER_LIMIT_IMPORTANT | 10
NUMBER_MIN_AGE         | 1800
QGROUP                 |
SPACE_LIMIT            | 0.5
SUBVOLUME              | /
SYNC_ACL               | no
TIMELINE_CLEANUP       | yes
TIMELINE_CREATE        | yes
TIMELINE_LIMIT_DAILY   | 10
TIMELINE_LIMIT_HOURLY  | 10
TIMELINE_LIMIT_MONTHLY | 10
TIMELINE_LIMIT_WEEKLY  | 0
TIMELINE_LIMIT_YEARLY  | 10
TIMELINE_MIN_AGE       | 1800
```

Lectura inicial de la configuración:

- `TIMELINE_CREATE=yes`: Snapper está preparado para crear snapshots automáticos por tiempo.
- `TIMELINE_CLEANUP=yes`: también tiene activa la limpieza de snapshots de timeline.
- `NUMBER_LIMIT=50`: el límite por número está bastante alto para un esquema minimalista.
- `NUMBER_LIMIT_IMPORTANT=10`: ya existe un límite separado para snapshots importantes.

Conclusión de esta revisión:

- antes de seguir, conviene decidir si queremos un esquema por eventos y no por tiempo;
- si seguimos la línea del repositorio, lo esperable sería desactivar timeline y bajar el límite numérico.

Ajustes aplicados para esquema por eventos:

```bash
# Desactivar la creación automática de snapshots por tiempo y ajustar los límites numéricos básicos
sudo snapper -c root set-config "TIMELINE_CREATE=no"
sudo snapper -c root set-config "NUMBER_LIMIT=10"
sudo snapper -c root set-config "NUMBER_LIMIT_IMPORTANT=10"

# Verificar los valores resultantes después del ajuste
sudo snapper -c root get-config | grep -E 'TIMELINE_CREATE|NUMBER_LIMIT|NUMBER_LIMIT_IMPORTANT'
```

Resultado observado en el primer intento:

```text
NUMBER_LIMIT           | 50
NUMBER_LIMIT_IMPORTANT | 10
TIMELINE_CREATE        | no
```

Corrección aplicada:

```bash
# Corregir el límite numérico general y volver a verificar los tres parámetros clave
sudo snapper -c root set-config "NUMBER_LIMIT=10" && sudo snapper -c root get-config | grep -E 'TIMELINE_CREATE|NUMBER_LIMIT|NUMBER_LIMIT_IMPORTANT'
```

Resultado final:

```text
NUMBER_LIMIT           | 10
NUMBER_LIMIT_IMPORTANT | 10
TIMELINE_CREATE        | no
```

Conclusión de esta etapa:

- `Snapper` quedó configurado para no crear snapshots de timeline;
- el límite general quedó en `10`;
- el límite de snapshots importantes quedó en `10`;
- el siguiente paso, si se confirma, es revisar el estado de los timers de `Snapper`, en especial `snapper-timeline.timer`.

Verificación de timers y servicio:

```bash
# Revisar si los timers y el servicio principal de Snapper siguen habilitados y activos
for unit in snapper-timeline.timer snapper-cleanup.timer snapper-boot.timer snapperd.service; do printf '%s enabled=' "$unit"; systemctl is-enabled "$unit" 2>/dev/null || true; printf '%s active=' "$unit"; systemctl is-active "$unit" 2>/dev/null || true; done
```

Resultado obtenido:

```text
snapper-timeline.timer enabled=enabled
snapper-timeline.timer active=active
snapper-cleanup.timer enabled=enabled
snapper-cleanup.timer active=active
snapper-boot.timer enabled=enabled
snapper-boot.timer active=active
snapperd.service enabled=enabled
snapperd.service active=active
```

Conclusión de esta verificación:

- `snapper-timeline.timer` sigue habilitado y activo;
- `snapper-cleanup.timer` está habilitado y activo;
- `snapper-boot.timer` también está habilitado y activo;
- el siguiente paso, si se confirma, es desactivar `snapper-timeline.timer` para alinear servicios con la política por eventos.

Desactivación del timer de timeline:

```bash
# Desactivar y detener el timer de timeline de Snapper para evitar snapshots automáticos por tiempo
sudo systemctl disable --now snapper-timeline.timer
```

Resultado obtenido:

```text
Removed '/etc/systemd/system/timers.target.wants/snapper-timeline.timer'.
```

Verificación posterior:

```bash
# Confirmar que el timer de timeline quedó deshabilitado e inactivo
printf 'snapper-timeline.timer enabled='; systemctl is-enabled snapper-timeline.timer 2>/dev/null || true; printf 'snapper-timeline.timer active='; systemctl is-active snapper-timeline.timer 2>/dev/null || true
```

Resultado de la verificación posterior:

```text
snapper-timeline.timer enabled=disabled
snapper-timeline.timer active=inactive
```

Conclusión de esta etapa:

- `snapper-timeline.timer` quedó correctamente deshabilitado e inactivo;
- la política por eventos ya está alineada tanto en configuración como en systemd;
- el siguiente paso, si se confirma, es hacer una verificación funcional simple de `Snapper` creando un snapshot manual.

Prueba funcional de snapshot manual:

```bash
# Crear un snapshot manual de prueba para validar que la configuración root de Snapper funciona correctamente
sudo snapper -c root create -d "Prueba manual inicial Snapper"
```

Resultado de la creación:

```text
Command produced no output
```

Verificación posterior:

```bash
# Mostrar los snapshots más recientes para confirmar que el snapshot manual quedó registrado
sudo snapper -c root list | tail -5
```

Resultado de la verificación posterior:

```text
 # | Tipo   | Pre número | Fecha                    | Usuario | Limpieza | Descripción                   | Información del usuario
---+--------+------------+--------------------------+---------+----------+-------------------------------+------------------------
0  | single |            |                          | root    |          | current                       |
1  | single |            | mié 15 abr 2026 01:08:41 | root    |          | Prueba manual inicial Snapper |
```

Conclusión de esta etapa:

- `Snapper` ya crea snapshots manuales correctamente;
- el snapshot `1` quedó registrado con la descripción esperada;
- la instalación y configuración base de `Snapper` quedaron funcionales.

Verificación del hook de APT para Snapper:

```bash
# Verificar si ya existe el hook de APT para Snapper y mostrar su contenido si está presente
if [[ -f /etc/apt/apt.conf.d/80snapper ]]; then
   echo 'HOOK 80snapper: exists'
   ls -l /etc/apt/apt.conf.d/80snapper
   echo '---'
   sed -n '1,120p' /etc/apt/apt.conf.d/80snapper
else
   echo 'HOOK 80snapper: missing'
fi
```

Resultado obtenido:

```text
HOOK 80snapper: exists
-rw-r--r-- 1 root root 734 sep 19  2023 /etc/apt/apt.conf.d/80snapper
---
# https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=770938
   DPkg::Pre-Invoke  { "if [ -e /etc/default/snapper ]; then . /etc/default/snapper; fi; if [ -x /usr/bin/snapper ] && [ ! x$DISABLE_APT_SNAPSHOT = 'xyes' ] && [ -e /etc/snapper/configs/root ]; then rm -f /var/tmp/snapper-apt || true ; snapper create -d apt -c number -t pre -p > /var/tmp/snapper-apt || true ; snapper cleanup number || true ; fi"; };
   DPkg::Post-Invoke { "if [ -e /etc/default/snapper ]; then . /etc/default/snapper; fi; if [ -x /usr/bin/snapper ] && [ ! x$DISABLE_APT_SNAPSHOT = 'xyes' ] && [ -e /var/tmp/snapper-apt ]; then snapper create -d apt -c number -t post --pre-number=`cat /var/tmp/snapper-apt` || true ; snapper cleanup number || true ; fi"; };
```

Conclusión de esta etapa:

- el hook `/etc/apt/apt.conf.d/80snapper` ya existe;
- ya tiene la lógica para snapshots `pre/post` en transacciones de `apt`;
- no hace falta crearlo manualmente en este sistema;
- el siguiente paso, si se confirma, es probarlo con una operación simple de `apt`.

Prueba del hook de APT:

```bash
# Ejecutar una transacción simple de APT para disparar los snapshots pre/post de Snapper
sudo apt install --reinstall -y snapper
```

Resultado relevante de la transacción:

```text
Summary:
   Upgrading: 0, Installing: 0, Reinstalling: 1, Removing: 0, Not Upgrading: 0

Desempaquetando snapper (0.10.6-1.2) sobre (0.10.6-1.2) ...
Configurando snapper (0.10.6-1.2) ...
```

Verificación posterior:

```bash
# Mostrar los snapshots recientes para confirmar que APT generó el par pre/post
sudo snapper -c root list | tail -10
```

Resultado de la verificación posterior:

```text
 # | Tipo   | Pre número | Fecha                    | Usuario | Limpieza | Descripción                   | Información del usuario
---+--------+------------+--------------------------+---------+----------+-------------------------------+------------------------
0  | single |            |                          | root    |          | current                       |
1  | single |            | mié 15 abr 2026 01:08:41 | root    |          | Prueba manual inicial Snapper |
2  | pre    |            | mié 15 abr 2026 01:19:45 | root    | number   | apt                           |
3  | single |            | mié 15 abr 2026 01:19:46 | root    | number   | boot                          |
4  | post   |          2 | mié 15 abr 2026 01:19:46 | root    | number   | apt                           |
```

Conclusión de esta etapa:

- el hook de `apt` para `Snapper` funciona correctamente;
- quedó creado el par `pre/post` (`2` y `4`) para la transacción de `apt`;
- también apareció un snapshot `boot` (`3`), coherente con `snapper-boot.timer` activo;
- la parte principal de `Snapper` ya quedó validada tanto manualmente como en integración con `apt`.

---

## Prueba de rollback con Snapper (Opción B — sin boot desde snapshot)

Objetivo: instalar `fastfetch`, validar que queda en el sistema, hacer rollback al snapshot `pre` de forma definitiva y verificar que `fastfetch` desaparece.

### Paso 1 — Verificar que fastfetch no estaba instalado

```bash
# Verificar que fastfetch no existe en el sistema antes de la prueba
dpkg-query -W -f='PACKAGE fastfetch: ${Status} ${Version}\n' fastfetch 2>/dev/null || echo 'PACKAGE fastfetch: not-installed'; command -v fastfetch >/dev/null 2>&1 && echo "COMMAND fastfetch: $(command -v fastfetch)" || echo 'COMMAND fastfetch: not-found'
```

Resultado:

```text
PACKAGE fastfetch: not-installed
COMMAND fastfetch: not-found
```

Estado de snapshots antes de instalar (última línea era el `4`):

```text
4  | post   |          2 | mié 15 abr 2026 01:19:46 | root    | number   | apt
```

### Paso 2 — Instalar fastfetch y verificar snapshots pre/post

```bash
# Instalar fastfetch, lo que dispara automáticamente los snapshots pre/post de Snapper via APT hook
sudo apt install -y fastfetch
```

Verificación de snapshots generados:

```bash
# Confirmar que el hook de APT de Snapper creó el par pre/post durante la instalación
sudo snapper -c root list | tail -6
```

Resultado:

```text
5  | pre    |            | mié 15 abr 2026 01:31:41 | root    | number   | apt
6  | post   |          5 | mié 15 abr 2026 01:31:42 | root    | number   | apt
```

### Paso 3 — Verificar que fastfetch funciona

```bash
# Confirmar que fastfetch quedó instalado y operativo
fastfetch --version
```

Resultado:

```text
fastfetch 2.40.4-debug (x86_64)
```

Conclusión hasta aquí:

- `fastfetch` quedó instalado correctamente;
- se generaron los snapshots `5` (pre) y `6` (post);
- el snapshot `5` es el punto exacto al que vamos a volver.
- el siguiente paso, si se confirma, es hacer rollback al snapshot `5` (pre) con `snapper undochange`.

### Paso 4 — Rollback al snapshot pre (sin reinicio)

```bash
# Revertir todos los cambios del filesystem entre el snapshot pre (5) y post (6)
# Equivale a deshacer la instalación de fastfetch a nivel de archivos
sudo snapper -c root undochange 5..6
```

Resultado:

```text
crear:0 modificar:12 eliminar:59
```

### Paso 5 — Verificar que fastfetch ya no está

```bash
# Verificar que dpkg ya no conoce fastfetch y que el binario no existe en el sistema
dpkg-query -W -f='PACKAGE fastfetch: ${Status} ${Version}\n' fastfetch 2>/dev/null || echo 'PACKAGE fastfetch: not-installed'
ls -la /usr/bin/fastfetch 2>/dev/null || echo 'BINARY: not found'
fastfetch --version 2>/dev/null || echo 'BINARY: not executable'
```

Resultado:

```text
PACKAGE fastfetch: not-installed
BINARY: not found
```

Nota operativa:

- En la primera verificación `command -v fastfetch` devolvió `/usr/bin/fastfetch`, pero era un caché de la sesión de shell del paso anterior.
- La verificación real con `ls -la` confirmó que el binario ya no existe en el filesystem.

Conclusión de la prueba:

- el rollback con `snapper undochange 5..6` funcionó correctamente;
- `fastfetch` desapareció del sistema tanto a nivel de `dpkg` como a nivel de binario;
- el flujo completo quedó validado: instalación → snapshots `pre/post` automáticos → rollback definitivo.

### Paso 6 — Validación post-reinicio

```bash
# Confirmar después del reinicio que fastfetch sigue ausente y revisar el estado reciente de snapshots
echo "PKG=$(dpkg-query -W -f='${Status} ${Version}' fastfetch 2>/dev/null || echo not-installed)"
[[ -e /usr/bin/fastfetch ]] && echo 'BIN=present' || echo 'BIN=missing'
echo 'SNAPS:'
sudo snapper -c root list | tail -8
```

Resultado:

```text
PKG=not-installed
BIN=missing
SNAPS:
0  | single |            |                          | root    |          | current                       |
1  | single |            | mié 15 abr 2026 01:08:41 | root    |          | Prueba manual inicial Snapper |
2  | pre    |            | mié 15 abr 2026 01:19:45 | root    | number   | apt                           |
3  | single |            | mié 15 abr 2026 01:19:46 | root    | number   | boot                          |
4  | post   |          2 | mié 15 abr 2026 01:19:46 | root    | number   | apt                           |
5  | pre    |            | mié 15 abr 2026 01:31:41 | root    | number   | apt                           |
6  | post   |          5 | mié 15 abr 2026 01:31:42 | root    | number   | apt                           |
7  | single |            | mié 15 abr 2026 01:37:23 | root    | number   | boot                          |
```

Conclusión final de la validación de Snapper:

- después del reinicio, `fastfetch` sigue ausente como paquete y como binario;
- no aparecieron snapshots `apt` extra ni efectos inesperados tras el reinicio;
- sí apareció un nuevo snapshot `boot` (`7`), que es el comportamiento esperado con `snapper-boot.timer` activo;
- `Snapper` quedó validado de punta a punta para este esquema base.

### Consulta de límites, cantidad y espacio

```bash
# Ver los límites actuales de retención configurados en Snapper
sudo snapper -c root get-config | grep -E 'NUMBER_LIMIT|NUMBER_LIMIT_IMPORTANT|TIMELINE_CREATE|TIMELINE_CLEANUP'

# Contar cuántos snapshots existen actualmente en la configuración root
printf 'SNAP_COUNT='; sudo snapper -c root list | awk 'NR>2 && NF {count++} END {print count+0}'

# Ver tamaño total visible de /.snapshots y uso Btrfs por snapshot
echo 'TOTAL /.snapshots:'
sudo du -sh /.snapshots 2>/dev/null || true

sudo bash -lc 'echo; echo "BTRFS DU per snapshot:"; btrfs filesystem du -s /.snapshots/*/snapshot 2>/dev/null'
```

Resultado:

```text
NUMBER_LIMIT           | 10
NUMBER_LIMIT_IMPORTANT | 10
TIMELINE_CLEANUP       | yes
TIMELINE_CREATE        | no

SNAP_COUNT=8

TOTAL /.snapshots:
11G     /.snapshots

BTRFS DU per snapshot:
       Total   Exclusive  Set shared  Filename
    1.40GiB    24.00KiB     1.32GiB  /.snapshots/1/snapshot
    1.40GiB   216.00KiB     1.32GiB  /.snapshots/2/snapshot
    1.40GiB   640.00KiB     1.32GiB  /.snapshots/3/snapshot
    1.40GiB   192.00KiB     1.32GiB  /.snapshots/4/snapshot
    1.40GiB     4.00KiB     1.32GiB  /.snapshots/5/snapshot
    1.40GiB    48.04MiB     1.30GiB  /.snapshots/6/snapshot
    1.40GiB   888.00KiB     1.32GiB  /.snapshots/7/snapshot
```

Lectura práctica de estos datos:

- el límite general actual es `10` snapshots con cleanup por número;
- el límite de snapshots importantes también es `10`;
- hoy hay `8` snapshots contando `0 current`;
- `du -sh /.snapshots` muestra `11G`, pero en Btrfs ese número puede confundir porque incluye muchos bloques compartidos;
- para estimar cuánto “agrega” realmente cada snapshot, la columna más útil es `Exclusive` de `btrfs filesystem du`.

### Desactivar snapshots por reinicio

```bash
# Desactivar y detener el timer que crea snapshots de boot en cada arranque
sudo systemctl disable --now snapper-boot.timer

# Confirmar que quedó deshabilitado e inactivo
printf 'snapper-boot.timer enabled='; systemctl is-enabled snapper-boot.timer 2>/dev/null || true
printf 'snapper-boot.timer active='; systemctl is-active snapper-boot.timer 2>/dev/null || true
```

Resultado:

```text
Removed '/etc/systemd/system/timers.target.wants/snapper-boot.timer'.
snapper-boot.timer enabled=disabled
snapper-boot.timer active=inactive
```

Conclusión de este ajuste:

- ya no se crearán snapshots automáticos por reinicio;
- `Snapper` queda orientado a snapshots manuales y a snapshots `pre/post` de `apt`;
- esto reduce ruido y hace más fácil ubicar snapshots útiles al momento de recuperar el sistema.

### Validación post-reinicio (sin snapper-boot.timer activo)

```bash
# Verificar que tras un reinicio no se crea un nuevo snapshot de boot
sudo snapper -c root list | tail -8

# Confirmar que el timer de boot sigue deshabilitado
printf 'snapper-boot.timer enabled='; systemctl is-enabled snapper-boot.timer 2>/dev/null || true
printf 'snapper-boot.timer active='; systemctl is-active snapper-boot.timer 2>/dev/null || true
```

Resultado post-reinicio:

```text
7  | single |            | mié 15 abr 2026 01:37:23 | root    | number   | boot

snapper-boot.timer enabled=disabled
snapper-boot.timer active=inactive
```

Conclusión final de Snapper:

- tras el reinicio, **no apareció un nuevo snapshot automatico**: el último sigue siendo el `7`;
- esto confirma que la desactivación de `snapper-boot.timer` funcionó correctamente;
- `Snapper` quedó completamente configurado y validado para un esquema por eventos (solo manual + `apt`);
- próximos reinicios no generarán ruido de snapshots innecesarios.

---

## Scripts de automatización

Se crearon dos scripts shell para automatizar la gestión de Snapper:

### `setup-snapper.sh`

Script no interactivo de instalación y configuración inicial.

**Funciones:**
1. Verifica/instala el paquete `snapper`
2. Crea la configuración root (`/etc/snapper/configs/root`)
3. Ajusta el esquema a eventos:
   - `TIMELINE_CREATE=no`
   - `NUMBER_LIMIT=10`
   - `NUMBER_LIMIT_IMPORTANT=10`
4. Desactiva `snapper-timeline.timer`
5. Desactiva `snapper-boot.timer`

**Uso:**
```bash
sudo /home/nippur/proyectos/setup-snapper.sh
```

**Salida esperada:**
- 5 pasos secuenciales
- Cada paso validado y reportado
- Resumen final con próximos pasos

---

### `admin-snapper.sh`

Script interactivo con menú para gestión operacional de snapshots.

**Opciones del menú:**
0. Ver snapshots actuales
1. Crear nuevo snapshot
2. Restaurar desde snapshot (con selección de rango)
3. Eliminar snapshot
4. Ver configuración actual
5. Ejecutar setup-snapper.sh
6. Salir

**Características:**
- Menú con selector numérico
- Validación de entrada de usuario
- Confirmaciones antes de operaciones destructivas
- Colores y formato clara de salida
- Requiere root para todas las operaciones

**Uso:**
```bash
sudo /home/nippur/proyectos/admin-snapper.sh
```

**Flujo:**
- Si snapper no está instalado, ofrece opción 0 (setup)
- Si está instalado, ofrece menú completo
- Cada operación es reversible o tiene confirmación

---

## btrbk: instalación, configuración y validación

### Estado inicial verificado

- `btrbk` no estaba instalado.
- Partición recovery detectada y válida en Btrfs:
   - dispositivo: `/dev/nvme0n1p3`
   - label: `recovery`
   - UUID FS: `87a863b0-7cb2-4c66-becb-f71440fd994e`
- `/btrfs-root` y `/mnt/backup` ya estaban en `fstab` con `noauto`.

### Instalación y configuración aplicada

1. Se instaló `btrbk` con `apt`.
2. Se creó configuración en `/etc/btrbk/btrbk.conf` con esquema:
    - origen: `volume /btrfs-root` + `subvolume @`
    - staging local oculto: `snapshot_dir .btrbk_snapshots`
    - destino recovery: `target /mnt/backup/snapshots`
    - compresión: `stream_compress zstd`
    - retención local: `7d`
    - retención recovery: `14d 4w`
3. Se creó trigger APT en `/etc/apt/apt.conf.d/81btrbk-trigger` para lanzar `btrbk.service` en segundo plano tras transacciones exitosas.
4. Se aplicó override de `btrbk.service` para:
    - montar `/btrfs-root` y `/mnt/backup` antes del run;
    - ejecutar postrun al finalizar.
5. Se activó timer semanal (`OnCalendar=Sun 03:30`) con `btrbk.timer`.

### Política de seguridad validada

- Recovery NO queda montada en estado normal.
- Flujo operativo:
   - montar solo durante `btrbk run`;
   - replicar snapshot en `/mnt/backup/snapshots`;
   - desmontar al finalizar.

Validado en ejecución real:
- `/mnt/backup` termina desmontada.
- `/btrfs-root` termina desmontado.

### Prueba con evento APT (fastfetch)

Se hizo prueba equivalente a Snapper para validar cadena completa:

1. `fastfetch` no estaba instalado.
2. `apt install fastfetch` creó snapshots Snapper `10(pre)` y `11(post)`.
3. Trigger APT disparó `btrbk.service`.
4. Se replicó snapshot en recovery: `@.20260415T0228`.
5. Validación final: mounts auxiliares desmontados.

### Entrada custom de GRUB para EMERGENCY

Se creó entrada custom en `/etc/grub.d/40_custom` y se regeneró GRUB.

Además, se integró actualización automática desde `btrbk-postrun.sh` para que la entrada EMERGENCY apunte al último snapshot de recovery luego de cada `btrbk run`.

### Control para prueba pre-fastfetch

Se validó contenido de snapshots recovery para evitar falso positivo:

- `@.20260415T0222` → **sin** fastfetch (pre)
- `@.20260415T0225` → **sin** fastfetch (pre)
- `@.20260415T0228` → con fastfetch (post)
- `@.20260415T0254` → con fastfetch (post)

Para la prueba de boot de emergencia, la entrada GRUB quedó **hardcodeada temporalmente** al snapshot pre-fastfetch:

- `@.20260415T0225`

Validación en GRUB generado:

```text
menuentry 'Confirmar: arrancar desde nvme0n1p3 @.20260415T0225 (EMERGENCIA)'
```

### Banner de contexto de arranque (sección 12.5)

Se habilitó la validación automática al iniciar sesión:

- script instalado: `/usr/local/bin/show-boot-context.sh`
- hook global en `/etc/bash.bashrc`

Resultado actual:

```text
Mode : [OK] NORMAL
```

---

## Próximo paso propuesto

Realizar prueba de arranque EMERGENCY no destructiva en dos reinicios:

1. Reinicio 1: validar que el menú GRUB aparece correctamente.
2. Reinicio 2: entrar a `⚠ Debian RECOVERY` apuntando a `@.20260415T0225` y verificar que `fastfetch` no está.
3. Reiniciar normal y confirmar que `fastfetch` sigue instalado en sistema principal.

### Resultado de prueba en boot EMERGENCY (snapshot pre-fastfetch)

Se realizó el arranque de prueba desde:

- `@.20260415T0225` (recovery `nvme0n1p3`)

Validaciones ejecutadas en la sesión EMERGENCY:

```bash
findmnt -no SOURCE,OPTIONS /
cat /proc/cmdline
command -v fastfetch || echo fastfetch-absent
findmnt /mnt/backup || echo backup-unmounted
findmnt /btrfs-root || echo root-helper-unmounted
```

Resultado observado:

- `/` montado desde `/dev/nvme0n1p3[/snapshots/@.20260415T0225]`
- `cmdline` con `rootflags=subvol=snapshots/@.20260415T0225 ro quiet`
- `fastfetch-absent`
- `backup-unmounted`
- `root-helper-unmounted`

Conclusión:

- El boot EMERGENCY usó correctamente el snapshot pre-fastfetch.
- El paquete `fastfetch` no aparece en este entorno de recuperación.
- La partición recovery se mantuvo protegida (sin montajes auxiliares abiertos).

### Respaldo preventivo antes de rollback Snapper (pre-fastfetch)

Para no perder el mensaje de ingreso (boot context) ni la entrada custom de GRUB al volver a un estado anterior, se hizo backup en `/home` (fuera de `@`):

- carpeta: `/home/nippur/proyectos/backup-boot-context-20260415-031435`

Contenido respaldado:

- `/usr/local/bin/show-boot-context.sh`
- `/etc/bash.bashrc`
- `/usr/local/bin/btrbk-postrun.sh`
- `/etc/grub.d/40_custom`

También se dejó script de restauración rápida:

- `/home/nippur/proyectos/backup-boot-context-20260415-031435/restore-boot-context.sh`

Uso (si después del rollback se pierde configuración):

```bash
/home/nippur/proyectos/backup-boot-context-20260415-031435/restore-boot-context.sh
```

### Rollback Snapper a estado pre-fastfetch (sistema principal)

Se ejecutó rollback del rango de instalación de fastfetch:

```bash
sudo snapper -c root undochange 10..11
```

Salida resumida:

```text
crear:0 modificar:12 eliminar:59
```

Validación post-rollback:

```bash
command -v fastfetch || echo fastfetch-absent
dpkg-query -W -f='${Status}\n' fastfetch 2>/dev/null || echo package-not-installed
```

Resultado:

- `fastfetch-absent`
- `package-not-installed`

Validación de configuración preservada (sin restaurar backup):

- banner de contexto presente:
   - `/usr/local/bin/show-boot-context.sh`
   - hook en `/etc/bash.bashrc`
- entrada EMERGENCY vigente en GRUB:
   - `@.20260415T0225` en `/etc/grub.d/40_custom`
   - `@.20260415T0225` en `/boot/grub/grub.cfg`

Validación btrbk post-rollback:

- `btrbk.timer` activo
- trigger APT de btrbk cargado
- snapshots recovery disponibles:
   - `@.20260415T0222`
   - `@.20260415T0225`
   - `@.20260415T0228`
   - `@.20260415T0254`

### Validación post-reinicio en sistema normal (tras rollback Snapper)

Comprobaciones ejecutadas:

```bash
command -v fastfetch || echo fastfetch-absent
dpkg-query -W -f='${Status}\n' fastfetch 2>/dev/null || echo package-not-installed
/usr/local/bin/show-boot-context.sh
findmnt -no SOURCE /
findmnt -no SOURCE /home
```

Resultado:

- `fastfetch-absent`
- `package-not-installed`
- banner: `Mode : [OK] NORMAL`
- `/` en `/dev/nvme0n1p2[/@]`
- `/home` en `/dev/nvme0n1p2[/@home]`

Conclusión:

- El rollback con Snapper quedó aplicado de forma persistente en sistema principal.
- El reinicio confirmó estado estable en modo NORMAL.

## grub-btrfs: instalación y validación

### Instalación

`grub-btrfs` no estaba disponible como paquete en repositorios de Debian 13, por lo que se instaló desde fuente oficial:

```bash
git clone https://github.com/Antynea/grub-btrfs.git /home/nippur/proyectos/grub-btrfs
sudo make -C /home/nippur/proyectos/grub-btrfs install
```

Dependencias usadas durante instalación:

- `make`
- `inotify-tools` (requerida por `grub-btrfsd`)

### Configuración

Archivo activo: `/etc/default/grub-btrfs/config`

Valores aplicados:

```bash
GRUB_BTRFS_SUBMENUNAME="Debian snapshots"
GRUB_BTRFS_MKCONFIG=/usr/sbin/grub-mkconfig
GRUB_BTRFS_SCRIPT_CHECK=grub-script-check
GRUB_BTRFS_SNAPSHOT_KERNEL_PARAMETERS=""
GRUB_BTRFS_LIMIT="20"
GRUB_BTRFS_IGNORE_PREFIX_PATH=(".btrbk_snapshots" ".btrbk_snapshots/")
```

Objetivo del filtro `GRUB_BTRFS_IGNORE_PREFIX_PATH`:

- ocultar snapshots técnicos de btrbk (`.btrbk_snapshots`) del submenú `Debian snapshots`;
- mostrar solo snapshots Snapper (`@/.snapshots/...`) en ese menú.

### Fix de compatibilidad aplicado

Se detectó error al generar menú (`UUID of the root subvolume is not available`) por regex awk incompatible en `/etc/grub.d/41_snapshots-btrfs`.

Se aplicó corrección en dos líneas de detección de UUID, reemplazando `^\s*UUID` por `^[[:space:]]*UUID`.

Backup local creado antes de ajustar:

- `/etc/grub.d/41_snapshots-btrfs.bak-20260415-032442`

### Estado del servicio

```bash
systemctl is-enabled grub-btrfsd.service
systemctl is-active grub-btrfsd.service
```

Resultado:

- `enabled`
- `active`

### Validación de integración en GRUB

Archivo generado:

- `/boot/grub/grub-btrfs.cfg` (presente)

Referencia en GRUB principal:

- submenú `Debian snapshots` apunta a `configfile "${prefix}/grub-btrfs.cfg"`

### Prueba funcional (auto-actualización)

Se creó snapshot manual para disparar el daemon:

```bash
sudo snapper -c root create -d "Prueba grub-btrfsd" --print-number
```

Resultado:

- snapshot creado: `16`
- snapshot `@/.snapshots/16/snapshot` presente en `/boot/grub/grub-btrfs.cfg`
- no hay referencias a `.btrbk_snapshots` en `/boot/grub/grub-btrfs.cfg`

Conclusión:

- `grub-btrfs` quedó operativo para listar snapshots Snapper en GRUB;
- snapshots de btrbk en recovery no se muestran en `Debian snapshots`.

---

## Estado final confirmado: estructura de GRUB

Validación visual en menú GRUB confirmada el 2026-04-15 tras reinicios múltiples.

### Estructura de menú

El menú de GRUB contiene dos secciones diferenciadas:

1. **Menú normal** (sistema principal - `nvme0n1p2 @/`):
   - Entrada sistema Debian (kernel + initrd)
   - Submenu `Debian snapshots` (Snapper)
     - Snapshots con números: `1`, `2`, `3`, ... `16`, etc.
     - Cada entrada es un snapshot local en `@/.snapshots/N/snapshot`
     - Actualización automática: el daemon `grub-btrfsd` detecta nuevos snapshots en tiempo real
     - **Filtro aplicado**: no incluye snapshots de `.btrbk_snapshots` (ocultos)

2. **Menú de emergencia** (recovery - `nvme0n1p3`):
   - Submenu `⚠ Debian RECOVERY`
     - Entrada única apuntando al último snapshot de btrbk en recovery (`@.DATETIME`)
     - Actualizado automáticamente por `btrbk-postrun.sh` después de cada replicación
     - Separación clara del menú de Snapper, sin contaminación cruzada

### Validaciones ejecutadas

✓ Snapshots Snapper visibles en `Debian snapshots` (con números)
✓ Snapshots btrbk NO visibles en `Debian snapshots` (filtro funcionando)
✓ Entrada `⚠ Debian RECOVERY` presenta snapshot válido de recovery
✓ Navegación clara entre ambos menús (no hay duplicados)
✓ Auto-actualización funcional (nuevos snapshots Snapper aparecen sin reboot)

### Archivos de configuración en lugar

```
/etc/default/grub-btrfs/config    (filtro IGNORE_PREFIX_PATH activo)
/etc/grub.d/40_custom               (entrada RECOVERY apuntando a recovery)
/etc/grub.d/41_snapshots-btrfs      (script generador Snapper, regex fixed)
/boot/grub/grub-btrfs.cfg           (índice dinámico, auto-generado)
/etc/systemd/system/grub-btrfsd.service.d/override.conf  (auto-restart/restart-on-watchdog)
```

### Notas operacionales

- La carpeta fuente `/home/nippur/proyectos/grub-btrfs/` puede eliminarse si se requiere espacio (instalación ya aplicada al sistema).
- Para futuros updates de `grub-btrfs`, conviene mantener una copia del repositorio o re-clonar según necesidad.
- El cambio de kernel o estructura Btrfs requeriría revisar el filtro de `GRUB_BTRFS_IGNORE_PREFIX_PATH` si se agregan nuevas prefijos técnicas.

---

## Resumen del estado completo del sistema

### Componentes instalados y activos

| Componente | Estado | Ubicación clave | Función |
|---|---|---|---|
| **Snapper** | ✓ Activo | `/etc/snapper/configs/root` | Snapshots locales por eventos (apt, manual) |
| **btrbk** | ✓ Activo | `/etc/btrbk/btrbk.conf` | Replicación a recovery, weekly timer |
| **grub-btrfs** | ✓ Activo | `/etc/default/grub-btrfs/config` | Menú GRUB para snapshots Snapper |
| **Boot context** | ✓ Activo | `/usr/local/bin/show-boot-context.sh` | Banner de modo (NORMAL/SNAPSHOT/EMERGENCY) |
| **Custom GRUB** | ✓ Activo | `/etc/grub.d/40_custom` | Entrada ⚠ RECOVERY apuntando a btrbk |

### Snapshots actuales verificados

```
Snapper (local, @/.snapshots/):
  Snapshot #1 a #16 (números secuenciales)
  Tipos: pre (apt), post (apt), single (manual)
  Descripción: apt, boot, o manual según origen

btrbk (recovery, /mnt/backup/snapshots/):
  @.20260415T0222  (post-reinstall snapper)
  @.20260415T0225  (pre-fastfetch)
  @.20260415T0228  (post-fastfetch)
  @.20260415T0254  (post-rollback Snapper)
  [más snapshots según ciclos APT]
```

### Validaciones completadas

- ✅ Snapper: snapshots por eventos (apt + manual), sin timeline
- ✅ btrbk: replicación a recovery con mount/umount automático, timer semanal
- ✅ grub-btrfs: menú Snapper con filtro de .btrbk_snapshots
- ✅ Entrada RECOVERY: apunta a btrbk, separada de Snapper
- ✅ Boot context: banner en login, detecta contexto (NORMAL/SNAPSHOT/EMERGENCY)
- ✅ Integración APT: genera snapshots Snapper + dispara btrbk en background
- ✅ Auto-update GRUB: cambios en snapshots reflejados sin reboot manual

---

## Scripts de automatización y gestión

Se generaron dos **familias completamente funcionales** de scripts shell para automatizar instalación y gestión diaria:

1. **Familia Original**: Interfaz de texto simple (admin-*.sh)
2. **Familia UI**: Interfaz visual con cajas/bordes estilo debian-btrfs (admin-*-ui.sh)

Los scripts `setup-*.sh` son idénticos en ambas familias (no interactivos, sin menú).

---

### Familia Setup (instalación, común a ambas versiones)

Instalación y configuración inicial **no interactiva**, ejecución secuencial sin menús.

#### setup-snapper.sh (3.0K)
**Instalación de Snapper y configuración por eventos**

Pasos:
- Verificar/instalar paquete `snapper`
- Crear configuración root (`/etc/snapper/configs/root`)
- Ajustar a esquema por eventos:
  - `TIMELINE_CREATE=no`
  - `NUMBER_LIMIT=10`
  - `NUMBER_LIMIT_IMPORTANT=10`
- Desactivar timers automáticos: `snapper-timeline.timer`, `snapper-boot.timer`

**Uso:**
```bash
sudo /home/nippur/proyectos/setup-snapper.sh
```

---

#### setup-btrbk.sh (6.2K)
**Instalación de btrbk con replicación segura a recovery**

Pasos:
- Verificar/instalar paquete `btrbk`
- Crear `/etc/btrbk/btrbk.conf`:
  - Origen: `@` subvolume
  - Staging local oculto: `.btrbk_snapshots`
  - Destino: `/mnt/backup/snapshots` (recovery partition)
  - Compresión: zstd
  - Retención: 7d local, 14d+4w recovery
- Crear trigger APT (`/etc/apt/apt.conf.d/81btrbk-trigger`) para lanzar btrbk en background
- Aplicar override `btrbk.service`:
  - Pre-run: Montar recovery (`/btrfs-root`, `/mnt/backup`)
  - Post-run: Ejecutar `btrbk-postrun.sh` (desmontar, actualizar GRUB)
- Crear script `/usr/local/bin/btrbk-postrun.sh` (desmontaje + actualización de entrada EMERGENCY)
- Crear entrada custom GRUB (`/etc/grub.d/40_custom`) para arranque de emergencia
- Habilitar `btrbk.timer` (Sunday 03:30)

**Uso:**
```bash
sudo /home/nippur/proyectos/setup-btrbk.sh
```

---

#### setup-grub-btrfs.sh (4.3K)
**Instalación de grub-btrfs con menú de snapshots de Snapper**

Pasos:
- Verificar si grub-btrfs está instalado; clonar desde GitHub si falta (`/proyectos/grub-btrfs`)
- Instalar dependencia: `inotify-tools`
- Crear `/etc/default/grub-btrfs/config` con filtro:
  - `GRUB_BTRFS_IGNORE_PREFIX_PATH=(".btrbk_snapshots")` (oculta staging snapshots)
- Aplicar fix de regex awk (`^\s* → ^[[:space:]]*`) en `/etc/grub.d/41_snapshots-btrfs` si es necesario
- Habilitar daemon `grub-btrfsd` (auto-actualiza menú GRUB con eventos de Snapper)
- Regenerar GRUB `grub-mkconfig -o /boot/grub/grub.cfg`

**Uso:**
```bash
sudo /home/nippur/proyectos/setup-grub-btrfs.sh
```

---

#### setup-general.sh (2.4K)
**Ejecutor secuencial de todos los setup sin interacción**

Flujo:
1. setup-snapper.sh
2. setup-btrbk.sh
3. setup-grub-btrfs.sh

**Uso:**
```bash
sudo /home/nippur/proyectos/setup-general.sh
```

**Output:** Ejecución lineal de los tres pasos. Solo requiere confirmación inicial ("¿Continuar?").

---

### Familia Admin Original (interfaz simple, texto)

Menús interactivos para gestión operacional diaria. Interfaz de texto plano sin decoración visual.

#### admin-snapper.sh (6.5K)

**Opciones:**
```
[0] Ver snapshots actuales
[1] Crear nuevo snapshot
[2] Restaurar desde snapshot (seleccionar rango pre..post)
[3] Eliminar snapshot
[4] Ver configuración actual
[5] Info: políticas de retención
[6] Ejecutar setup-snapper.sh
[7] Salir
```

**Uso:**
```bash
sudo /home/nippur/proyectos/admin-snapper.sh
```

---

#### admin-btrbk.sh (6.7K)

**Opciones:**
```
[0] Ver snapshots en recovery (staging ocultos)
[1] Ejecutar btrbk run manualmente (mount → sync → umount)
[2] Ver estado + últimas líneas de /var/log/btrbk.log
[3] Ver configuración actual
[4] Editar configuración (/etc/btrbk/btrbk.conf)
[5] Info: política de retención (7d local, 14d+4w recovery)
[6] Ejecutar setup-btrbk.sh
[7] Salir
```

**Uso:**
```bash
sudo /home/nippur/proyectos/admin-btrbk.sh
```

---

#### admin-grub-btrfs.sh (7.6K)

**Opciones:**
```
[0] Ver estado del daemon grub-btrfsd (systemctl)
[1] Listar snapshots visibles en menú GRUB
[2] Regenerar configuración GRUB manualmente
[3] Ver configuración (/etc/default/grub-btrfs/config)
[4] Editar configuración
[5] Info: filtro .btrbk_snapshots
[6] Reiniciar daemon grub-btrfsd
[7] Ejecutar setup-grub-btrfs.sh
[8] Salir
```

**Uso:**
```bash
sudo /home/nippur/proyectos/admin-grub-btrfs.sh
```

---

#### admin-general.sh (8.3K)

**Menú central interactivo** con acceso a todos los componentes.

**Opciones:**
```
╒════════════════════════════════════════════════════════════════╕
│  [1] Gestión: Snapper     [2] Gestión: btrbk     [3] Gestión: grub-btrfs
│  [4] Setup: Snapper       [5] Setup: btrbk       [6] Setup: grub-btrfs
│  [7] Setup: Todo          [8] Info: Estado
│  [9] Guía rápida          [0] Salir
╘════════════════════════════════════════════════════════════════╛
```

**Características:**
- Banner de estado (✓/✗) de todos los componentes
- Detección automática de instalaciones
- Guía rápida integrada
- Menú padre que redirecciona a los otros admin-*.sh

**Uso:**
```bash
sudo /home/nippur/proyectos/admin-general.sh
```

---

### Familia Admin UI (interfaz visual, estilo debian-btrfs)

Menús interactivos **idénticos en funcionalidad** a la familia original, pero con **presentación visual mejorada** usando cajas, bordes y colores (estilo debian-btrfs repositorio).

- **Bordes**: Cajas de líneas (┌─┐├─┤└─┘)
- **Títulos**: Amarillo/cyan, resaltados
- **Separadores**: Líneas horizontales
- **Funcionalidad**: **100% idéntica** a versiones originales

#### admin-snapper-ui.sh (7.3K)
Mismas opciones que `admin-snapper.sh`, interfaz visual mejorada.

**Uso:**
```bash
sudo /home/nippur/proyectos/admin-snapper-ui.sh
```

---

#### admin-btrbk-ui.sh (7.6K)
Mismas opciones que `admin-btrbk.sh`, interfaz visual mejorada.

**Uso:**
```bash
sudo /home/nippur/proyectos/admin-btrbk-ui.sh
```

---

#### admin-grub-btrfs-ui.sh (8.3K)
Mismas opciones que `admin-grub-btrfs.sh`, interfaz visual mejorada.

**Uso:**
```bash
sudo /home/nippur/proyectos/admin-grub-btrfs-ui.sh
```

---

#### admin-general-ui.sh (8.7K)
Menú central visual, **llama a las versiones -ui de los submenús**.

Flujo:
- Cuando selecciona opción [1], llama a `admin-snapper-ui.sh` (no `admin-snapper.sh`)
- Cuando selecciona opción [2], llama a `admin-btrbk-ui.sh` (no `admin-btrbk.sh`)
- Cuando selecciona opción [3], llama a `admin-grub-btrfs-ui.sh` (no `admin-grub-btrfs.sh`)

**Uso:**
```bash
sudo /home/nippur/proyectos/admin-general-ui.sh
```

---

### Comparación: Original vs UI

| Aspecto | Original | UI |
|---------|----------|-----|
| **Interfaz** | Texto simple | Cajas/bordes (debian-btrfs style) |
| **Funcionalidad** | 100% completa | 100% completa (idéntica) |
| **Colores** | Ninguno | Cyan/amarillo/verde |
| **Menús anidados** | admin-general.sh → admin-*.sh | admin-general-ui.sh → admin-*-ui.sh |
| **Setup** | setup-general.sh | setup-general.sh (sin UI) |
| **Recomendación** | Scripts, automatización | Uso interactivo, legibilidad |

---

### Estructura completa de scripts

```
/home/nippur/proyectos/
│
├─── SETUP (Instalación, común a ambas familias) ───
├── setup-general.sh          (2.4K)  Ejecutor secuencial
│   ├── → setup-snapper.sh    (3.0K)
│   ├── → setup-btrbk.sh      (6.2K)
│   └── → setup-grub-btrfs.sh (4.3K)
│
├─── ADMIN ORIGINAL (Interfaz simple) ───
├── admin-general.sh          (8.3K)  Menú central
│   ├── → admin-snapper.sh    (6.5K)
│   ├── → admin-btrbk.sh      (6.7K)
│   ├── → admin-grub-btrfs.sh (7.6K)
│   └── → setup-general.sh    (2.4K)
│
├─── ADMIN UI (Interfaz visual debian-btrfs style) ───
├── admin-general-ui.sh       (8.7K)  Menú central con cajas
│   ├── → admin-snapper-ui.sh      (7.3K)
│   ├── → admin-btrbk-ui.sh        (7.6K)
│   ├── → admin-grub-btrfs-ui.sh   (8.3K)
│   └── → setup-general.sh         (2.4K)
│
└─ Total: 12 scripts (4 setup + 4 admin original + 4 admin UI)
```

---

### Puntos de entrada principales

**Instalación inicial del sistema completo (sin UI):**
```bash
sudo /home/nippur/proyectos/setup-general.sh
```

**Gestión operacional — Interfaz simple:**
```bash
sudo /home/nippur/proyectos/admin-general.sh
```

**Gestión operacional — Interfaz visual (recomendado para uso interactivo):**
```bash
sudo /home/nippur/proyectos/admin-general-ui.sh
```

**Acceso directo a componentes específicos (Original):**
```bash
sudo /home/nippur/proyectos/admin-snapper.sh
sudo /home/nippur/proyectos/admin-btrbk.sh
sudo /home/nippur/proyectos/admin-grub-btrfs.sh
```

**Acceso directo a componentes específicos (UI):**
```bash
sudo /home/nippur/proyectos/admin-snapper-ui.sh
sudo /home/nippur/proyectos/admin-btrbk-ui.sh
sudo /home/nippur/proyectos/admin-grub-btrfs-ui.sh
```

---

## Próximas acciones opcionales

1. **Monitoreo automático**: Alertas si snapshots recovery ocupan espacio crítico
2. **Rotación de logs**: Configurar logrotate para /var/log/btrbk.log
3. **Documentación operacional**: Guía para usuarios sobre cómo usar recovery desde boot EMERGENCY
4. **Validación en producción**: Monitorear comportamiento con ciclos reales de apt/usuario
5. **Optimización de retención**: Revisar política después de 1 mes de uso en producción

---

## Restauración parcial desde USB (validada)

Se validó un flujo de restauración selectiva en vivo usando stream de Btrfs en USB.

Objetivo de la prueba:

- comprobar que se puede traer una ruta puntual sin rollback completo de `/@`;
- cerrar el circuito completo: exportar, modificar, restaurar y limpiar import temporal.

Flujo ejecutado:

1. Crear archivo de prueba:

```bash
printf 'version original\n' | sudo tee /root/archivo-prueba.txt > /dev/null
```

2. Crear snapshot local Snapper:

```bash
sudo snapper create -d "golden test archivo-prueba"
```

3. Identificar snapshot (`21` en esta prueba) y exportar a USB:

```bash
sudo btrfs send /.snapshots/21/snapshot | sudo tee /mnt/usb/btrfs-streams/golden-test-archivo-prueba-20260415.btrfs-stream > /dev/null
```

4. Modificar archivo en sistema vivo:

```bash
printf 'version modificada\n' | sudo tee /root/archivo-prueba.txt > /dev/null
```

5. Importar stream en subvolumen temporal:

```bash
sudo mkdir -p /mnt/btrfs-restore-test
sudo btrfs receive /mnt/btrfs-restore-test < /mnt/usb/btrfs-streams/golden-test-archivo-prueba-20260415.btrfs-stream
```

6. Restaurar solo el archivo requerido:

```bash
sudo cp /mnt/btrfs-restore-test/snapshot/root/archivo-prueba.txt /root/archivo-prueba.txt
```

7. Verificación final:

```bash
sudo cat /root/archivo-prueba.txt
```

Resultado esperado y obtenido:

```text
version original
```

8. Limpieza del import temporal (paso importante):

```bash
sudo btrfs subvolume delete /mnt/btrfs-restore-test/snapshot
sudo rmdir /mnt/btrfs-restore-test
```

Conclusión:

- la restauración parcial desde USB funciona para archivos/rutas puntuales;
- no reemplaza un rollback total de `/@` (que requiere flujo de recuperación).

## Snapshots importantes (anclados)

Para conservar puntos de restauración de referencia en Snapper, se usa `userdata` con `important=yes`.

Crear snapshot anclado:

```bash
sudo snapper create -d "punto de referencia estable" --userdata "important=yes"
```

Marcar snapshot existente:

```bash
sudo snapper modify --userdata "important=yes" <ID>
```

Liberar snapshot (deja de estar anclado):

```bash
sudo snapper modify --userdata "important=no" <ID>
```

Verificación:

```bash
sudo snapper list
```

En la columna "Información del usuario" debe aparecer `important=yes`.

Promover snapshot importante viejo para GRUB:

- si un snapshot importante queda fuera del menú GRUB por límite (`GRUB_BTRFS_LIMIT`), se puede clonar desde ese snapshot para generar uno nuevo con ID reciente;
- en `admin-tools.sh` está disponible en: `Snapper -> Snapshots importantes -> Clonar/promover snapshot para GRUB`.
- tras clonar, normalmente `grub-btrfsd` lo toma automáticamente; si no aparece en GRUB, se puede forzar reiniciando daemon o regenerando GRUB manualmente.

Equivalente por comando:

```bash
sudo snapper -c root create --from <ID_VIEJO> -d "PROMOTE-YYYYMMDD-from-<ID_VIEJO>" -c number
```

Opcional:

```bash
sudo snapper -c root modify --userdata "important=yes" <ID_NUEVO>
```

## ¿Existe equivalente en btrbk?

No existe un equivalente directo de `important=yes` por snapshot individual en btrbk.

En btrbk, la preservación se define por política de retención en configuración (por ejemplo `snapshot_preserve` y `target_preserve`) y no por etiqueta puntual aplicada a un snapshot específico.

Si se requiere "anclar" una copia concreta de btrbk, la práctica recomendada es mover/copiar ese snapshot a una ruta fuera del alcance de la política automática de cleanup.

---

## Normativa operativa de snapshots (acordada)

Objetivo:

- tener puntos de restauración rápidos dentro de `/`;
- tener una copia externa para contingencias mayores.

### Nivel 1: Snapper importante (interno)

Uso:

- crear o marcar snapshots de referencia con `important=yes`;
- conservarlos como puntos estables de retorno local.

Regla:

- se usa para rollback rápido en el mismo sistema;
- no reemplaza backup externo.

Convención sugerida de descripción:

- `REF-YYYYMMDD-cambio`

Ejemplo:

```bash
sudo snapper create -d "REF-20260415-base-estable" --userdata "important=yes"
```

### Nivel 2: GOLDEN USB (externo)

Uso:

- exportar snapshots relevantes a USB como `.btrfs-stream`;
- mantener una copia fuera del disco principal.

Regla:

- se usa para restauración selectiva en vivo o restauración total desde entorno de recuperación;
- mantener el USB limpio, idealmente con 1 a 3 GOLDEN activos según capacidad.

Convención sugerida de nombre:

- `golden-YYYYMMDD-ref.btrfs-stream`

---

## Recuperación total desde snapshot en USB

Sí, es posible restaurar totalmente desde un snapshot exportado al USB, pero no se hace sobre el sistema en uso.

Condición obligatoria:

- arrancar desde Debian Live, consola de recuperación o entorno equivalente.

Razón:

- el subvolumen `/@` no puede reemplazarse de forma segura mientras está montado como raíz activa.

Esquema general:

1. Arrancar en entorno Live/Recovery.
2. Montar filesystem Btrfs del sistema interno.
3. Importar stream del USB con `btrfs receive`.
4. Crear nuevo `/@` a partir del snapshot importado (o renombrar/mover el actual y reemplazar).
5. Ajustar montaje si hace falta, regenerar GRUB/initramfs si corresponde.
6. Reiniciar al sistema normal.

Resumen:

- restauración parcial desde USB: sí, en vivo (selectiva);
- restauración total desde USB: sí, pero fuera del sistema en ejecución.

---

## Procedimiento operativo: recuperación total desde consola

Estado de esta guía:

- documentada para contingencia;
- no ejecutada en esta etapa (solo se validó rollback Snapper local y restore parcial USB).

### Preparación común (Live/Recovery)

1. Arrancar desde Debian Live (o consola de recuperación equivalente).
2. Abrir shell root.
3. Identificar discos y particiones:

```bash
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT
```

4. Variables de referencia usadas en este host:

- sistema Btrfs: `/dev/nvme0n1p2` (label `system`)
- recovery Btrfs: `/dev/nvme0n1p3` (label `recovery`)
- USB GOLDEN: partición exFAT label `golden` (por ejemplo `/dev/sda1`)

5. Montar raíz real del filesystem Btrfs (top-level):

```bash
mount -o subvolid=5 /dev/nvme0n1p2 /mnt/system
```

6. Verificar que existen los subvolúmenes esperados:

```bash
btrfs subvolume list /mnt/system | sed -n '1,120p'
```

### Opción A: recuperar total desde partición recovery (btrbk)

1. Montar recovery:

```bash
mkdir -p /mnt/recovery
mount /dev/nvme0n1p3 /mnt/recovery
ls -1 /mnt/recovery/snapshots
```

2. Elegir snapshot recovery objetivo (ejemplo `@.20260415T0225`).

3. Resguardar subvolumen activo actual (en lugar de borrarlo):

```bash
mv /mnt/system/@ "/mnt/system/@.pre-restore-$(date +%Y%m%d-%H%M%S)"
```

4. Crear nuevo `@` desde snapshot recovery:

```bash
btrfs subvolume snapshot /mnt/recovery/snapshots/@.20260415T0225 /mnt/system/@
```

5. Validar que el nuevo `@` existe:

```bash
test -d /mnt/system/@ && echo "OK nuevo @" || echo "ERROR @"
```

### Opción B: recuperar total desde USB GOLDEN (.btrfs-stream)

1. Montar USB:

```bash
mkdir -p /mnt/usb
mount /dev/sda1 /mnt/usb
ls -1 /mnt/usb/btrfs-streams
```

2. Importar stream dentro del Btrfs del sistema:

```bash
mkdir -p /mnt/system/@usb-imports
btrfs receive /mnt/system/@usb-imports < /mnt/usb/btrfs-streams/golden-YYYYMMDD-ref.btrfs-stream
```

3. Confirmar nombre del subvolumen recibido (normalmente `snapshot`):

```bash
find /mnt/system/@usb-imports -mindepth 1 -maxdepth 1 -type d
```

4. Resguardar `@` actual:

```bash
mv /mnt/system/@ "/mnt/system/@.pre-restore-$(date +%Y%m%d-%H%M%S)"
```

5. Crear nuevo `@` desde el subvolumen importado:

```bash
btrfs subvolume snapshot /mnt/system/@usb-imports/snapshot /mnt/system/@
```

6. Validar:

```bash
test -d /mnt/system/@ && echo "OK nuevo @" || echo "ERROR @"
```

### Cierre (aplica a ambas opciones)

1. Regenerar GRUB e initramfs dentro del sistema restaurado:

```bash
mount --bind /dev /mnt/system/dev
mount --bind /proc /mnt/system/proc
mount --bind /sys /mnt/system/sys
chroot /mnt/system /bin/bash -c "update-initramfs -u -k all && grub-mkconfig -o /boot/grub/grub.cfg"
```

2. Desmontar en orden:

```bash
umount /mnt/system/dev /mnt/system/proc /mnt/system/sys || true
umount /mnt/recovery 2>/dev/null || true
umount /mnt/usb 2>/dev/null || true
umount /mnt/system
```

3. Reiniciar:

```bash
reboot
```

### Validación post-arranque

```bash
findmnt -no SOURCE /
findmnt -no SOURCE /home
sudo /usr/local/bin/show-boot-context.sh
```

Esperado:

- raíz montada desde `/dev/nvme0n1p2[/@]`;
- modo reportado como `NORMAL` (salvo que se arranque deliberadamente otra entrada);
- estado funcional del sistema objetivo.

### Notas de seguridad

- no borrar inmediatamente `@.pre-restore-*`; conservarlo hasta validar arranque estable;
- confirmar dos veces el snapshot objetivo antes de reemplazar `@`;
- en caso de duda, preferir snapshot recovery btrbk conocido y documentado;
- mantener al menos un GOLDEN USB reciente y verificado.

---

## Protocolo de emergencia (sistema inconsistente)

Objetivo:

- recuperar estabilidad sin perder capacidad de inspeccionar/extraer del estado roto.

### Regla principal

- evitar volver a dejar como `/@` principal un snapshot identificado como roto o inconsistente.

### Flujo recomendado (5 pasos)

1. Congelar el estado roto

- crear snapshot del estado actual inconsistente;
- marcarlo temporalmente como importante (`important=yes`) para evitar cleanup automático.

2. Recuperar base estable

- ejecutar rollback hacia un snapshot conocido como sano;
- reiniciar y validar que el sistema vuelva en modo normal.

3. Recuperar diferencias necesarias

- usar inspección de snapshot en solo lectura desde `admin-tools.sh` (`Snapper -> Inspeccionar snapshot (solo lectura)`);
- copiar selectivamente archivos/directorios desde el snapshot roto al sistema estable (solo lo necesario).

4. Consolidar estado operativo

- crear un snapshot nuevo del sistema ya recuperado;
- marcar ese snapshot nuevo como importante.

5. Normalizar política de retención

- cuando ya no haga falta conservar el snapshot roto, desmarcarlo (`important=no`);
- permitir que la política automática de Snapper lo limpie en su ciclo normal.

### Resultado esperado

- sistema principal estable;
- snapshot roto conservado solo mientras sea útil para análisis/recuperación;
- nuevo punto de restauración claro y mantenible.

### Tabla de decisión rápida

| Necesidad | Opción recomendada |
|---|---|
| Ver qué cambió entre snapshots | `Comparar snapshots` |
| Deshacer cambios puntuales en vivo | `undochange` |
| Volver el sistema completo a un estado anterior | `rollback` + reboot |
| Revisar snapshot sin tocar el sistema actual | `Inspeccionar snapshot (solo lectura)` |
| Recuperar archivos desde copia externa | `Restaurar desde USB (selectivo)` |
- nuevo punto de referencia importante y reciente.