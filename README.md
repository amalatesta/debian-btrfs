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

---



## 📋 Tabla de Contenidos

1. Preparación
2. Instalación Base Debian
3. Configuración de Subvolúmenes BTRFS
4. Configurar acceso SSH (Opcional pero recomendado)
5. VirtualBox Guest Additions
6. Configuración de Snapper
7. Configuración de btrbk
8. grub-btrfs
9. Entrada de Emergencia en GRUB
10. Procedimientos de Recuperación
11. Instalación en Notebook Física
12. Verificación y Mantenimiento
13. Próximos Pasos

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

```
Menú GRUB del instalador:
→ Selecciona: "Advanced options..."
→ Selecciona: "... Expert install"
→ Enter
```

**¿Por qué Expert Install?**
- Más control sobre particionado
- Evita instalación de paquetes innecesarios
- Permite configuración precisa

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

### 3.1 Apagar sistema y arrancar Rescue Mode

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


### 3.2 Arrancar en Rescue Mode

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

### 3.3 Renombrar a estructura estándar y crear @home

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


### ✅ Verificación CRÍTICA del renombrado (OBLIGATORIO)

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


### 3.4 Actualizar /etc/fstab

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


### 3.6 ⚠️ CRÍTICO: Reinstalar GRUB después de cambios

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

### ✅ Al reiniciar debe ocurrir:

1. **Aparece el menú de GRUB** automáticamente
2. **Selecciona "Debian GNU/Linux"**
3. **El sistema arranca sin errores**
4. **NO se queda esperando** (RCU stall)

---

### ❌ Si el sistema NO arranca:

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


### 3.5 Verificar configuración

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

### 3.6 Quitar ISO y arrancar sistema

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

### 3.7 Verificar arranque con subvolúmenes

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

### 4.1 Instalar dependencias

```bash
# Actualizar sistema
sudo apt update
sudo apt upgrade -y

# Instalar herramientas de compilación
sudo apt install -y build-essential dkms linux-headers-$(uname -r)
```

### 4.2 Insertar ISO de Guest Additions

```
Menú VirtualBox (arriba):
→ Devices (Dispositivos)
→ Insert Guest Additions CD image...
```

### 4.3 Montar y ejecutar instalador

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

### 4.4 Verificar instalación

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

### 4.5 Habilitar funciones

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

### 5.1 Instalar paquetes

```bash
# Instalar Snapper y herramientas BTRFS
sudo apt install -y btrfs-progs snapper inotify-tools

# Herramientas adicionales útiles
sudo apt install -y vim curl wget net-tools
```

### 5.2 Crear configuración de Snapper

```bash
# Crear configuración para raíz (solo sistema operativo, NO /home)
sudo snapper -c root create-config /

# Verificar creación
sudo snapper -c root list

# Deberías ver:
# # | Type   | Pre # | Date | User | Cleanup | Description | Userdata
# 0 | single |       |      | root |         | current     |

# Verificar que se creó directorio de snapshots
ls -la /.snapshots/

# Ver subvolumen creado
sudo btrfs subvolume list /
# Debe aparecer: .snapshots (ID 258 o similar)
```

### 5.3 Configurar retención (SOLO eventos, NO tiempo)

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

### 5.4 Configurar snapshots PRE/POST para APT

**Crear hook de APT:**

```bash
sudo nano /etc/apt/apt.conf.d/80snapper
```

**Contenido:**

```
// Snapper PRE/POST snapshots para APT
DPkg::Pre-Invoke {
  "if [ -x /usr/bin/snapper ]; then /usr/bin/snapper create --type=pre --cleanup-algorithm=number --print-number --description='apt-pre' > /tmp/snapper-pre-apt 2>&1; fi";
};

DPkg::Post-Invoke {
  "if [ -x /usr/bin/snapper ]; then /usr/bin/snapper create --type=post --cleanup-algorithm=number --pre-number=$(cat /tmp/snapper-pre-apt 2>/dev/null | tail -1) --description='apt-post' 2>&1; rm -f /tmp/snapper-pre-apt; fi";
};
```

