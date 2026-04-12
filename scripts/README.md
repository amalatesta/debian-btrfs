# 📋 Scripts - Bitácora de Trabajo

Registro vivo del desarrollo de la interfaz bash+tput para el instalador Debian Btrfs.
Documenta lo completado, en progreso y lo proyectado.

---

## 📊 Estado Actual

## ✅ Trabajo Completado

### v008_debian-btrfs-installer.sh - Motor Principal

#### 0001 - Base bash+tput
- Motor UI completo basado en tput (sin whiptail)
- Menú genérico reutilizable con navegación por flechas/TAB
- Sistema de temas (blanco, naranja, verde) seleccionables
- Detección de colores de terminal (8/16/256)
- Centrado automático y ajuste por tamaño de terminal

#### 0002 - Ayuda integrada + Helpers genéricos
- Pantalla de ayuda dentro del marco UI (no texto plano)
- Scroll interno: Up/Down/PgUp/PgDn (similar a whiptail)
- Perfiles de pantalla adaptativos (compact, normal, wide-log)
- Confirmación binaria reutilizable (Sí/No)
- Preview de comandos genérico
- `run_with_progress()` para ejecuciones futuras con seguimiento visual
- Helpers: info_box, message_box, success_box, error_box, todo_screen

#### 0003 - Opción 2 (Modo prueba) externalizada
- Script dedicado: `dry_run.sh` (mismo directorio que 008)
- Ejecución controlada desde menú
- Integración sin dependencia de scripts/006
- Validado en VM con flujo completo (precheck → ejecución → resultado)

#### 0004 - Opción 2 ampliada (dry-run guiado)
- Validaciones de entorno (bash, tput, lsblk, findmnt, awk, sed)
- Detección de contexto de ejecución (kernel, usuario, raíz)
- Detección de hardware y particiones en modo solo lectura
- Preview explícito de acciones reales (sin tocar disco)
- Flujo por etapas con logs claros `[step]`, `[ok]`, `[warn]`

### dry_run.sh - Auxiliar de Opción 2
- Parte 1: Validaciones básicas de entorno (bash, tput)
- Extensible para flujo dry-run futuro

---

## 🔄 Trabajo en Progreso

### 0008.0008 - Preguntas iniciales tipo Debian (OK)
- Validado en VM el flujo de idioma, ubicación, teclado y resumen
- Confirmado el formato Sugerido --> / Elegido --> en terminal y reporte

### 0008.0009 - Red inicial (OK por requisito)
- Se cierra el tema red como requisito del entorno
- La instalación debe contar con salida a Internet, preferentemente por Ethernet
- Si el live arranca solo con Wi-Fi, queda fuera del alcance validado de esta iteración

---

## Estructura General del Menú

```
┌─────────────────────────────────┐
│ Debian Btrfs Installer v008     │
├─────────────────────────────────┤
│ Selecciona una opcion:          │
│ 1. Iniciar instalacion          │
│ 2. Modo prueba (dry-run)  ← OK  │
│ 3. Ayuda                  ← OK  │
│ 4. Salir                        │
└─────────────────────────────────┘
```

## Funciones Reutilizables Implementadas

### UI Base
- `show_centered_text_box()` - Renderer genérico con scroll
- `get_text_box_profile()` - Perfiles de tamaño por tipo de pantalla
- `draw_centered_text_frame()` - Dibujo adaptativo de marco

### Pantallas de Información
- `show_info_box()` - Información general
- `show_message_box()` - Mensaje simple
- `show_success_box()` - Resultado exitoso
- `show_error_box()` - Resultado con error
- `show_command_preview()` - Preview de comando
- `show_todo_screen()` - Pantalla "en construcción"
- `show_help_screen()` - Ayuda del sistema

### Interacción
- `confirm_yes_no()` - Confirmación binaria reutilizable
- `run_with_progress()` - Ejecutor de comando con resultado visual

### Motor
- `run_menu()` - Motor de menú reutilizable
- `apply_theme()` - Temas de color (blanco, naranja, verde)
- `get_key_raw()` - Lector de teclas (flechas, PgUp/PgDn, Enter, etc.)

## 🎯 Próximos Pasos

### Fase 2: Ampliar Opción 2 (Dry-run Completo)
**Decisión 0008.0004**: Expandir `dry_run.sh` con:
- Validación de requisitos (disk space mínimo, BIOS/firmware, etc.)
- Detección de hardware (nvme, ssd, hdd)
- Análisis interactivo de particiones existentes
- Preview de configuración (qué se haría)
- Ejecución paso a paso con feedback

**Commits necesarios**:
- 0008.0004: Ampliar validaciones básicas
- 0008.0005: Añadir detectores de hardware
- 0008.0006: Construir preview UI

### Fase 3: Implementar Opción 1 (Instalación Integrada)
- Dentro del motor 008 (sin scripts externos nuevos)
- Reutilizar helpers (confirm, progress, etc.)
- Integración con dry_run.sh para obtener config
- Ejecución de pasos reales (formato, instalación, bootloader)

