# KDE Plasma con estilo Windows / AnduinOS-like

## Objetivo

Este perfil documenta una forma simple y reproducible de instalar **KDE Plasma** en Debian 13 y dejarlo con una experiencia visual cercana a Windows:

- panel inferior
- lanzador tipo menu inicio
- area de notificacion a la derecha
- tema claro
- iconos y espaciado sobrios
- flujo compatible con Snapper + btrbk + entrada EMERGENCY ya validada

No intenta clonar AnduinOS al pixel, sino lograr una experiencia parecida sobre una base Debian estable y mantenible.

## Enfoque recomendado

Antes de instalar el escritorio:

```bash
snapcfg "Baseline antes de instalar KDE Plasma" --replicate
```

Eso deja un punto de rollback local y una replica en `sda3` antes del cambio grande de paquetes.

## Instalacion

### Opcion recomendada para la VM

Usar el script incluido en esta carpeta:

```bash
cd /home/administrador/proyectos/debian-btrfs/escritorios/KDE_Windows
chmod +x install_kde_windows.sh
./install_kde_windows.sh
```

### Opcion manual equivalente

```bash
sudo snapcfg "Antes de instalar KDE Plasma" --replicate

echo 'sddm shared/default-x-display-manager select sddm' | sudo debconf-set-selections
sudo DEBIAN_FRONTEND=noninteractive apt install -y task-kde-desktop sddm

sudo systemctl enable sddm
sudo systemctl set-default graphical.target
```

## Verificacion posterior

```bash
sudo snapper -c root list | tail -n 10
grep -nE 'menuentry|linux /snapshots|initrd /snapshots' /etc/grub.d/40_custom
mount | grep '/mnt/backup' || echo "sda3 desmontado"
systemctl status sddm --no-pager
systemctl get-default
```

Resultado esperado:

- nuevo par de snapshots `pre/post` por APT
- entrada `EMERGENCY` actualizada al ultimo snapshot tecnico
- `sda3` desmontado al finalizar
- `sddm` habilitado
- `graphical.target` como default target

## Ajuste visual tipo Windows

Una vez que KDE arranque:

### 1. Panel

- mover el panel a la parte inferior si no quedo asi
- altura sugerida: `40-44 px`
- usar **Icons-only Task Manager**
- reloj y bandeja a la derecha

### 2. Lanzador

- usar **Application Launcher (Kickoff)**
- fijarlo al extremo izquierdo del panel
- anclar Dolphin, Konsole, Firefox/Chromium y Configuracion del sistema

### 3. Tema base

Configurar desde **System Settings**:

- Global Theme: `Breeze Light`
- Plasma Style: `Breeze`
- Application Style: `Breeze`
- Colors: `Breeze Light`
- Icons: `Breeze`
- Cursors: `Breeze`

### 4. Comportamiento tipo Windows

- doble click para abrir archivos si lo prefieres
- barra inferior siempre visible
- area de notificacion compacta
- escritorio limpio, sin plasmoides innecesarios

### 5. Opcional: look mas cercano a AnduinOS

Si quieres acercarte mas al look moderno tipo Windows 11 / AnduinOS:

- instalar un tema tipo `Fluent` desde KDE Store
- usar iconos `Fluent` o similares
- mantener panel inferior con bordes suaves
- usar fondo claro o neutro, no wallpapers de Windows

Esto es opcional. La base recomendada sigue siendo `Breeze Light`, que es estable y facil de mantener.

## Rollback / recuperacion

Si KDE no queda bien o rompe algo:

### Opcion 1. Desde Snapper

```bash
sudo snapper -c root list
sudo snapper rollback <ID>
sudo reboot
```

### Opcion 2. Desde GRUB snapshots

- arrancar un snapshot anterior desde `Debian snapshots`

### Opcion 3. Desde particion de recuperacion

- usar la entrada `Debian RECOVERY`
- validar que arranca el ultimo snapshot tecnico de `sda3`

## Que modificar mas adelante

Todo esto es reversible sin reinstalar Debian:

- cambiar `sddm` por otro display manager
- quitar KDE Plasma
- cambiar tema, iconos y panel
- pasar a GNOME, XFCE u otro perfil

Lo importante es que la base Btrfs + Snapper + btrbk + recovery ya quedo estable.