**Guardar:** Ctrl+O, Enter, Ctrl+X

### 5.5 Habilitar servicios de Snapper

```bash
# Habilitar limpieza automática
sudo systemctl enable --now snapper-cleanup.timer

# Verificar estado
systemctl status snapper-cleanup.timer

# (timeline.timer NO lo habilitamos porque TIMELINE_CREATE=no)
```

### 5.6 Probar funcionamiento

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

# Deberías ver nuevos snapshots:
# 2 | pre  |   | ... | root | number  | apt-pre  |
# 3 | post | 2 | ... | root | number  | apt-post |

# Ver qué cambió
sudo snapper -c root status 2..3

# Ver archivos específicos
sudo snapper -c root diff 2..3 | head -20
```

---

## 7. Configuración de btrbk

### 6.1 Instalar btrbk

```bash
sudo apt install -y btrbk
```

### 6.2 Preparar montajes

```bash
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

### 6.3 Crear configuración de btrbk

```bash
# Hacer backup de configuración original
sudo mv /etc/btrbk/btrbk.conf /etc/btrbk/btrbk.conf.original

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
target_preserve_min     14d 4w
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

### 6.4 Preparar partición de recuperación

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

### 6.5 Probar btrbk

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

### 6.6 Configurar protección de partición de recuperación

**Script post-backup (montar como solo lectura):**

```bash
sudo nano /usr/local/bin/btrbk-postrun.sh
```

**Contenido:**

```bash
#!/bin/bash
# Script post-ejecución de btrbk
# Remontar partición de recuperación como solo lectura

if mountpoint -q /mnt/backup; then
    mount -o remount,ro /mnt/backup
    logger "btrbk-postrun: Partición de recuperación remontada como solo lectura"
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
ExecStartPost=/usr/local/bin/btrbk-postrun.sh
```

**Guardar:** Ctrl+O, Enter, Ctrl+X

**Recargar systemd:**

```bash
sudo systemctl daemon-reload
```

### 6.7 Desmontar partición de recuperación

```bash
# Desmontar (debe estar desmontada normalmente)
sudo umount /mnt/backup

# Verificar
mount | grep backup
# No debe mostrar nada
```

### 6.8 Automatizar btrbk

```bash
# Habilitar timer (corre diariamente a medianoche)
sudo systemctl enable btrbk.timer

# Iniciar timer
sudo systemctl start btrbk.timer

# Verificar estado
systemctl status btrbk.timer

# Ver próxima ejecución
systemctl list-timers btrbk.timer
```

---

## 8. grub-btrfs

### 7.1 Instalación manual desde GitHub

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

### 7.2 Configurar grub-btrfs (SIMPLIFICADO con @)

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

# Línea ~140: Directorio de snapshots
GRUB_BTRFS_SNAPSHOT_DIRNAME="/.snapshots"

# Línea ~160: Parámetros de kernel (vacío)
GRUB_BTRFS_SNAPSHOT_KERNEL_PARAMETERS=""

# Línea ~270: Límite de snapshots mostrados
GRUB_BTRFS_LIMIT="20"

# Línea ~300: Solo snapshots de Snapper
GRUB_BTRFS_SNAPSHOT_FILTER="snapper"

# ✅ YA NO NECESITAS configurar ROOTFLAGS ni OVERRIDE
# Con @ estándar, grub-btrfs detecta automáticamente
```

**Guardar:** Ctrl+O, Enter, Ctrl+X

### 7.3 Habilitar servicio

```bash
# Habilitar grub-btrfsd (detección automática)
sudo systemctl enable --now grub-btrfsd

# Verificar estado
systemctl status grub-btrfsd
```

### 7.4 Actualizar GRUB

```bash
# Actualizar configuración de GRUB
sudo update-grub

# ✅ Debería detectar snapshots sin warnings de UUID

# Verificar si se creó archivo de snapshots
ls -la /boot/grub/grub-btrfs.cfg

# Si existe, ver contenido (primeras líneas)
sudo head -50 /boot/grub/grub-btrfs.cfg
```

