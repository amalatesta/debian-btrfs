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

### 3. Tema visual aplicado (look Windows 11 oscuro)

Configurado desde **System Settings → Appearance**:

1. Entrar a **Global Theme** → verificar que `Breeze Dark` esta seleccionado
2. Hacer clic en **Get New Global Themes** y descargar:
   - `Fluent Round Dark` (tema Plasma oscuro estilo Windows 11)
   - `Win11OS-Dark` (incluye fondo de pantalla y splash screen)
3. Aplicar **Fluent Round Dark** como Plasma Style
4. Seleccionar el fondo de pantalla que viene con `Win11OS-Dark`

### 4. Pantalla de carga (Splash Screen)

- En **System Settings → Appearance → Splash Screen**
- Seleccionar `Win11OS-Dark`
- Muestra una barra de carga estilo Windows 11 al iniciar sesion

### 5. Comportamiento tipo Windows

- doble click para abrir archivos si lo prefieres
- barra inferior siempre visible
- area de notificacion compacta
- escritorio limpio, sin plasmoides innecesarios

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