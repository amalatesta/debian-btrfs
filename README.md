# Guía Completa: Debian 13 con BTRFS + Snapper + btrbk
# Instalación desde cero optimizada (Estructura estándar @ y @home)

## Objetivo

Este repositorio tiene como objetivo documentar, paso a paso, la instalación de **Debian** como sistema operativo utilizando **Btrfs** como sistema de archivos, incluyendo la configuración de una **partición de recuperación**.

El propósito es contar con una guía clara y reproducible que permita:

- Instalar Debian con el sistema de archivos Btrfs.
- Configurar subvolúmenes Btrfs para una gestión eficiente del almacenamiento.
- Crear y configurar una partición de recuperación para restaurar el sistema ante fallos.

---

## Contenido

**Aplicación:**
- 🖥️ **Primero:** Probar en VM VirtualBox
- 💻 **Después:** Instalar en notebook física

**Estructura de subvolúmenes:** Estándar `@` y `@home` (compatible con grub-btrfs automático)

**Perfiles de escritorio:**
- KDE Plasma estilo Windows / AnduinOS-like: [escritorios/KDE_Windows/README.md](escritorios/KDE_Windows/README.md)

---

## 🟢 Estado de Validación

| Fase | Estado | Notas |
|------|--------|-------|
| **Secciones 1-8** | ✅ Completadas | Instalación base, Snapper, btrbk, grub-btrfs validados y funcionando |
| **Sección 9** | ✅ Validada | Entrada de emergencia en GRUB creada y verificada |
| **Sección 13.1** | ✅ Completada | Snapshot "Sistema base listo" creado y respaldado en sda3 |
| **VM VirtualBox** | 🟢 **LISTA** | Todas las características probadas y funcionando. Proceder a instalación física o personalización. |

---



## 📋 Tabla de Contenidos