### 7.5 Verificar en próximo reinicio

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

## 9. Entrada de Emergencia en GRUB

**Entrada manual para arrancar desde partición de recuperación**

### 8.1 Obtener información necesaria

```bash
# UUID de sda3 (recuperación)
sudo blkid /dev/sda3 | grep -o 'UUID="[^"]*"'
# Anotar UUID (ej: UUID="abcd-1234-efgh-5678")

# Ver snapshot más reciente en sda3
sudo mount /dev/sda3 /mnt/backup
ls -lt /mnt/backup/snapshots/ | head -5
# Anotar nombre (ej: @.20260328T1851)
sudo umount /mnt/backup

# Ver versión del kernel
uname -r
# Anotar (ej: 6.12.74+deb13+1-amd64)
```

### 8.2 Crear entrada custom en GRUB

```bash
sudo nano /etc/grub.d/40_custom
```

**Agregar al final (usar TUS datos reales):**

```bash
#!/bin/sh
exec tail -n +3 $0
# This file provides an easy way to add custom menu entries.

menuentry 'Debian RECOVERY (desde partición de recuperación sda3)' --class debian --class gnu-linux {
    insmod gzio
    insmod part_gpt
    insmod btrfs
    
    # UUID de sda3 (CAMBIAR por tu UUID)
    search --no-floppy --fs-uuid --set=root abcd-1234-efgh-5678
    
    # Kernel (CAMBIAR versión y fecha de snapshot)
    linux /boot/vmlinuz-6.12.74+deb13+1-amd64 root=UUID=abcd-1234-efgh-5678 rootflags=subvol=snapshots/@.20260328T1851 ro quiet
    
    # Initrd (CAMBIAR versión si es diferente)
    initrd /boot/initrd.img-6.12.74+deb13+1-amd64
}
```

**Guardar:** Ctrl+O, Enter, Ctrl+X

**Hacer ejecutable:**

```bash
sudo chmod +x /etc/grub.d/40_custom
```

### 8.3 Actualizar GRUB

```bash
sudo update-grub

# Verificar que se agregó la entrada
grep -A 3 "menuentry.*RECOVERY" /boot/grub/grub.cfg
```

### 8.4 Probar entrada (opcional)

```bash
# Reiniciar
sudo reboot

# En GRUB deberías ver:
# ...
# Debian GNU/Linux
# Advanced options for Debian
# Debian RECOVERY (desde partición de recuperación sda3)  ← NUEVA
# ...

# NO la selecciones aún (solo verifica que aparece)
```

---

## 10. Procedimientos de Recuperación

### 9.1 Crear documento de procedimientos

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

### 9.2 Crear Live USB de recuperación

**Desde tu host (no la VM):**

1. Descargar Debian Live Standard
2. Crear USB bootable con Rufus (Windows) o dd (Linux)
3. Etiquetar USB: "DEBIAN RESCUE"
4. Guardar copia de RECOVERY-PROCEDURE.txt en el USB

---

## 11. Instalación en Notebook Física

### 10.1 Diferencias VM vs Notebook

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

### 10.2 Preparación notebook

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

### 10.3 Ajustes específicos para notebook

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

### 10.4 Checklist de instalación en notebook

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

### 11.1 Comandos de verificación diaria

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

### 11.2 Mantenimiento semanal

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

### 11.3 Mantenimiento mensual

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

### 11.4 Script de verificación automática

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

---

## 13. Próximos Pasos

### 12.1 Crear snapshot "Sistema base listo"

```bash
# Crear snapshot del sistema base completamente configurado
sudo snapper -c root create -d "Sistema base con Snapper+btrbk+@ configurado"

# Forzar backup inmediato a sda3
sudo btrbk run

# Verificar
sudo snapper -c root list
```

### 12.2 Instalar entorno de escritorio

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

### 12.3 Personalización (Windows 11 style)

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
