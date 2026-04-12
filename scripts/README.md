# Scripts - Debian Btrfs Installer

## Estado Actual

### v008 - Motor principal (v008_debian-btrfs-installer.sh)
- **Versión**: 008
- **Estado**: En desarrollo activo
- **Archivo**: `008_debian-btrfs-installer.sh`

#### Historial de Versiones
- **0008.0001** - ✅ OK
  - Base bash+tput (motor UI integrado)
  - Framework de menú, navegación, colores
  - Soporte para temas (blanco, naranja, verde)

- **0008.0002** - ✅ OK
  - Ayuda integrada dentro del marco UI
  - Refactor UI genérico (helpers reutilizables)
  - Scroll interno con Up/Down/PgUp/PgDn
  - Perfiles de pantalla (compact, normal, wide-log)
  - Confirmación Sí/No
  - Preview de comandos
  - `run_with_progress()` para ejecuciones futuras

- **0008.0003** - ✅ OK
  - Opción 2 (Modo prueba / dry-run) externalizada
  - Script dedicado: `dry_run.sh`
  - Ejecución controlada desde menú
  - Validado en VM

- **0008.0004** - 🔄 En progreso
  - Próximo: Ampliar opción 2 o trabajar en opción 1

### Scripts auxiliares
- **dry_run.sh**: Ejecutable por opción 2 del menú
  - Parte 1: Validaciones básicas de entorno
  - Extensible para flujo dry-run completo futuro

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

## Próximos Pasos (0008.0004 y más allá)

### Opción 2 - Modo prueba (ampliar dry_run.sh)
- [ ] Implementar validaciones de requisitos (root, UEFI, internet)
- [ ] Detección de discos automática
- [ ] Análisis de hardware y sugerencias
- [ ] Flujo interactivo de preguntas no críticas
- [ ] Preview del plan de instalación
- [ ] Ejecución controlada paso a paso

### Opción 1 - Instalación Real (futuro)
- [ ] Integrar lógica de 005 en 008
- [ ] Validaciones iniciales
- [ ] Configuración interactiva
- [ ] Instalación con barra de progreso en UI
- [ ] Manejo de errores mejorado

### Consolidación (futuro)
- [ ] Traer todo de `dry_run.sh` dentro de 008 como función modular `option_dryrun()`
- [ ] Opción 1 como función modular `option_install()`
- [ ] Estructura única en 008_debian-btrfs-installer.sh sin archivos auxiliares
- [ ] Mantener modularidad y reutilización de código

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

## Decisiones Técnicas

### Por qué bash+tput y no whiptail
- Control total sobre comportamiento
- Scroll interno como whiptail pero personalizable
- Sin dependencias GUI pesadas
- Funciona en más contextos (VM, SSH, etc.)
- Motor reutilizable para futuras opciones

### Por qué versionado en cabecera
- Gobernanza explícita de cambios
- Facilita seguimiento de iteraciones
- Regla clara: no duplicar versión hasta OK
- Permite historial de lo que fue probado

### Por qué dry_run.sh separado por ahora
- Encapsulación clara durante desarrollo
- Fácil testing independiente
- Plan: consolidar en 008 cuando esté completo

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

**Última actualización**: 2026-04-12 (0008.0003 cerrado, 0008.0004 en progreso)