1. [Preparación](#1-preparación)
   - [1.1 Descargas necesarias](#11-descargas-necesarias)
   - [1.2 Configuración VM VirtualBox](#12-configuración-vm-virtualbox)
   - [1.3 Configuración adicional (antes de arrancar)](#13-configuración-adicional-antes-de-arrancar)
2. [Instalación Base Debian](#2-instalación-base-debian)
   - [2.1 Arrancar instalador](#21-arrancar-instalador)
   - [2.2 Configuración inicial](#22-configuración-inicial)
   - [2.3 Configuración de usuarios](#23-configuración-de-usuarios)
   - [2.4 Configuración de reloj](#24-configuración-de-reloj)
   - [2.5 Particionado de discos CRÍTICO](#25-particionado-de-discos-crítico)
   - [2.6 Instalación del sistema base](#26-instalación-del-sistema-base)
   - [2.7 Instalación de GRUB](#27-instalación-de-grub)
   - [2.8 Finalizar instalación](#28-finalizar-instalación)
3. [Configuración de Subvolúmenes BTRFS](#3-configuración-de-subvolúmenes-btrfs)
   - [3.1 Limpiar /etc/fstab](#31-limpiar-etcfstab-prevenir-demoras-en-arranque)
   - [3.2 Apagar sistema y arrancar Rescue Mode](#32-apagar-sistema-y-arrancar-rescue-mode)
   - [3.3 Arrancar en Rescue Mode](#33-arrancar-en-rescue-mode)
   - [3.4 Renombrar a estructura estándar y crear @home](#34-renombrar-a-estructura-estándar-y-crear-home)
   - [3.5 Verificación crítica del renombrado](#s3-verificacion-renombrado)
   - [3.6 Actualizar /etc/fstab](#36-actualizar-etcfstab)
   - [3.7 Reinstalar GRUB después de cambios](#s3-reinstalar-grub)
   - [3.8 Al reiniciar debe ocurrir](#s3-al-reiniciar)
   - [3.9 Si el sistema no arranca](#s3-si-no-arranca)
   - [3.10 Verificar configuración](#310-verificar-configuración)
   - [3.11 Quitar ISO y arrancar sistema](#311-quitar-iso-y-arrancar-sistema)
   - [3.12 Verificar arranque con subvolúmenes](#312-verificar-arranque-con-subvolúmenes)
4. [Configurar acceso SSH (Opcional pero recomendado)](#4-configurar-acceso-ssh-opcional-pero-recomendado)
   - [4.1 Instalar y configurar SSH en Debian](#41-instalar-y-configurar-ssh-en-debian)
   - [4.2 Configuración para VirtualBox (Port Forwarding)](#42-configuración-para-virtualbox-port-forwarding)
   - [4.3 Conectarse por SSH desde Windows](#43-conectarse-por-ssh-desde-windows)
   - [4.4 Conectarse desde Linux/Mac](#44-conectarse-desde-linuxmac)
   - [4.5 Configuración alternativa: Modo Bridge (IP directa)](#45-configuración-alternativa-modo-bridge-ip-directa)
   - [4.6 Configuración de seguridad básica (Opcional)](#46-configuración-de-seguridad-básica-opcional)
   - [4.7 Transferir archivos por SCP/SFTP](#47-transferir-archivos-por-scpsftp)
   - [4.8 Troubleshooting SSH](#48-troubleshooting-ssh)
5. [VirtualBox Guest Additions](#5-virtualbox-guest-additions)
   - [5.1 Instalar dependencias](#51-instalar-dependencias)
   - [5.2 Insertar ISO de Guest Additions](#52-insertar-iso-de-guest-additions)
   - [5.3 Montar y ejecutar instalador](#53-montar-y-ejecutar-instalador)
   - [5.4 Verificar instalación](#54-verificar-instalación)
   - [5.5 Habilitar funciones](#55-habilitar-funciones)
6. [Configuración de Snapper](#6-configuración-de-snapper)
   - [6.1 Instalar paquetes](#61-instalar-paquetes)
   - [6.2 Crear configuración de Snapper](#62-crear-configuración-de-snapper)
   - [6.3 Configurar retención](#63-configurar-retención-solo-eventos-no-tiempo)
   - [6.4 Configurar snapshots PRE/POST para APT](#64-configurar-snapshots-prepost-para-apt)
   - [6.5 Habilitar servicios de Snapper](#65-habilitar-servicios-de-snapper)
   - [6.6 Probar funcionamiento](#66-probar-funcionamiento)
   - [6.7 Snapshots para /home (opcional)](#67-snapshots-para-home-opcional)
7. [Configuración de btrbk](#7-configuración-de-btrbk)
   - [7.1 Instalar btrbk](#71-instalar-btrbk)
   - [7.2 Preparar montajes](#72-preparar-montajes)
   - [7.3 Crear configuración de btrbk](#73-crear-configuración-de-btrbk)
   - [7.4 Preparar partición de recuperación](#74-preparar-partición-de-recuperación)
   - [7.5 Probar btrbk](#75-probar-btrbk)
   - [7.6 Configurar protección estricta de partición de recuperación](#76-configurar-protección-estricta-de-partición-de-recuperación)
   - [7.7 Estado normal de la partición de recuperación](#77-estado-normal-de-la-partición-de-recuperación)
   - [7.8 Automatizar btrbk (hibrido: evento + timer)](#78-automatizar-btrbk-hibrido-evento--timer)
   - [7.9 Snapshot manual para cambios no-APT (`snapcfg`)](#79-snapshot-manual-para-cambios-no-apt-snapcfg)
8. [grub-btrfs](#8-grub-btrfs)
   - [8.1 Instalación manual desde GitHub](#81-instalación-manual-desde-github)
   - [8.2 Configurar grub-btrfs](#82-configurar-grub-btrfs-simplificado-con-)
   - [8.3 Habilitar servicio](#83-habilitar-servicio)
   - [8.4 Actualizar GRUB](#84-actualizar-grub)
   - [8.5 Verificar en próximo reinicio](#85-verificar-en-próximo-reinicio)
9. [Entrada de Emergencia en GRUB](#9-entrada-de-emergencia-en-grub)
   - [9.1 Obtener información necesaria](#91-obtener-información-necesaria)
   - [9.2 Crear entrada custom en GRUB](#92-crear-entrada-custom-en-grub)
   - [9.3 Actualizar GRUB](#93-actualizar-grub)
   - [9.4 Probar entrada (opcional)](#94-probar-entrada-opcional)
10. [Procedimientos de Recuperación](#10-procedimientos-de-recuperación)
   - [10.1 Crear documento de procedimientos](#101-crear-documento-de-procedimientos)
   - [10.2 Crear Live USB de recuperación](#102-crear-live-usb-de-recuperación)
11. [Instalación en Notebook Física](#11-instalación-en-notebook-física)
   - [11.1 Diferencias VM vs Notebook](#111-diferencias-vm-vs-notebook)
   - [11.2 Preparación notebook](#112-preparación-notebook)
   - [11.3 Ajustes específicos para notebook](#113-ajustes-específicos-para-notebook)
   - [11.4 Checklist de instalación en notebook](#114-checklist-de-instalación-en-notebook)
12. [Verificación y Mantenimiento](#12-verificación-y-mantenimiento)
   - [12.1 Comandos de verificación diaria](#121-comandos-de-verificación-diaria)
   - [12.2 Mantenimiento semanal](#122-mantenimiento-semanal)
   - [12.3 Mantenimiento mensual](#123-mantenimiento-mensual)
   - [12.4 Script de verificación automática](#124-script-de-verificación-automática)
13. [Próximos Pasos](#13-próximos-pasos)
   - [13.1 Crear snapshot "Sistema base listo"](#131-crear-snapshot-sistema-base-listo)
   - [13.2 Instalar entorno de escritorio](#132-instalar-entorno-de-escritorio)
   - [13.3 Personalización (Windows 11 style)](#133-personalización-windows-11-style)

---

---

## 1. Preparación

### 1.1 Descargas necesarias

```bash
# ISO de Debian 13 (Trixie) netinstall
URL: https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/
Archivo: debian-13.X.X-amd64-netinst.iso (~600 MB)

# Live USB Debian (para recuperación)
URL: https://cdimage.debian.org/debian-cd/current-live/amd64/iso-hybrid/
Archivo: debian-live-13.X.X-amd64-standard.iso
```

### 1.2 Configuración VM VirtualBox

```
Click en "Nueva"

Configuración básica:
├── Nombre: Debian-BTRFS-Production
├── Carpeta: [tu carpeta de VMs]
├── Tipo: Linux
├── Versión: Debian (64-bit)
└── ISO: debian-13.X.X-amd64-netinst.iso

Memoria y procesador:
├── RAM: 4096 MB (4 GB)
└── CPUs: 2

Disco duro:
├── Tamaño: 80 GB
├── Tipo: VDI
└── Almacenamiento: Dinámicamente asignado

Finalizar
```

### 1.3 Configuración adicional (antes de arrancar)

```
VM → Settings → System → Motherboard:
✅ Enable UEFI (special OSes only)

VM → Settings → System → Processor:
Processors: 2

VM → Settings → Display:
Video Memory: 128 MB

VM → Settings → Network:
Adapter 1: NAT (por defecto OK)

Iniciar VM
```

---

## 2. Instalación Base Debian

### 2.1 Arrancar instalador

**Opción A: Instalación Gráfica (RECOMENDADA)** ⭐

```
Menú GRUB del instalador:
→ Selecciona: "Graphical install"
→ Enter
```

**Ventajas:**
- Interfaz gráfica más clara e intuitiva
- Menos propenso a errores
- Particionado manual disponible en el asistente
- Recomendado para esta guía

---

**Opción B: Expert Install (Alternativa)**

```
Menú GRUB del instalador:
→ Selecciona: "Advanced options..."
→ Selecciona: "... Expert install"
→ Enter
```

**Ventajas:**
- Control granular en cada paso
- Instalación más rápida (sin interfaz gráfica)
- Para usuarios avanzados

---

**En cualquiera de las dos opciones:**
- Particionado: Seleccionar "Manual" cuando se pida
- Software: Desmarcar escritorio (instalar solo SSH + utilidades estándar)

### 2.2 Configuración inicial

```
Choose language: [tu idioma preferido]
Select your location: [tu país]
Configure locales: [configurar según necesidad]
Configure keyboard: [tu teclado]

Configure the network:
├── Auto-configure: Yes
├── Hostname: debian-btrfs
└── Domain name: [dejar vacío]
```

### 2.3 Configuración de usuarios

```
⚠️ IMPORTANTE: Crear usuario con privilegios sudo (NO root directo)

Set up users and passwords:
├── Allow login as root?: No  ← IMPORTANTE
├── Full name: [Tu nombre]
├── Username: [tu_usuario]  ← Ejemplo: admin
└── Password: [contraseña segura]
```

### 2.4 Configuración de reloj

```
Configure the clock:
└── Select your time zone: [tu zona horaria]
```

### 2.5 Particionado de discos **CRÍTICO**

**Método de particionado:**

```
Partition disks:
→ Manual
```

**Crear tabla de particiones:**

```
Seleccionar: SCSI (0,0,0) (sda) - 80 GB
→ Create new empty partition table on this device?: Yes
→ Partition table type: gpt
```

**Crear particiones:**

#### **Partición 1: EFI (512 MB)**

```
Seleccionar: pri/log FREE SPACE
→ Create a new partition
Size: 512 MB
Type: Primary
Location: Beginning

Use as: EFI System Partition
Bootable flag: On
Done setting up the partition
```

#### **Partición 2: Sistema BTRFS (60 GB)**

```
Seleccionar: FREE SPACE
→ Create a new partition
Size: 60 GB
Location: Beginning

Use as: btrfs journaling file system
Mount point: /
Mount options: noatime
Label: system
Done setting up the partition
```

#### **Partición 3: Recuperación BTRFS (10 GB)**

```
Seleccionar: FREE SPACE
→ Create a new partition
Size: 10 GB
Location: Beginning

Use as: btrfs journaling file system
Mount point: Enter manually → /mnt/backup
Mount options: noatime
Label: recovery
Done setting up the partition
```

#### **Partición 4: SWAP (resto)**

```
Seleccionar: FREE SPACE
→ Create a new partition
Size: [aceptar todo el espacio restante]
Location: Beginning

Use as: swap area
Done setting up the partition
```

**Resumen de particionado:**

```
/dev/sda1   512 MB    EFI System Partition
/dev/sda2    60 GB    btrfs (/)
/dev/sda3    10 GB    btrfs (/mnt/backup)
/dev/sda4   ~10 GB    swap
```

**Finalizar particionado:**

```
→ Finish partitioning and write changes to disk
→ Write changes to disks?: Yes
```

### 2.6 Instalación del sistema base

```
Configure the package manager:
├── Scan extra installation media?: No
├── Debian archive mirror country: [tu país o cercano]
├── Debian archive mirror: deb.debian.org
└── HTTP proxy: [dejar vacío si no usas]

Participate in package usage survey?: No

Software selection:
❌ DESMARCAR TODO excepto:
  ✅ SSH server
  ✅ standard system utilities

→ Continue (instalará paquetes base, ~5-10 minutos)
```

### 2.7 Instalación de GRUB

```
Install the GRUB boot loader:
→ Yes

Device for boot loader installation:
→ /dev/sda (disco completo, NO particiones)

Force GRUB installation to removable media path?:
→ No

Update NVRAM variables to automatically boot into Debian?:
→ Yes

Run os-prober automatically?:
→ No
```

### 2.8 Finalizar instalación

```
Finish the installation:
→ Continue

VM reiniciará...
```

**Configuración post-primer-boot:**

```
debian-btrfs login: tu_usuario
Password: [tu contraseña]

# Verificar particiones
lsblk

# Deberías ver:
sda      80G
├─sda1  512M  [EFI]
├─sda2   60G  /
├─sda3   10G  /mnt/backup
└─sda4   10G  [SWAP]
```

---

## 3. Configuración de Subvolúmenes BTRFS

⚠️ **Este paso es CRÍTICO - Crear estructura estándar @ y @home**


### 3.1 Limpiar /etc/fstab (Prevenir demoras en arranque)

**⚠️ IMPORTANTE - Hacer inmediatamente después del primer arranque**

Durante la instalación, Debian agrega automáticamente una entrada para el CD-ROM en `/etc/fstab` 
que causa demoras de 30+ segundos al arrancar si no hay un disco insertado.

**Paso 1:** Revisar el archivo
```bash
cat /etc/fstab
```

**Paso 2:** Editar el archivo
```bash
sudo nano /etc/fstab
```

**Paso 3:** Comentar la línea del CD-ROM
Busca una línea similar a:
```
/dev/sr0    /media/cdrom0    udf,iso9660    user,noauto    0    0
```

Agrégale `#` al inicio:
```
# /dev/sr0    /media/cdrom0    udf,iso9660    user,noauto    0    0
```

**Paso 4:** Guardar y salir
- Ctrl+O → Enter → Ctrl+X

**Paso 5:** Verificar sintaxis
```bash
sudo mount -a
# No debe mostrar errores
```

**Paso 6:** Reiniciar para verificar
```bash
sudo reboot
```

**Resultado esperado:**
✅ El sistema debe arrancar en ~10-15 segundos sin quedarse esperando en mensajes RCU

---

### 3.2 Apagar sistema y arrancar Rescue Mode

```bash
# Desde el sistema instalado
sudo poweroff
```

**En VirtualBox:**

```
VM apagada → Settings → Storage
Controller: IDE → Click en disco vacío
→ Click icono disco (derecha)
→ Choose a disk file...
→ Seleccionar: debian-13.X.X-amd64-netinst.iso
→ OK

Iniciar VM
```

**Si VM arranca desde disco (no ISO):**

**Método 1: Desde menú GRUB (RECOMENDADO para VirtualBox)**

Si GRUB ya está instalado:
```
1. Al aparecer el menú de GRUB
2. Seleccionar: "UEFI Firmware Settings"
3. Presionar Enter
4. En el menú UEFI, seleccionar: "Boot Manager"
5. Seleccionar: "UEFI VBOX CD-ROM VB0-01f003f6"
6. Presionar Enter
```
→ Aparecerá el menú del instalador Debian

**Método 2: Tecla F12 al arrancar**
```
1. Reiniciar la VM
2. Presionar F12 inmediatamente (antes de GRUB)
3. Seleccionar: CD-ROM/DVD
```
⚠️ Puede no funcionar en todas las configuraciones de VirtualBox

**Método 3: Desmontar disco temporalmente**
```
1. Apagar la VM
2. Settings → Storage → SATA Controller
3. Click derecho en disco → Remove Attachment
4. OK → Iniciar VM
5. Después de usar el CD, volver a adjuntar el disco
```


---

### 💡 NOTA: Acceso a UEFI Firmware Settings

**Este método funciona en:**
- ✅ VirtualBox con UEFI habilitado
- ✅ Hardware físico con UEFI
- ✅ Notebooks modernos (2012+)

**Ventajas:**
- No depende de timing (presionar tecla en momento exacto)
- Funciona aunque el host capture las teclas F12/ESC/F2
- Interfaz visual clara
- Método estándar UEFI

**Disponible desde:**
- Menú de GRUB (opción "UEFI Firmware Settings")
- Systemd boot
- Cualquier bootloader UEFI moderno

---


### 3.3 Arrancar en Rescue Mode

```
Menú GRUB del instalador:
→ Advanced options...
→ ... Rescue mode
→ Enter

Configurar idioma, red, etc. (como antes)

Device to use as root file system:
→ Do not use a root file system
→ Continue

Execute a shell:
→ Execute a shell in the installer environment
→ Continue

Presionar Enter en mensaje informativo
```

### 3.4 Renombrar a estructura estándar y crear @home

**Comandos a ejecutar:**

```bash
# Crear punto de montaje
mkdir /mnt/btrfs

# Montar partición BTRFS
mount /dev/sda2 /mnt/btrfs

# Verificar contenido (instalador creó @rootfs)
ls /mnt/btrfs
# Output: @rootfs

# Listar subvolúmenes existentes
btrfs subvolume list /mnt/btrfs
# Output: ID 256 gen X top level 5 path @rootfs

# ⚠️ CRÍTICO: RENOMBRAR a nombre estándar @
# El instalador crea @rootfs pero grub-btrfs requiere @
# Este cambio es OBLIGATORIO para que grub-btrfs funcione correctamente

mv /mnt/btrfs/@rootfs /mnt/btrfs/@

# Verificar renombrado (DEBE mostrar @ NO @rootfs)
ls /mnt/btrfs
# Output esperado: @

# Verificar subvolumen
btrfs subvolume list /mnt/btrfs
# Output esperado: ID 256 gen X top level 5 path @
# ⚠️ Si ves @rootfs, el renombrado NO se hizo correctamente

# Crear subvolumen @home
btrfs subvolume create /mnt/btrfs/@home

# Verificar creación
ls /mnt/btrfs
# Output: @  @home

btrfs subvolume list /mnt/btrfs
# Output:
# ID 256 ... path @
# ID 257 ... path @home

# Mover contenido de home del usuario
mv /mnt/btrfs/@/home/* /mnt/btrfs/@home/ 2>/dev/null || true

# Verificar movimiento
ls /mnt/btrfs/@home/
# Debe mostrar tu usuario

ls /mnt/btrfs/@/home/
# Debe estar vacío
```


<a id="s3-verificacion-renombrado"></a>
### 3.5 ✅ Verificación CRÍTICA del renombrado (OBLIGATORIO)

**Antes de continuar, verifica que el renombrado fue exitoso:**

```bash
# Montar partición root
mount -o subvolid=5 /dev/sda2 /mnt/btrfs

# Verificar contenido (DEBE mostrar @ NO @rootfs)
ls -la /mnt/btrfs/

# Verificar subvolúmenes
btrfs subvolume list /mnt/btrfs
```

**Output CORRECTO:**
```
ID 256 gen X top level 5 path @
ID 257 gen X top level 5 path @home
```

**Output INCORRECTO (ERROR):**
```
ID 256 gen X top level 5 path @rootfs    ← ⚠️ PROBLEMA
```

**Si ves @rootfs:**
```bash
# Renombrar nuevamente
cd /mnt/btrfs
mv @rootfs @
ls -la  # Verificar que ahora muestre @
```

**⚠️ CONSECUENCIAS de NO renombrar correctamente:**
- ❌ Sistema NO arrancará (error: "unknown filesystem")
- ❌ grub-btrfs NO detectará snapshots
- ❌ fstab con subvol=@ pero subvolumen llamado @rootfs = fallo total

---


### 3.6 Actualizar /etc/fstab

**Obtener UUIDs:**

```bash
# UUID de sda2 (sistema)
blkid /dev/sda2
# Copiar UUID (ej: 1234-5678-90ab-cdef)

# UUID de sda3 (recuperación)
blkid /dev/sda3
# Copiar UUID (ej: abcd-efgh-1234-5678)
```

**Editar fstab:**

```bash
nano /mnt/btrfs/@/etc/fstab
```

**Modificar las líneas de BTRFS y agregar nuevas:**

```
# ANTES (buscar líneas existentes):
UUID=xxxx  /  btrfs  defaults,noatime,subvol=@rootfs  0  0
UUID=yyyy  /mnt/backup  btrfs  noatime  0  0

# CAMBIAR A (usar tus UUIDs reales):
UUID=1234-5678-90ab-cdef  /  btrfs  subvol=@,compress=zstd:3,noatime  0  0
UUID=1234-5678-90ab-cdef  /home  btrfs  subvol=@home,compress=zstd:3,noatime  0  0
UUID=abcd-efgh-1234-5678  /mnt/backup  btrfs  noauto,compress=zstd:3,noatime  0  0
UUID=1234-5678-90ab-cdef  /mnt/btrfs-root  btrfs  subvolid=5,noauto,compress=zstd:3  0  0

# ⚠️ CRÍTICO: Verificar nombre de subvolumen
# - DEBE ser: subvol=@
# - NO usar: subvol=@rootfs (causará fallo de arranque)
# - El renombrado debe haberse hecho en el paso anterior
# - Mantener líneas de /boot/efi y swap sin cambios
```

**Guardar:** Ctrl+O, Enter, Ctrl+X


<a id="s3-reinstalar-grub"></a>
### 3.7 ⚠️ CRÍTICO: Reinstalar GRUB después de cambios

**IMPORTANTE:** Después de renombrar subvolúmenes y editar fstab, 
DEBES reinstalar GRUB para que use la nueva configuración.

**Si no haces esto, el sistema NO arrancará.**

---

#### Paso 1: Desmontar y remontar correctamente

```bash
# Salir del directorio de trabajo
cd /

# Desmontar todo (si ya estaba montado)
umount /mnt/btrfs/@/boot/efi 2>/dev/null
umount /mnt/btrfs/@/dev 2>/dev/null
umount /mnt/btrfs/@/proc 2>/dev/null
umount /mnt/btrfs/@/sys 2>/dev/null
umount /mnt/btrfs/@ 2>/dev/null
umount /mnt/btrfs 2>/dev/null
```

#### Paso 2: Montar el sistema para chroot

```bash
# Montar el subvolumen @ directamente en /mnt
mount -o subvol=@ /dev/sda2 /mnt

# Montar partición EFI
mount /dev/sda1 /mnt/boot/efi

# Montar filesystems virtuales (necesarios para GRUB)
mount --bind /dev /mnt/dev
mount --bind /proc /mnt/proc
mount --bind /sys /mnt/sys
```

**Verificar que todo esté montado:**

```bash
mount | grep /mnt
```

Debes ver:
```
/dev/sda2 on /mnt type btrfs (...subvol=@...)
/dev/sda1 on /mnt/boot/efi type vfat
devtmpfs on /mnt/dev
proc on /mnt/proc
sysfs on /mnt/sys
```

#### Paso 3: Entrar al sistema (chroot)

```bash
chroot /mnt
```

Tu prompt debería cambiar. Ahora estás "dentro" del sistema instalado.

#### Paso 4: Reinstalar GRUB

```bash
grub-install /dev/sda
```

**Salida esperada:**
```
Installing for x86_64-efi platform.
grub-install: warning: EFI variables cannot be set on this system.
grub-install: warning: You will have to complete the GRUB setup manually.
Installation finished. No error reported.
```

⚠️ Los warnings son **NORMALES** en Rescue Mode. Ignóralos.

#### Paso 5: Actualizar configuración de GRUB

```bash
update-grub
```

**Salida esperada:**
```
Generating grub configuration file
Found linux image: /boot/vmlinuz-6.12.74+deb13+1-amd64
Found initrd image: /boot/initrd.img-6.12.74+deb13+1-amd64
...
done
```

#### Paso 6: Verificar que GRUB se instaló correctamente

**Verificaciones OBLIGATORIAS:**

```bash
# 1. Verificar archivos EFI
ls /boot/efi/EFI/debian/
# Debe contener: grubx64.efi, shimx64.efi

# 2. Verificar grub.cfg
ls -lh /boot/grub/grub.cfg
# Debe existir y tener ~8KB

# 3. CRÍTICO: Verificar que use subvol=@ (NO @rootfs)
grep "subvol" /boot/grub/grub.cfg | head -5
```

**Salida CORRECTA del último comando:**
```
linux /@/boot/vmlinuz... root=UUID=... rootflags=subvol=@ quiet
```

**Salida INCORRECTA (ERROR):**
```
linux /@/boot/vmlinuz... root=UUID=... rootflags=subvol=@rootfs quiet
                                                            ^^^^^^^^
                                                            ¡PROBLEMA!
```

**Si ves `@rootfs` en lugar de `@`:**
```bash
# Algo salió mal. Verifica:
cat /etc/fstab | grep " / "
# Debe decir: subvol=@

# Si fstab está bien, ejecuta nuevamente:
update-grub
grep "subvol" /boot/grub/grub.cfg | head -3
```

#### Paso 7: Salir del chroot

```bash
exit
```

#### Paso 8: Desmontar todo

```bash
# Desmontar en orden inverso
umount /mnt/sys
umount /mnt/proc
umount /mnt/dev
umount /mnt/boot/efi
umount /mnt
```

#### Paso 9: Reiniciar

```bash
reboot
```

---

<a id="s3-al-reiniciar"></a>
### 3.8 ✅ Al reiniciar debe ocurrir:

1. **Aparece el menú de GRUB** automáticamente
2. **Selecciona "Debian GNU/Linux"**
3. **El sistema arranca sin errores**
4. **NO se queda esperando** (RCU stall)

---

<a id="s3-si-no-arranca"></a>
### 3.9 ❌ Si el sistema NO arranca:

**Síntoma 1:** Queda en shell de GRUB (`grub>`)
→ Ve a sección 9.3: Recuperación de GRUB

**Síntoma 2:** Error "unknown filesystem"
→ El nombre del subvolumen no coincide. Verifica:
```grub
ls (hd0,gpt2)/@/
ls (hd0,gpt2)/@rootfs/
```
El que funcione es el nombre real.

**Síntoma 3:** Se queda esperando 30+ segundos (RCU stall)
→ Revisa `/etc/fstab` y comenta la línea del CD-ROM

---


### 3.10 Verificar configuración

```bash
# Verificar sintaxis de fstab
cat /mnt/btrfs/@/etc/fstab

# Listar subvolúmenes finales
btrfs subvolume list /mnt/btrfs
# Debe mostrar:
# ID 256 ... path @
# ID 257 ... path @home

# Desmontar
umount /mnt/btrfs

# Salir del rescue mode
exit

# Seleccionar: Reboot the system
# → Continue
```

### 3.11 Quitar ISO y arrancar sistema

```
Cuando VM se apague/reinicie:

VirtualBox → Detener VM si no se apagó sola

Settings → Storage → Controller: IDE
→ Click en ISO → Click icono disco (derecha)
→ Remove disk from virtual drive

Si desmontaste el disco (Opción B):
Settings → Storage → Controller: SATA
→ Add Hard Disk → Choose existing disk
→ Seleccionar tu .vdi

OK → Iniciar VM
```

### 3.12 Verificar arranque con subvolúmenes

```bash
# Login con tu usuario

# Verificar montajes
mount | grep btrfs

# Deberías ver:
# /dev/sda2 on / type btrfs (rw,...,compress=zstd:3,subvol=/@)
# /dev/sda2 on /home type btrfs (rw,...,compress=zstd:3,subvol=/@home)

# Verificar subvolúmenes
sudo btrfs subvolume show /
# Debe mostrar: Name: @

sudo btrfs subvolume show /home
# Debe mostrar: Name: @home

# Ver espacio
df -h

# Todo OK ✅
```

---

## 4. Configurar acceso SSH (Opcional pero recomendado)

**¿Por qué configurar SSH antes que el entorno gráfico?**

Trabajar desde la consola de VirtualBox es incómodo:
- ❌ No puedes copiar/pegar comandos fácilmente
- ❌ Resolución limitada
- ❌ No puedes usar tu terminal favorito

Con SSH puedes:
- ✅ Conectarte desde PuTTY, MobaXterm, Windows Terminal
- ✅ Copiar/pegar comandos
- ✅ Trabajar cómodamente desde tu máquina host
- ✅ Transferir archivos con SCP/SFTP

---

### 4.1 Instalar y configurar SSH en Debian

#### Paso 1: Instalar openssh-server

```bash
sudo apt update
sudo apt install openssh-server -y
```

#### Paso 2: Verificar que SSH está activo

```bash
sudo systemctl status sshd
```

**Salida esperada:**
```
● ssh.service - OpenBSD Secure Shell server
   Active: active (running)
```

Si NO está activo:
```bash
sudo systemctl enable --now ssh
```

#### Paso 3: Verificar puerto y configuración

```bash
sudo ss -tlnp | grep :22
```

Debe mostrar:
```
LISTEN 0 128 0.0.0.0:22  0.0.0.0:*  users:(("sshd",pid=...))
```

#### Paso 4: Obtener IP de la VM

```bash
ip -4 addr show | grep inet
```

Anota la IP (ejemplo: `10.0.2.15` en NAT o `192.168.x.x` en Bridge)

---

### 4.2 Configuración para VirtualBox (Port Forwarding)

**Si tu VM usa red en modo NAT (configuración por defecto):**

#### Opción A: Desde interfaz gráfica de VirtualBox

1. **Apaga la VM** (o hazlo con la VM encendida, algunos pasos se pueden hacer en caliente)
2. VirtualBox → **Configuración** de la VM
3. **Red** → Adaptador 1 (debe estar en **NAT**)
4. Click en **Avanzadas** → **Reenvío de puertos**
5. Click en **+** (agregar regla)

**Configurar regla:**
```
Nombre:     SSH
Protocolo:  TCP
IP anfitrión: (dejar vacío)
Puerto anfitrión: 2222
IP invitado: (dejar vacío)
Puerto invitado: 22
```

6. Click **OK** → **OK**
7. Arrancar la VM

#### Opción B: Desde línea de comandos (más rápido)

**Con la VM apagada:**

```bash
# Reemplaza "Debian-BTRFS-Production" por el nombre de tu VM
VBoxManage modifyvm "Debian-BTRFS-Production" --natpf1 "SSH,tcp,,2222,,22"
```

**Verificar que se agregó:**
```bash
VBoxManage showvminfo "Debian-BTRFS-Production" | grep "NIC 1 Rule"
```

Debe mostrar:
```
NIC 1 Rule(0):   name = SSH, protocol = tcp, host ip = , host port = 2222, guest ip = , guest port = 22
```

---

### 4.3 Conectarse por SSH desde Windows

#### Método 1: PuTTY

1. **Descargar PuTTY**: https://www.putty.org/
2. Abrir PuTTY
3. Configurar:
   ```
   Host Name: localhost
   Port: 2222
   Connection Type: SSH
   ```
4. Click **Open**
5. Aceptar el fingerprint del servidor (primera vez)
6. Login:
   ```
   login as: administrador
   password: [tu contraseña]
   ```

#### Método 2: MobaXterm (RECOMENDADO)

1. **Descargar MobaXterm**: https://mobaxterm.mobatek.net/
2. Abrir MobaXterm
3. Click **Session** → **SSH**
4. Configurar:
   ```
   Remote host: localhost
   Port: 2222
   Username: administrador
   ```
5. Click **OK**
6. Ingresar contraseña

**Ventajas de MobaXterm:**
- ✅ Terminal con copiar/pegar mejorado
- ✅ Explorador de archivos integrado (SFTP)
- ✅ Túneles X11 para aplicaciones gráficas
- ✅ Editor de texto integrado

#### Método 3: Windows Terminal + OpenSSH

**Windows 10/11 ya incluye cliente SSH:**

```powershell
# Desde PowerShell o CMD
ssh administrador@localhost -p 2222
```

Primera vez:
```
The authenticity of host '[localhost]:2222' can't be established.
Are you sure you want to continue connecting (yes/no)? yes
```

---

### 4.4 Conectarse desde Linux/Mac

```bash
ssh administrador@localhost -p 2222
```

O si prefieres especificar la clave:
```bash
ssh -p 2222 administrador@localhost
```

---

### 4.5 Configuración alternativa: Modo Bridge (IP directa)

**Si prefieres que la VM tenga IP en tu red local:**

#### Ventajas:
- ✅ La VM tiene IP propia en tu red (ej: 192.168.1.150)
- ✅ No necesitas port forwarding
- ✅ Más simple para redes complejas

#### Desventajas:
- ❌ Depende de tu router/DHCP
- ❌ IP puede cambiar si no es estática

#### Configurar en VirtualBox:

1. **Apagar la VM**
2. VirtualBox → **Configuración**
3. **Red** → Adaptador 1
4. **Conectado a:** Cambiar de **NAT** a **Adaptador puente**
5. **Nombre:** Seleccionar tu adaptador de red físico
6. **OK**
7. Arrancar VM

#### Dentro de Debian:

```bash
# Verificar IP asignada
ip -4 addr show
```

Verás algo como:
```
inet 192.168.1.150/24 brd 192.168.1.255 scope global dynamic enp0s3
```

#### Conectar desde Windows/Linux:

```bash
# Usar la IP directamente (sin port forwarding)
ssh administrador@192.168.1.150
```

---

### 4.6 Configuración de seguridad básica (Opcional)

**Si vas a exponer SSH a internet o red insegura:**

#### Deshabilitar login de root por SSH:

```bash
sudo nano /etc/ssh/sshd_config
```

Cambiar o agregar:
```
PermitRootLogin no
```

Guardar (Ctrl+O, Enter, Ctrl+X) y reiniciar:
```bash
sudo systemctl restart sshd
```

#### Cambiar puerto SSH (evitar escaneos):

```bash
sudo nano /etc/ssh/sshd_config
```

Cambiar:
```
Port 22
```
Por:
```
Port 2244
```

Guardar y reiniciar:
```bash
sudo systemctl restart sshd
```

**Importante:** Si cambias el puerto, también debes cambiar el port forwarding en VirtualBox.

---

### 4.7 Transferir archivos por SCP/SFTP

#### Desde Windows (MobaXterm):
- MobaXterm ya incluye explorador de archivos integrado
- Arrastra y suelta archivos

#### Desde línea de comandos:

**Copiar archivo del host a la VM:**
```bash
scp -P 2222 archivo.txt administrador@localhost:/home/administrador/
```

**Copiar archivo de la VM al host:**
```bash
scp -P 2222 administrador@localhost:/home/administrador/archivo.txt ./
```

**Copiar directorio completo:**
```bash
scp -P 2222 -r carpeta/ administrador@localhost:/home/administrador/
```

---

### 4.8 Troubleshooting SSH

#### Problema: "Connection refused"

```bash
# Verificar que SSH está corriendo
sudo systemctl status sshd

# Verificar firewall (si está activo)
sudo ufw status
sudo ufw allow 22/tcp

# Verificar puerto
sudo ss -tlnp | grep :22
```

#### Problema: "Permission denied (publickey)"

```bash
# Verificar que se permite autenticación por contraseña
sudo nano /etc/ssh/sshd_config
```

Debe tener:
```
PasswordAuthentication yes
```

Reiniciar:
```bash
sudo systemctl restart sshd
```

#### Problema: No puedo conectarme con port forwarding

```bash
# Verificar regla en VirtualBox
VBoxManage showvminfo "Debian-BTRFS-Production" | grep "NIC 1 Rule"

# Verificar que la VM usa NAT
VBoxManage showvminfo "Debian-BTRFS-Production" | grep "NIC 1"
```

---

### ✅ Verificación final

**Desde tu máquina host, conecta por SSH:**

```bash
ssh administrador@localhost -p 2222
```

**Debes poder:**
- ✅ Iniciar sesión con tu contraseña
- ✅ Copiar y pegar comandos
- ✅ Trabajar cómodamente

---

**Ahora puedes continuar con la configuración desde tu terminal favorito.**

---


## 5. VirtualBox Guest Additions

⚠️ **Hacer ANTES de instalar Snapper/btrbk para tener copiar/pegar funcionando**

### 5.1 Instalar dependencias

```bash
# Actualizar sistema
sudo apt update
sudo apt upgrade -y

# Instalar herramientas de compilación
sudo apt install -y build-essential dkms linux-headers-$(uname -r)
```

### 5.2 Insertar ISO de Guest Additions

```
Menú VirtualBox (arriba):
→ Devices (Dispositivos)
→ Insert Guest Additions CD image...
```

### 5.3 Montar y ejecutar instalador

```bash
# Crear punto de montaje
sudo mkdir -p /mnt/cdrom

# Montar CD
sudo mount /dev/sr0 /mnt/cdrom

# Verificar contenido
ls /mnt/cdrom
# Debe mostrar: VBoxLinuxAdditions.run

# Ejecutar instalador
sudo /mnt/cdrom/VBoxLinuxAdditions.run

# Salida esperada:
# Building modules...
# Installing modules...
# VirtualBox Guest Additions: Starting.
# (puede mostrar warnings sobre sistema gráfico - OK)

# Desmontar CD
sudo umount /mnt/cdrom

# Reiniciar
sudo reboot
```

### 5.4 Verificar instalación

```bash
# Login después de reinicio

# Verificar módulos cargados
lsmod | grep vbox

# Deberías ver:
# vboxguest
# vboxsf
# vboxvideo

# Ver versión
VBoxControl --version
```

### 5.5 Habilitar funciones

**En el menú de VirtualBox:**

```
Devices → Shared Clipboard → Bidirectional
Devices → Drag and Drop → Bidirectional
```

**Probar copiar/pegar:**
- Copiar texto del host
- Pegar en terminal de VM con Ctrl+Shift+V
- ✅ Debe funcionar

---

## 6. Configuración de Snapper

### 6.1 Instalar paquetes

```bash
# Instalar Snapper y herramientas BTRFS
sudo apt install -y btrfs-progs snapper inotify-tools

# Herramientas adicionales útiles
sudo apt install -y vim curl wget net-tools
```

### 6.2 Crear configuración de Snapper

```bash
# Crear configuración para raíz (solo sistema operativo, NO /home)
sudo snapper -c root create-config /

# Verificar creación
sudo snapper -c root list

# Deberías ver:
# # | Type   | Pre # | Date | User | Cleanup | Description | Userdata
# 0 | single |       |      | root |         | current     |

# Verificar que se creó directorio de snapshots
sudo ls -la /.snapshots/

# Ver subvolumen creado
sudo btrfs subvolume list /
# Debe aparecer: .snapshots (ID 258 o similar)
```

### 6.3 Configurar retención (SOLO eventos, NO tiempo)

```bash
# Deshabilitar snapshots automáticos por tiempo
sudo snapper -c root set-config "TIMELINE_CREATE=no"

# Configurar límites para snapshots manuales/eventos
sudo snapper -c root set-config "NUMBER_LIMIT=10"
sudo snapper -c root set-config "NUMBER_LIMIT_IMPORTANT=10"

# Verificar configuración
sudo snapper -c root get-config | grep -E "TIMELINE|NUMBER"

# Deberías ver:
# TIMELINE_CREATE         | no
# NUMBER_LIMIT            | 10
# NUMBER_LIMIT_IMPORTANT  | 10
```

### 6.4 Configurar snapshots PRE/POST para APT

**Crear hook de APT:**

```bash
sudo nano /etc/apt/apt.conf.d/80snapper
```

**Contenido:**

```
// Snapper PRE/POST snapshots para APT
// Versión oficial de Debian (mejorada con mejor manejo de errores y limpieza automática)
// Ref: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=770938

DPkg::Pre-Invoke  { "if [ -e /etc/default/snapper ]; then . /etc/default/snapper; fi; if [ -x /usr/bin/snapper ] && [ ! x$DISABLE_APT_SNAPSHOT = 'xyes' ] && [ -e /etc/snapper/configs/root ]; then rm -f /var/tmp/snapper-apt || true ; snapper create -d apt -c number -t pre -p > /var/tmp/snapper-apt || true ; snapper cleanup number || true ; fi"; };

DPkg::Post-Invoke { "if [ -e /etc/default/snapper ]; then . /etc/default/snapper; fi; if [ -x /usr/bin/snapper ] && [ ! x$DISABLE_APT_SNAPSHOT = 'xyes' ] && [ -e /var/tmp/snapper-apt ]; then snapper create -d apt -c number -t post --pre-number=`cat /var/tmp/snapper-apt` || true ; snapper cleanup number || true ; fi"; };
```

**Mejoras sobre versión anterior:**
- ✅ Lee configuración centralizada `/etc/default/snapper` (permite activar/desactivar sin tocar este archivo)
- ✅ Mejor manejo de errores con `|| true` en múltiples puntos
- ✅ Verifica que `/etc/snapper/configs/root` exista antes de proceder
- ✅ Limpieza automática con `snapper cleanup number` tras cada snapshot
- ✅ Usa `/var/tmp` en lugar de `/tmp` (más seguro)
- ✅ Es la versión oficial de Debian, testeada y mantenida

**Nota:** Esta es la versión instalada por defecto en Debian 13 con snapper. Si necesitas usar la versión anterior (simplificada), puedes reemplazarla con:

```
// VERSIÓN ANTERIOR (simplificada, no recomendada):
// DPkg::Pre-Invoke {
//   "if [ -x /usr/bin/snapper ]; then /usr/bin/snapper create --type=pre --cleanup-algorithm=number --print-number --description='apt-pre' > /tmp/snapper-pre-apt 2>&1; fi";
// };
//
// DPkg::Post-Invoke {
//   "if [ -x /usr/bin/snapper ]; then /usr/bin/snapper create --type=post --cleanup-algorithm=number --pre-number=$(cat /tmp/snapper-pre-apt 2>/dev/null | tail -1) --description='apt-post' 2>&1; rm -f /tmp/snapper-pre-apt; fi";
// };
```

**Guardar:** Ctrl+O, Enter, Ctrl+X

### 6.4.1 (Opcional recomendado) Disparar btrbk.service tras transacciones APT exitosas

> Este hook complementa a Snapper: al terminar `apt` con éxito, lanza `btrbk.service` en segundo plano.
> No bloquea `apt` y reduce la ventana entre snapshot local y réplica en sda3.

```bash
# Crear hook separado para btrbk
sudo nano /etc/apt/apt.conf.d/81btrbk-trigger
```

**Contenido:**

```
// Dispara btrbk.service en segundo plano luego de una transaccion dpkg.
// Se usa Post-Invoke porque es el mismo punto en el que Snapper ya se ejecuta correctamente.
DPkg::Post-Invoke {
   "if [ -x /usr/bin/systemctl ]; then /usr/bin/systemctl start --no-block btrbk.service || true; fi";
};
```

```bash
# Verificar que APT cargue el hook
apt-config dump | grep -i btrbk
```

**Notas:**
- Mantén `btrbk.timer` habilitado como red de seguridad (si no hay eventos APT, igualmente habrá sincronización periódica).
- Si hay múltiples operaciones de paquetes en poco tiempo, pueden dispararse varias ejecuciones; `btrbk` maneja esto de forma segura.

### 6.5 Habilitar servicios de Snapper

```bash
# Habilitar limpieza automática
sudo systemctl enable --now snapper-cleanup.timer

# Verificar estado
systemctl status snapper-cleanup.timer

# (timeline.timer NO lo habilitamos porque TIMELINE_CREATE=no)
```

### 6.6 Probar funcionamiento

```bash
# Crear snapshot manual
sudo snapper -c root create -d "Sistema base configurado"

# Listar snapshots
sudo snapper -c root list

# Deberías ver:
# 0 | single |  | ... | root |         | current                    |
# 1 | single |  | ... | root | number  | Sistema base configurado   |

# Probar APT snapshot (instalar algo pequeño)
sudo apt install -y htop

# Verificar snapshots APT
sudo snapper -c root list

# Deberías ver nuevos snapshots tipo pre/post (el número puede variar):
# 3 | pre  |   | ... | root | number  | apt |
# 4 | post | 3 | ... | root | number  | apt |

# IMPORTANTE: usa SIEMPRE los IDs reales que te muestre 'snapper list'
# Ejemplo si ves pre=3 y post=4:

# Ver qué cambió
sudo snapper -c root status 3..4

# Ver archivos específicos
sudo snapper -c root diff 3..4 | head -20
```

### 6.7 Snapshots para /home (opcional)

> Esta sección es **opcional** y no forma parte del flujo base requerido de la guía.
> Úsala si quieres versionado de archivos de usuario además de snapshots del sistema.

```bash
# Crear configuración de Snapper para /home
sudo snapper -c home create-config /home

# Política sugerida para /home (timeline activado)
sudo snapper -c home set-config "TIMELINE_CREATE=yes"
sudo snapper -c home set-config "TIMELINE_LIMIT_HOURLY=12"
sudo snapper -c home set-config "TIMELINE_LIMIT_DAILY=7"
sudo snapper -c home set-config "TIMELINE_LIMIT_WEEKLY=4"
sudo snapper -c home set-config "TIMELINE_LIMIT_MONTHLY=3"
sudo snapper -c home set-config "TIMELINE_LIMIT_YEARLY=0"

# Snapshot inicial manual de /home
sudo snapper -c home create -d "Home base inicial"

# Verificar
sudo snapper -c home list
```

**Importante:** los snapshots de `/home` no crean entradas de arranque en GRUB.
Se gestionan con el sistema ya iniciado (snapper diff/status/restore de archivos en home).

---

## 7. Configuración de btrbk

### 7.1 Instalar btrbk

```bash
sudo apt install -y btrbk
```

### 7.2 Preparar montajes

```bash
# Crear punto de montaje si no existe
sudo mkdir -p /mnt/btrfs-root

# Montar root de BTRFS (necesario para btrbk)
sudo mount -o subvolid=5 /dev/sda2 /mnt/btrfs-root

# Verificar contenido
ls /mnt/btrfs-root/
# Debe mostrar: @  @home

# Verificar que fstab tiene entrada correcta
cat /etc/fstab | grep btrfs-root

# Recargar systemd
sudo systemctl daemon-reload
```

### 7.3 Crear configuración de btrbk

```bash
# Debian 13 suele traer solo el archivo de ejemplo
# Crear btrbk.conf a partir del ejemplo
sudo cp /etc/btrbk/btrbk.conf.example /etc/btrbk/btrbk.conf

# Crear nueva configuración
sudo nano /etc/btrbk/btrbk.conf
```

**Contenido completo:**

```
# Configuración btrbk - Sistema de recuperación
# Snapshots de sistema en partición separada

# Formato de timestamp
timestamp_format        long

# Cuándo crear snapshots
snapshot_create         onchange

# RETENCIÓN EN SISTEMA PRINCIPAL (sda2)
# Mantener 7 snapshots más recientes (última semana)
snapshot_preserve_min   7d
snapshot_preserve       7d

# RETENCIÓN EN PARTICIÓN DE RECUPERACIÓN (sda3)
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

**Guardar:** Ctrl+O, Enter, Ctrl+X

### 7.4 Preparar partición de recuperación

```bash
# Montar partición de recuperación
sudo mount /dev/sda3 /mnt/backup

# Verificar montaje
df -h /mnt/backup
mount | grep backup

# Crear directorio para snapshots
sudo mkdir -p /mnt/backup/snapshots

# Verificar
ls -la /mnt/backup/
```

### 7.5 Probar btrbk

```bash
# Prueba en seco (dry-run)
sudo btrbk -v run --dry-run

# Deberías ver:
# Creating subvolume snapshot for: /mnt/btrfs-root/@
# [snapshot] source: /mnt/btrfs-root/@
# [snapshot] target: /mnt/btrfs-root/@/.snapshots/@.FECHA
# ...
# NOTE: Dryrun was active, none of the operations above were actually executed!

# Si OK, ejecutar real
sudo btrbk -v run

# Verificar backups creados
ls -lh /mnt/backup/snapshots/

# Ver subvolúmenes en recuperación
sudo btrfs subvolume list /mnt/backup/

# Ver espacio usado
df -h / /mnt/backup
```

### 7.6 Configurar protección estricta de partición de recuperación

**Script post-backup (actualizar GRUB y desmontar):**

```bash
sudo nano /usr/local/bin/btrbk-postrun.sh
```

**Contenido:**

```bash
#!/bin/bash
# Script post-ejecución de btrbk
# 1. Actualizar entrada GRUB emergency al último snapshot de sda3
# 2. Desmontar partición de recuperación al finalizar

if ! mountpoint -q /mnt/backup; then
   logger "btrbk-postrun: /mnt/backup no está montado, saltando"
   exit 0
fi

LATEST_SNAPSHOT=$(btrfs subvolume list /mnt/backup 2>/dev/null | \
   awk '/@\.[0-9][0-9][0-9][0-9][0-1][0-9][0-3][0-9]T[0-2][0-9][0-5][0-9]/ {path=$NF; gsub(/.*@\./, "@.", path); print path}' | \
   sort | \
   tail -n 1)

if [ -z "$LATEST_SNAPSHOT" ]; then
   logger "btrbk-postrun: No se encontró snapshot válido en sda3"
   exit 1
fi

TMPFILE=$(mktemp)
if cat /etc/grub.d/40_custom | sed \
   -e "s|arrancar desde sda3 @\.[0-9]\{8\}T[0-9]\{4\}|arrancar desde sda3 ${LATEST_SNAPSHOT}|g" \
   -e "s|snapshots/@\.[0-9]\{8\}T[0-9]\{4\}|snapshots/${LATEST_SNAPSHOT}|g" > "$TMPFILE"; then
   mv "$TMPFILE" /etc/grub.d/40_custom
   chmod 755 /etc/grub.d/40_custom
else
   rm -f "$TMPFILE"
   logger "btrbk-postrun: Error actualizando 40_custom"
   exit 1
fi

/usr/sbin/grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1 || logger "btrbk-postrun: advertencia - grub-mkconfig falló"

if umount /mnt/backup 2>/dev/null; then
   logger "btrbk-postrun: Partición de recuperación desmontada"
else
   mount -o remount,ro /mnt/backup 2>/dev/null
   logger "btrbk-postrun: No se pudo desmontar /mnt/backup; queda remontada como solo lectura"
   exit 1
fi
```

**Permisos:**

```bash
sudo chmod +x /usr/local/bin/btrbk-postrun.sh
```

**Integrar con systemd:**

```bash
sudo systemctl edit btrbk.service
```

**Agregar:**

```
[Service]
ExecStartPre=/bin/sh -c 'if mountpoint -q /mnt/backup; then mount -o remount,rw /mnt/backup; else mount /mnt/backup; fi'
ExecStartPost=/usr/local/bin/btrbk-postrun.sh
```

**Guardar:** Ctrl+O, Enter, Ctrl+X

**Recargar systemd:**

```bash
sudo systemctl daemon-reload
```

### 7.7 Estado normal de la partición de recuperación

```bash
# Verificar que normalmente quede desmontada
mount | grep backup
# No debe mostrar nada en estado normal
```

### 7.8 Automatizar btrbk (hibrido: evento + timer)

```bash
# Mantener timer como respaldo periodico
sudo systemctl enable --now btrbk.timer

# Verificar estado
systemctl status btrbk.timer

# Ver próxima ejecución
systemctl list-timers btrbk.timer
```

**Estrategia recomendada:**
- `Snapper` crea snapshots locales PRE/POST durante operaciones APT.
- Hook `81btrbk-trigger` dispara `btrbk.service` al finalizar transacciones exitosas.
- `ExecStartPre` monta `/mnt/backup` solo para la réplica o la remonta en `rw` si ya estaba montada en `ro`.
- `ExecStartPost` ejecuta `btrbk-postrun.sh` para actualizar la entrada EMERGENCY y desmontar `/mnt/backup`.
- `btrbk.timer` permanece activo para cubrir cambios fuera de APT y como fallback.

### 7.9 Snapshot manual para cambios no-APT (`snapcfg`)

Cuando haces cambios manuales en configuración (por ejemplo en `/etc`), APT no se ejecuta y por lo tanto no se crea snapshot automático PRE/POST.

Para cubrir ese caso, usar `snapcfg` antes de tocar configuración:

```bash
# Crear snapshot local (cleanup=number)
snapcfg "Antes de cambiar sshd_config"

# Crear snapshot local y replicar a sda3 inmediatamente
snapcfg "Antes de cambiar networkd" --replicate
```

**Qué hace `snapcfg`:**
- Crea snapshot en Snapper (`root`) con `cleanup=number`.
- Si se usa `--replicate`, ejecuta `btrbk.service`.
- Con eso se actualiza también la entrada EMERGENCY y se desmonta `/mnt/backup` al finalizar.

**Recomendación operativa:**
- Usar `snapcfg` antes de cambios manuales relevantes de sistema.
- Dejar APT + hook automático para cambios por paquetes.
- Mantener timer semanal como red de seguridad.

---

## 8. grub-btrfs

### 8.1 Instalación manual desde GitHub

```bash
# Instalar git
sudo apt install -y git

# Clonar repositorio
cd /tmp
git clone https://github.com/Antynea/grub-btrfs.git

# Instalar
cd grub-btrfs
sudo make install

# Salida esperada:
# Installing...
# Updating the GRUB menu...
# (puede mostrar warning - ignorar)
```

### 8.2 Configurar grub-btrfs (SIMPLIFICADO con @)

```bash
# Editar configuración
sudo nano /etc/default/grub-btrfs/config
```

**Buscar y verificar/modificar estas líneas:**

```bash
# Línea ~40: Nombre del submenu
GRUB_BTRFS_SUBMENUNAME="Debian snapshots"

# Línea ~70: Comando grub-mkconfig (verificar)
GRUB_BTRFS_MKCONFIG=/usr/sbin/grub-mkconfig

# Línea ~100: Script check (verificar)
GRUB_BTRFS_SCRIPT_CHECK=grub-script-check

# Línea ~160: Parámetros de kernel (vacío)
GRUB_BTRFS_SNAPSHOT_KERNEL_PARAMETERS=""

# Línea ~270: Límite de snapshots mostrados
GRUB_BTRFS_LIMIT="20"

# Nota: en algunas versiones (como la instalada desde GitHub en Debian 13)
# NO existen estas variables y no deben agregarse:
# - GRUB_BTRFS_SNAPSHOT_DIRNAME
# - GRUB_BTRFS_SNAPSHOT_FILTER

# ✅ YA NO NECESITAS configurar ROOTFLAGS ni OVERRIDE
# Con @ estándar, grub-btrfs detecta automáticamente
```

**Guardar:** Ctrl+O, Enter, Ctrl+X

### 8.3 Habilitar servicio

```bash
# Habilitar grub-btrfsd (detección automática)
sudo systemctl enable --now grub-btrfsd

# Verificar estado
systemctl status grub-btrfsd
```

### 8.4 Actualizar GRUB

```bash
# Actualizar configuración de GRUB
sudo update-grub

# Puede aparecer este warning sin romper el arranque:
# "UUID of the root subvolume is not available"
# Si aparece, grub-btrfs puede no generar /boot/grub/grub-btrfs.cfg

# Verificar si se creó archivo de snapshots
ls -la /boot/grub/grub-btrfs.cfg

# Si existe, ver contenido (primeras líneas)
sudo head -50 /boot/grub/grub-btrfs.cfg
```

**Troubleshooting (si NO se genera `grub-btrfs.cfg`):**

Si `update-grub` muestra:
```
UUID of the root subvolume is not available
```
puede ser un problema de parseo en `/etc/grub.d/41_snapshots-btrfs`.

Aplicar fix (con backup previo):

```bash
# Backup del script original
sudo cp /etc/grub.d/41_snapshots-btrfs /etc/grub.d/41_snapshots-btrfs.bak

# Fix de regex para awk (compatibilidad)
sudo sed -i 's/\\s\*/[[:space:]]*/g' /etc/grub.d/41_snapshots-btrfs

# Regenerar GRUB
sudo update-grub

# Verificar que ahora existe el archivo
ls -la /boot/grub/grub-btrfs.cfg
```

Si el archivo existe y tiene entradas de snapshots, el submenú debería aparecer en el próximo reinicio.

### 8.5 Verificar en próximo reinicio

```bash
# Reiniciar para probar
sudo reboot

# En menú GRUB, buscar entrada:
# "Debian snapshots" o "Debian GNU/Linux snapshots"

# Si NO aparece aún:
# - Es normal si solo tienes snapshot #0 (current)
# - Aparecerá cuando tengas snapshots reales (después de apt install, etc.)
```

---

## 9. Entrada de Emergencia en GRUB (✅ COMPLETAMENTE VALIDADA)

**Entrada manual con submenú de confirmación para arrancar desde partición de recuperación**

> ✅ **Sección completamente validada**: Submenú de emergencia creado, probado y funcionando. Arranca desde sda3 snapshot correctamente. No es posible arrancar por error.

### 9.1 Obtener información necesaria

```bash
# UUID del filesystem de sda3 (recuperación)
sudo blkid -s UUID -o value /dev/sda3
# Anotar UUID (ej: abcd-1234-efgh-5678)

# Ver snapshot más reciente en sda3
sudo mount /dev/sda3 /mnt/backup
ls -lt /mnt/backup/snapshots/ | head -5
# Anotar nombre (ej: @.20260328T1851)
sudo umount /mnt/backup

# Ver versión del kernel
uname -r
# Anotar (ej: 6.12.74+deb13+1-amd64)
```

### 9.2 Crear entrada custom en GRUB

**La entrada usa un submenu** para evitar arranques accidentales. Al seleccionarla en GRUB aparece un segundo nivel donde hay que confirmar.

```bash
sudo nano /etc/grub.d/40_custom
```

**Agregar al final (usar TUS datos reales):**

```bash
#!/bin/sh
exec tail -n +3 $0
# This file provides an easy way to add custom menu entries.

submenu '⚠ Debian RECOVERY (partición sda3) >' {
    menuentry 'Confirmar: arrancar desde sda3 @.20260328T1851 (EMERGENCIA)' --class debian --class gnu-linux {
        insmod gzio
        insmod part_gpt
        insmod btrfs

        # UUID del filesystem BTRFS de sda3 (CAMBIAR por tu UUID)
        search --no-floppy --fs-uuid --set=root abcd-1234-efgh-5678

        # Kernel dentro del snapshot de recuperación en sda3 (CAMBIAR versión y fecha)
        linux /snapshots/@.20260328T1851/boot/vmlinuz-6.12.74+deb13+1-amd64 root=UUID=abcd-1234-efgh-5678 rootflags=subvol=snapshots/@.20260328T1851 ro quiet

        # Initrd dentro del snapshot de recuperación en sda3 (CAMBIAR versión si es diferente)
        initrd /snapshots/@.20260328T1851/boot/initrd.img-6.12.74+deb13+1-amd64
    }
}
```

**Comportamiento en GRUB:**
```
Menú principal:
├── Debian GNU/Linux                          ← arranque normal
├── Advanced options for Debian               ← submenú de kernels
├── ⚠ Debian RECOVERY (partición sda3) >     ← entra al submenú
└── UEFI Firmware Settings

Al seleccionar RECOVERY:
└── Confirmar: arrancar desde sda3 @.20260328T1851 (EMERGENCIA)  ← confirmar aquí
```

**Importante:**
- `search --fs-uuid` debe usar el `UUID` del filesystem (`blkid -s UUID -o value /dev/sda3`), **no el `PARTUUID`**.
- El kernel e initrd van dentro del snapshot en sda3: `/snapshots/@.../boot/vmlinuz-...`

**Guardar:** Ctrl+O, Enter, Ctrl+X

**Hacer ejecutable:**

```bash
sudo chmod +x /etc/grub.d/40_custom
```

### 9.3 Actualizar GRUB

```bash
sudo update-grub

# Verificar que se agregó la entrada
grep -A 3 "menuentry.*RECOVERY" /boot/grub/grub.cfg
```

### 9.3.1 Congelar el estado actual antes de probar la entrada

**Recomendado:** antes de arrancar la entrada `Debian RECOVERY`, crear un snapshot nuevo del sistema actual, copiarlo a `sda3` y apuntar `40_custom` a ese snapshot recién replicado.

```bash
# 1. Crear snapshot local del estado actual
sudo snapper -c root create -d "Antes de validar entrada recovery"

# 2. Replicarlo a sda3
sudo mount /dev/sda3 /mnt/backup
sudo btrbk run
ls -lt /mnt/backup/snapshots/ | head -5
sudo umount /mnt/backup

# 3. Tomar nota del snapshot más reciente en sda3
#    Ejemplo: @.20260403T2239

# 4. Editar /etc/grub.d/40_custom para usar ese snapshot nuevo
sudo nano /etc/grub.d/40_custom

# 5. Actualizar las dos rutas del bloque recovery:
#    linux  /snapshots/@.YYYYMMDDTHHMM/boot/vmlinuz-<kernel> \
#           root=UUID=<uuid-sda3> rootflags=subvol=snapshots/@.YYYYMMDDTHHMM ro quiet
#    initrd /snapshots/@.YYYYMMDDTHHMM/boot/initrd.img-<kernel>

# 6. Regenerar GRUB y verificar
sudo update-grub
sudo grep -A 12 "menuentry 'Debian RECOVERY" /boot/grub/grub.cfg
```

**Objetivo:** si la prueba falla o el snapshot de recovery está desactualizado, no arrancarás un estado viejo por error.

### 9.3.2 Actualización automática de entrada EMERGENCY tras btrbk run

> Dato: la entrada de emergency en `/etc/grub.d/40_custom` **se actualiza automáticamente** cada vez que se ejecuta `btrbk run` (ya sea por timer o por trigger APT).

**¿Por qué es importante?**
- La entrada de emergency debe **siempre apuntar al último snapshot válido en sda3**.
- Si sda2 es atacado o corrupto, necesitás la versión **más reciente y segura** del respaldo.
- Sin actualización automática, podrías terminar booteando un snapshot obsoleto.

**¿Cómo funciona?**

1. **Trigger:** Cuando `btrbk run` termina exitosamente (timer o APT hook), systemd ejecuta el script post-run.

2. **Servicio:** `btrbk.service` monta `/mnt/backup` antes de correr `btrbk run`, o la remonta en `rw` si ya estaba visible en `ro`.

3. **Script:** `/usr/local/bin/btrbk-postrun.sh` (si está integrado con btrbk.service):
   - Busca el último snapshot técnico en `/mnt/backup/snapshots/`
   - Extrae su nombre (ej: `@.20260404T0218`)
   - Actualiza **description, linux path, initrd path** en `/etc/grub.d/40_custom`
   - Regenera `grub.cfg`
   - Desmonta `/mnt/backup` al finalizar (o lo deja en solo lectura si no pudo desmontar)

4. **Resultado:** Próximo reboot tendrá entry EMERGENCY apuntando a la réplica más reciente y `sda3` volverá a quedar desmontado.

**Verificar que funciona:**

```bash
# Ver último snapshot replicado
sudo btrfs subvolume list /mnt/backup | grep 'snapshots/@' | tail -n 1

# Ver entrada en 40_custom
sudo sed -n '8,21p' /etc/grub.d/40_custom | grep -E 'menuentry|linux|initrd'

# Deben coincidir

# Ver entrada en GRUB generado
sudo grep -m 1 'Confirmar: arrancar desde sda3' /boot/grub/grub.cfg
```

### 9.4 Probar entrada (opcional)

```bash
# Reiniciar
sudo reboot

# En GRUB deberías ver:
# ...
# Debian GNU/Linux
# Advanced options for Debian
# Debian RECOVERY (desde partición de recuperación sda3)  ← NUEVA
# ...

# Seleccionarla para validar que arranca desde sda3
```

**Después del arranque**, validar que realmente estás sobre el snapshot de recuperación:

```bash
mount | grep ' / '
btrfs subvolume show /
uname -r
```

---

## 10. Procedimientos de Recuperación

### 10.1 Crear documento de procedimientos

```bash
# Crear directorio de documentación
sudo mkdir -p /boot/recovery-docs

# Crear procedimiento principal
sudo nano /boot/recovery-docs/RECOVERY-PROCEDURE.txt
```

**Contenido:**

```
═══════════════════════════════════════════════════════════════
PROCEDIMIENTOS DE RECUPERACIÓN - DEBIAN BTRFS + SNAPPER
Estructura de subvolúmenes: @ y @home (estándar)
═══════════════════════════════════════════════════════════════

NIVEL 1: RECUPERACIÓN RÁPIDA (GRUB funciona)
─────────────────────────────────────────────────────────────

Caso: Actualización rompió el sistema, configuración errónea, etc.

Pasos:
1. Reiniciar sistema
2. En menú GRUB:
   → Seleccionar "Debian snapshots"
   → Seleccionar snapshot anterior al problema
   → Enter
3. Sistema arranca en estado anterior
4. Si funciona bien:
   sudo snapper rollback [número_snapshot]
   sudo reboot

═══════════════════════════════════════════════════════════════

NIVEL 2: RECUPERACIÓN DESDE PARTICIÓN DE RECUPERACIÓN
─────────────────────────────────────────────────────────────

Caso: Sistema principal corrupto pero GRUB funciona

Pasos:
1. Reiniciar sistema
2. En GRUB:
   → Seleccionar "Debian RECOVERY (desde partición...)"
   → Enter
3. Sistema arranca desde sda3 (partición de recuperación)
4. Investigar problema en sda2
5. Restaurar si es necesario (ver NIVEL 3)

═══════════════════════════════════════════════════════════════

NIVEL 3: RECUPERACIÓN COMPLETA (GRUB roto o sistema destruido)
─────────────────────────────────────────────────────────────

Caso: GRUB no funciona, sistema principal completamente dañado

REQUISITOS:
- Live USB de Debian
- Conexión a internet (opcional pero recomendado)

PASOS DETALLADOS:

1. Arrancar con Live USB Debian
   
   **Método A: Desde GRUB (si el sistema arranca)**
   - Arrancar sistema normalmente
   - En menú GRUB → "UEFI Firmware Settings"
   - Boot Manager → Seleccionar USB device
   - Seleccionar "Live system"
   
   **Método B: Tecla de arranque (si sistema NO arranca)**
   - Conectar USB
   - Presionar F12 o F2 al arrancar (depende del fabricante)
   - Seleccionar USB device
   - Seleccionar "Live system"
   
   **Método C: Desde VirtualBox**
   - Settings → Storage → Controller IDE
   - Montar ISO de Debian Live
   - Arrancar y usar Método A (UEFI Firmware Settings)

2. Abrir terminal (Ctrl+Alt+T)

3. Convertirse en root:
   sudo su

4. Montar particiones:
   mkdir /mnt/system
   mkdir /mnt/backup
   
   mount -o subvolid=5 /dev/sda2 /mnt/system
   mount /dev/sda3 /mnt/backup

5. Ver snapshots disponibles:
   ls -lt /mnt/backup/snapshots/
   
   # Anotar snapshot deseado, ejemplo:
   # @.20260325T1200

6. Borrar sistema dañado:
   btrfs subvolume delete /mnt/system/@

7. Restaurar desde snapshot:
   btrfs send /mnt/backup/snapshots/@.20260325T1200 | \
     btrfs receive /mnt/system/

8. Renombrar subvolumen:
   mv /mnt/system/@.20260325T1200 /mnt/system/@

9. Reinstalar GRUB:
   mount --bind /dev /mnt/system/@/dev
   mount --bind /proc /mnt/system/@/proc
   mount --bind /sys /mnt/system/@/sys
   mount /dev/sda1 /mnt/system/@/boot/efi
   
   chroot /mnt/system/@
   grub-install /dev/sda
   update-grub
   exit

10. Desmontar todo:
    umount /mnt/system/@/boot/efi
    umount /mnt/system/@/dev
    umount /mnt/system/@/proc
    umount /mnt/system/@/sys
    umount /mnt/system
    umount /mnt/backup

11. Reiniciar:
    reboot

12. Quitar USB y arrancar normalmente

TIEMPO ESTIMADO: 10-15 minutos

═══════════════════════════════════════════════════════════════

RECUPERACIÓN DE ARCHIVOS ESPECÍFICOS
─────────────────────────────────────────────────────────────

Caso: Solo necesitas recuperar algunos archivos

Pasos:
1. Montar snapshot deseado:
   sudo mount /dev/sda3 /mnt/backup
   sudo mount -o subvol=snapshots/@.FECHA /dev/sda3 /mnt/old

2. Copiar archivos:
   sudo cp /mnt/old/path/to/file /path/to/restore/

3. Desmontar:
   sudo umount /mnt/old
   sudo umount /mnt/backup

═══════════════════════════════════════════════════════════════

NOTAS IMPORTANTES:

- Partición de recuperación (sda3) NUNCA debe montarse automáticamente
- Está configurada como "noauto" en /etc/fstab
- Solo btrbk la monta durante backups (1 vez al día)
- Después de backup, se remonta como solo lectura
- Protección contra ransomware/virus

VERIFICACIÓN PERIÓDICA:

Cada semana ejecutar:
  sudo mount /dev/sda3 /mnt/backup
  ls -lt /mnt/backup/snapshots/
  sudo umount /mnt/backup

Verificar que existen múltiples snapshots recientes.

═══════════════════════════════════════════════════════════════

CONTACTO / INFORMACIÓN:
Sistema instalado: [FECHA]
Usuario principal: [TU_USUARIO]
Configuración: BTRFS + Snapper + btrbk
Estructura: @ y @home (estándar)
Retención: 7 snapshots en sda2, 18 en sda3

═══════════════════════════════════════════════════════════════
```

**Guardar:** Ctrl+O, Enter, Ctrl+X

### 10.2 Crear Live USB de recuperación

**Desde tu host (no la VM):**

1. Descargar Debian Live Standard
2. Crear USB bootable con Rufus (Windows) o dd (Linux)
3. Etiquetar USB: "DEBIAN RESCUE"
4. Guardar copia de RECOVERY-PROCEDURE.txt en el USB

---

## 11. Instalación en Notebook Física

### 11.1 Diferencias VM vs Notebook

**Configuración que CAMBIA:**

```
VM (VirtualBox):
├── UEFI emulado
├── Disco virtual (VDI)
├── RAM asignada (fija)
├── Guest Additions necesarias
└── Red NAT

Notebook física:
├── UEFI real
├── SSD/HDD físico
├── RAM física
├── NO necesita Guest Additions
└── WiFi/Ethernet real
```

**Configuración que SE MANTIENE IGUAL:**

```
✅ Particionado (EFI, BTRFS sistema, BTRFS recovery, SWAP)
✅ Subvolúmenes (@ y @home) - estándar
✅ Snapper configuración
✅ btrbk configuración
✅ grub-btrfs (funciona mejor con @)
✅ Procedimientos de recuperación
```

### 11.2 Preparación notebook

**ANTES de instalar:**

```
1. ⚠️ BACKUP completo de datos existentes
2. Verificar compatibilidad:
   - Modo UEFI habilitado en BIOS
   - Secure Boot: desactivar temporalmente
   - Boot order: USB primero
3. Crear Live USB con Debian 13
4. Probar arranque desde USB (sin instalar)
```

### 11.2.1 Tipo de instalación a utilizar

**Recomendación:** Instalación Gráfica con Particionado Manual

```
Boot desde Live USB:
→ Selecciona: "Graphical install"
→ Sigue asistente normal
→ En particionado: selecciona "Manual"
→ Crea 4 particiones (EFI, BTRFS sistema, BTRFS recovery, SWAP)
→ Continúa
→ En "Software selection" → desmarcar escritorio
→ Listo
```

**Alternativa:** Expert Install (si prefieres paso a paso sin UI gráfico)

```
Boot desde Live USB:
→ Selecciona: "Advanced options..."
→ Selecciona: "Expert install"
→ Sigue instrucciones (igual particionado manual)
```

### 11.3 Ajustes específicos para notebook

**Durante instalación:**

```
Particionado:
├── Si disco es 256 GB:
│   ├── sda1: 512 MB (EFI)
│   ├── sda2: 180 GB (BTRFS sistema)
│   ├── sda3: 60 GB (BTRFS recovery)
│   └── sda4: 16 GB (SWAP)
│
└── Si disco es 512 GB:
    ├── sda1: 512 MB (EFI)
    ├── sda2: 400 GB (BTRFS sistema)
    ├── sda3: 96 GB (BTRFS recovery)
    └── sda4: 16 GB (SWAP)

Regla: Recovery = ~20-25% del tamaño del sistema
```

**Post-instalación (diferencias):**

```bash
# NO instalar Guest Additions (solo para VM)

# Instalar drivers de WiFi si es necesario
# Verificar con: lspci | grep Network
# Buscar drivers específicos del fabricante

# Configurar touchpad (si KDE)
# System Settings → Input Devices → Touchpad

# Configurar ahorro de energía
# System Settings → Power Management

# Habilitar TRIM para SSD (si aplica)
sudo systemctl enable fstrim.timer
```

### 11.4 Checklist de instalación en notebook

```
Pre-instalación:
□ Backup completo de datos
□ Live USB creado y verificado
□ BIOS configurado (UEFI, Secure Boot off)
□ Adaptador de corriente conectado

Durante instalación:
□ Particionado correcto (ajustado a tamaño de disco)
□ Usuario creado (no root)
□ Software mínimo seleccionado

Post-instalación base:
□ Subvolúmenes @ y @home creados (renombrado de @rootfs → @)
□ Verificado con: btrfs subvolume list / (debe mostrar path @ NO @rootfs)
□ fstab actualizado correctamente con subvol=@ (coincide con nombre real)
□ Sistema arranca con compresión zstd
□ WiFi/Ethernet funcionando

Configuración de recuperación:
□ Snapper instalado y configurado
□ Snapshots PRE/POST de APT funcionando
□ btrbk instalado y configurado
□ Primer backup a sda3 exitoso
□ grub-btrfs instalado (detección automática con @)
□ Entrada de emergencia en GRUB creada
□ Documento de procedimientos en /boot/recovery-docs

Verificación final:
□ Crear snapshot manual OK
□ Instalar paquete de prueba → snapshots PRE/POST OK
□ btrbk run manual OK
□ Verificar snapshots en sda3
□ Reiniciar → Menú GRUB muestra snapshots
□ Probar arranque desde snapshot en GRUB
```

---

## 12. Verificación y Mantenimiento

### 12.1 Comandos de verificación diaria

```bash
# Ver snapshots locales
sudo snapper -c root list

# Ver espacio usado
df -h /
sudo btrfs filesystem usage /

# Ver snapshots en recuperación (montar, ver, desmontar)
sudo mount /dev/sda3 /mnt/backup
ls -lt /mnt/backup/snapshots/ | head -10
df -h /mnt/backup
sudo umount /mnt/backup

# Ver servicios activos
systemctl status snapper-cleanup.timer
systemctl status btrbk.timer
systemctl status grub-btrfsd

# Ver logs de btrbk (último backup)
sudo journalctl -u btrbk.service -n 50
```

### 12.2 Mantenimiento semanal

```bash
# Limpiar snapshots viejos manualmente (si es necesario)
sudo snapper -c root list
sudo snapper -c root delete [número]

# Desfragmentar (opcional, si el sistema está hace meses)
sudo btrfs filesystem defragment -r -v /

# Balance de metadata (opcional, si hay warnings)
sudo btrfs balance start -m /

# Verificar integridad (scrub)
sudo btrfs scrub start /
sudo btrfs scrub status /
```

### 12.3 Mantenimiento mensual

```bash
# Verificar salud del disco (notebook física)
sudo smartctl -a /dev/sda

# Verificar errores de BTRFS
sudo btrfs device stats /

# Actualizar sistema
sudo apt update
sudo apt upgrade
# (Snapper creará snapshots PRE/POST automáticamente)

# Verificar backups antiguos
sudo mount /dev/sda3 /mnt/backup
ls -lth /mnt/backup/snapshots/
sudo umount /mnt/backup
```

### 12.4 Script de verificación automática

```bash
sudo nano /usr/local/bin/check-backup-health.sh
```

**Contenido:**

```bash
#!/bin/bash
# Script de verificación de salud del sistema de backups

echo "═══════════════════════════════════════════════"
echo "  VERIFICACIÓN DE SISTEMA DE BACKUPS"
echo "  Estructura: @ y @home (estándar)"
echo "═══════════════════════════════════════════════"
echo ""

# Snapshots locales
echo "📸 Snapshots locales (sda2):"
snapper -c root list | tail -5
echo ""

# Espacio usado
echo "💾 Espacio usado:"
df -h / | grep -v Filesystem
echo ""

# Verificar subvolúmenes
echo "🗂️  Subvolúmenes:"
btrfs subvolume show / | grep "Name:"
btrfs subvolume show /home | grep "Name:"
echo ""

# Verificar partición de recuperación
echo "🛡️  Partición de recuperación (sda3):"
mount /dev/sda3 /mnt/backup 2>/dev/null
if [ $? -eq 0 ]; then
    echo "Snapshots en recuperación:"
    ls -lt /mnt/backup/snapshots/ | head -5
    df -h /mnt/backup | grep -v Filesystem
    umount /mnt/backup
else
    echo "⚠️  No se pudo montar sda3"
fi
echo ""

# Servicios
echo "⚙️  Servicios:"
systemctl is-active snapper-cleanup.timer && echo "✅ Snapper cleanup: activo" || echo "❌ Snapper cleanup: inactivo"
systemctl is-active btrbk.timer && echo "✅ btrbk: activo" || echo "❌ btrbk: inactivo"
systemctl is-active grub-btrfsd && echo "✅ grub-btrfsd: activo" || echo "❌ grub-btrfsd: inactivo"
echo ""

# Próximo backup
echo "📅 Próximo backup automático:"
systemctl list-timers btrbk.timer | grep btrbk
echo ""

echo "═══════════════════════════════════════════════"
```

**Permisos:**

```bash
sudo chmod +x /usr/local/bin/check-backup-health.sh
```

**Uso:**

```bash
# Ejecutar cuando quieras verificar el sistema
sudo check-backup-health.sh
```

### 12.5 Mostrar validación automática al iniciar sesión

Esto muestra al abrir terminal (TTY o terminal del entorno gráfico) un resumen rápido de contexto de arranque:

- Estado de arranque con semáforo:
   - `[OK] NORMAL` (verde): raíz en `@`
   - `[WARN] SNAPSHOT` (amarillo): raíz en snapshot
   - `[EMERG] EMERGENCY` (rojo): raíz en recovery (`sda3`)
- Dispositivo y subvolumen montados en `/` y `/home`
- Kernel activo

**Crear script global:**

```bash
sudo nano /usr/local/bin/show-boot-context.sh
```

**Contenido:**

```bash
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
```

**Permisos:**

```bash
sudo chmod +x /usr/local/bin/show-boot-context.sh
```

**Ejecutar automáticamente en shells interactivas:**

```bash
sudo nano /etc/bash.bashrc
```

Agregar al final:

```bash
# Boot context banner for all users:
# - TTY/SSH: show on every login shell
# - Graphical terminal: show once per boot
if [ -x /usr/local/bin/show-boot-context.sh ] && [ -z "${BOOT_CONTEXT_BANNER_SHOWN-}" ]; then
   BOOT_CONTEXT_BANNER_SHOWN=1
   if [ -n "${DISPLAY-}${WAYLAND_DISPLAY-}" ]; then
      /usr/local/bin/show-boot-context.sh --once-per-boot
   else
      /usr/local/bin/show-boot-context.sh
   fi
fi
```

**Nota:** no hace falta modificar `~/.bashrc` ni `/etc/skel/.bashrc`; con `/etc/bash.bashrc` alcanza para todos los usuarios.

---

## 13. Próximos Pasos

### 13.1 Crear snapshot "Sistema base listo" (✅ COMPLETADO)

```bash
# Crear snapshot del sistema base completamente configurado
sudo snapper -c root create -d "Sistema base con Snapper+btrbk+grub-btrfs configurado"

# Montar partición de recuperación
sudo mount /dev/sda3 /mnt/backup

# Forzar backup inmediato a sda3
sudo btrbk run

# Desmontar partición de recuperación
sudo umount /mnt/backup

# Verificar snapshot creado
sudo snapper -c root list | tail -3
```

**Importante:** Asegurar que en `/etc/fstab` está configurado:

```bash
UUID=4e10e56c-665e-4b5c-9892-55bb12509de6 /mnt/btrfs-root btrfs subvolid=5,auto,compress=zstd:3 0 0
```

(sin `noauto` para que btrbk.timer funcione automáticamente en cada arranque)

### 13.2 Instalar entorno de escritorio

**Para KDE Plasma mínimo:**

```bash
# ANTES de instalar, crear snapshot
sudo snapper -c root create -d "Antes de instalar KDE"

# Instalar KDE mínimo
sudo apt install -y kde-plasma-desktop sddm

# Habilitar SDDM
sudo systemctl enable sddm

# Reiniciar
sudo reboot

# DESPUÉS de verificar que funciona
sudo snapper -c root create -d "KDE Plasma instalado y funcionando"
```

### 13.3 Personalización (Windows 11 style)

Esto será para otra conversación, pero los pasos base:

1. Instalar temas y widgets
2. Configurar panel
3. Instalar aplicaciones necesarias
4. Cada cambio importante → Crear snapshot

---

## 📚 Recursos Adicionales

### Documentación oficial:

- BTRFS: https://btrfs.readthedocs.io/
- Snapper: http://snapper.io/
- btrbk: https://github.com/digint/btrbk
- grub-btrfs: https://github.com/Antynea/grub-btrfs

### Comandos de referencia rápida:

```bash
# Snapper
sudo snapper -c root list
sudo snapper -c root create -d "Descripción"
sudo snapper -c root delete [número]
sudo snapper -c root status [num1]..[num2]
sudo snapper -c root diff [num1]..[num2]
sudo snapper -c root rollback [número]

# btrbk
sudo btrbk run
sudo btrbk -v run
sudo btrbk -v run --dry-run
sudo btrbk list snapshots
sudo btrbk list backups

# BTRFS
sudo btrfs subvolume list /
sudo btrfs filesystem usage /
sudo btrfs filesystem df /
sudo btrfs scrub start /
sudo btrfs scrub status /

# Montajes
sudo mount /dev/sda3 /mnt/backup
sudo mount -o subvol=snapshots/@.FECHA /dev/sda3 /mnt/old
sudo umount /mnt/backup
```

---

## 💻 Casos Aplicados

Esta sección documenta instalaciones concretas realizadas con esta guía, con el hardware específico utilizado y las decisiones tomadas en cada caso.

---

### Caso 1: Dell Latitude 5421

**Fecha:** Abril 2026  
**Objetivo:** Reemplazar Windows 11 completo por Debian 13 con Btrfs + Snapper + btrbk. Sin dual boot.

#### Hardware

| Componente | Detalle |
|---|---|
| **Modelo** | Dell Latitude 5421 |
| **CPU** | Intel Core i7-11850H @ 2.50 GHz (11ª gen) |
| **RAM** | 32 GB |
| **Disco** | NVMe SSD 256 GB (CL1-3D256-Q11 NVMe SSSTC) |
| **Modo arranque** | UEFI |
| **Secure Boot** | Activado (desactivado durante instalación) |
| **BitLocker** | No activo |
| **Sistema previo** | Windows 11 (borrado completamente) |

#### Decisiones de instalación

| Decisión | Elección | Motivo |
|---|---|---|
| Dual boot | No | Reemplazo completo |
| /home separado | Subvolumen `@home` (no partición) | Flexibilidad de espacio + backup unificado por btrbk |
| Swap | 33 GB | Hibernación habilitada (≥ RAM de 32 GB) |

#### Esquema de particionado aplicado

| Partición | Tamaño | Tipo | Uso |
|---|---|---|---|
| sda1 | 512 MB | FAT32 (EFI) | Arranque UEFI |
| sda2 | 170 GB | Btrfs | Sistema: subvolúmenes `@` y `@home` |
| sda3 | 35 GB | Btrfs | Backup btrbk (`noauto`) |
| sda4 | 33 GB | swap | Hibernación |

**Regla aplicada:** backup ≈ 20% del sistema. Swap = RAM para hibernación.

#### Notas específicas

- Secure Boot se desactiva en BIOS antes de arrancar el installer y puede reactivarse después si se configura shim.
- NVMe aparece como `nvme0n1` en Linux (no `sda`); ajustar referencias del particionado en consecuencia.
- Wi-Fi Intel AX201 incluido en el kernel, sin drivers adicionales necesarios.
- TRIM en SSD: habilitar con `sudo systemctl enable fstrim.timer`.

---

## ✅ Checklist Final de Instalación Completa

```
Sistema Base:
□ Debian 13 instalado con UEFI
□ Particionado correcto (EFI, BTRFS×2, SWAP)
□ Subvolúmenes @ y @home (estándar, renombrado de @rootfs)
□ Compresión zstd:3 activa
□ Sistema arranca correctamente

VirtualBox (solo VM):
□ Guest Additions instaladas
□ Copiar/pegar funciona
□ Carpetas compartidas (opcional)

Recuperación:
□ Snapper configurado (eventos, no tiempo)
□ Snapshots APT PRE/POST funcionando
□ btrbk configurado (7+18 retención)
□ Primer backup en sda3 exitoso
□ Partición sda3 protegida (noauto, ro)
□ grub-btrfs instalado (detección automática con @)
□ Entrada GRUB de emergencia creada
□ Documento de procedimientos en /boot

Verificación:
□ Crear snapshot manual → OK
□ Instalar paquete → snapshots PRE/POST → OK
□ btrbk run manual → OK
□ Verificar backups en sda3 → OK
□ Reiniciar → Snapshots en GRUB → OK
□ Script de verificación ejecutado → OK

Documentación:
□ Procedimientos de recuperación documentados
□ Live USB de rescate creado
□ Contraseñas y usuarios documentados
□ Tamaños de particiones anotados
```

---

**Documento creado:** [FECHA]  
**Sistema:** Debian 13 (Trixie)  
**Arquitectura:** BTRFS con recuperación multinivel  
**Subvolúmenes:** @ y @home (estándar)  
**Autor:** Guía optimizada con estructura estándar

**✅ Sistema listo para producción con estructura estándar!** 🚀

**Ventajas de usar @ y @home:**
- ✅ Compatible con grub-btrfs automáticamente
- ✅ Sin necesidad de configuración ROOTFLAGS manual
- ✅ Estructura reconocida por documentación y herramientas
- ✅ Más ejemplos y soporte en comunidad