### Fase 4: Consolidación y Limpieza
- Internalizar `dry_run.sh` como función dentro de 008
- Mantener modularidad pero en un solo archivo
- Validar que todo sigue funcionando en VM
- Preparar para futuro mantenimiento

---

## 📝 Notas de Diseño

## Cómo Ejecutar

### Requisitos
- Terminal interactiva (TTY)
- Bash 4+
- `tput` disponible
- `stty` disponible

### Ejecución
```bash
cd debian-btrfs/scripts
bash 008_debian-btrfs-installer.sh
```

### Desde fuera del directorio
```bash
cd debian-btrfs
bash scripts/008_debian-btrfs-installer.sh
```

## Arquitectura de Diseño

### Principios
1. **UI Modular**: Función base genérica + wrappers especializados
2. **Pantallas por Perfil**: Tamaño adaptativo (`compact`, `normal`, `wide-log`)
3. **Scroll Interno**: Similiar a whiptail textbox (Up/Down/PgUp/PgDn)
4. **Colores por Tema**: Seleccionable al inicio, consiste durante sesión
5. **Ejecución Controlada**: `run_with_progress()` para comandos con seguimiento
6. **Versionado Funcional**: Historial en cabecera, OK marca estabilidad

### Patrón de Desarrollo
1. Implementa en `dry_run.sh` o función nueva
2. Prueba en VM con iteraciones cortas
3. Una vez OK, traslada a 008 si corresponde
4. Marca versión como OK cuando valdida
5. Abre siguiente versión para próximos pasos

### bash+tput vs whiptail
- Elegimos bash+tput por control total
- Scroll interno personalizable (similar a whiptail pero flexible)
- Sin dependencias GUI pesadas
- Funciona en VM, SSH, ambientes restringidos
- Motor reutilizable sin cambios futuros

### Versionado en cabecera (0008.0001, 0008.0002, etc.)
- Gobernanza explícita: versionado por iteración
- Regla: nueva versión solo después de validar en VM y marcar/OK/
- Historial de cambios dentro del código (single source of truth)
- Facilita rollback o referencia a cambios específicos

### Perfiles de pantalla (compact, normal, wide-log)
- Adaptación futura para diferentes tipos de contenido
- Preview de comandos → wide-log (más espacio)
- Errores/confirmaciones → compact (conciso)
- Diferencia entre necesidades de UI sin duplicar motor

### Modularidad progresiva
- Hoy: `dry_run.sh` separado (claro testing/aislamiento)
- Mañana: dentro de 008 como función (consolidación)
- Facilita evolución sin caos de archivos

---

## � Historial de Commits

| Commit | Versión | Cambio |
|--------|---------|--------|
| ca96dff | 0008.0001 | Bash+tput motor + menú principal |
| e59a7eb | 0008.0002 | Ayuda en frame + scroll + helpers |
| 419f884 | 0008.0002-b | Perfiles de pantalla (compact/normal/wide) |
| 69d819c | 0008.0003 | Opción 2 → dry_run.sh |
| 688ce67 | 0008.0003-OK | Marca 0003-OK, abre 0004 |
| d79a2c8 | 0008.0008 | Resumen ordenado y sin redundancia |
| aa66817 | 0008.0008 | Resumen con formato Sugerido/Elegido |
| 8509282 | 0008.0008 | Prompt de Backup con formato `[S/n]` |
| bd6166e | 0008.0008 | Limpieza del informe UI en `dry_run.sh` |
| (actual) | 0008.0009-OK | Red cerrada como requisito de Internet/Ethernet |
| 92417ca | - | README.md bitácora inicial |
| (próximo) | - | Definir siguiente iteración funcional |

---

## �💡 Lecciones Aprendidas

1. **Iteración corta + Push inmediato**: Validación en VM después de cada cambio acelera feedback
2. **Naming explícito**: `dry_run.sh` en lugar de `opcion-2-...` reduce fricción
3. **Versionado en código**: Cabecera del script como fuente de verdad de historia
4. **Funciones genéricas primero**: Invertir tiempo en helpers reutilizables paga dividendos
5. **No prematura consolidación**: Mantener separado hasta que sea claro el patrón
6. **Tests sintácticos constantes**: `bash -n` cada cambio evita sorpresas
7. **Scroll interno importante**: Para contenido variable, crucial la UX tipo whiptail

## Logs y Debugging

### Información de Sesión
- Colores disponibles detectados
- Terminal TTY validada
- Dimensiones adaptadas

### Para Debugging
- Agregar `printf "[debug] ...\\n"` en funciones clave
- La salida de `run_with_progress()` muestra últimas líneas de logs
- Sintaxis validable con `bash -n scripts/008_debian-btrfs-installer.sh`

## Contacto / Contribución

Flujo de cambios:
1. Branch/Feature en local
2. Prueba en VM
3. Commit/Push a main
4. Actualizar este README con cambios

---

**Última actualización**: 2026-04-12 (0008.0004 en validación)
