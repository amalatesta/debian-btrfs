# CONSOLIDACIÓN: ESTADO ACTUAL

**Fecha:** 12-04-2026  
**Commit:** bc7cda7 - "refactor: Rename symbols to avoid conflicts"  
**Status:** ✅ **LISTO PARA CONSOLIDACIÓN FINAL**

## ✅ QUÉ SE COMPLETÓ

### 1. Renombrado de Símbolos Conflictivos

#### dry_run.sh
- Variables: `DISK` → `DRYRUN_DISK`, `RAM_GB` → `DRYRUN_RAM_GB`, etc.
- Funciones: `step()` → `dryrun_step()`, `ok()` → `dryrun_ok()`, etc.
- Todas las referencias internas actualizadas

**Estado de validación:**
```bash
bash -n dry_run.sh  # ✓ SYNTAX OK
```

#### install.sh  
- Variables: `DISK` → `INSTALL_DISK`, `RAM_GB` → `INSTALL_RAM_GB`, etc.
- Funciones: `step()` → `install_step()`, `ok()` → `install_ok()`, etc.
- Todas las referencias internas actualizadas

**Estado de validación:**
```bash
bash -n install.sh  # ✓ SYNTAX OK
```

### 2. Archivos Eliminados
- ❌ `debian-btrfs-install.sh` (archivo temporal - ya no necesario)

## 🔄 QUÉ FALTA: CONSOLIDACIÓN FINAL EN 008

### Pasos Requeridos

#### 1. Extraer Bloques de Código
- **dry_run.sh**: Insertar líneas 66-726 (funciones dryrun_*) en 008 antes de main()
- **install.sh**: Insertar líneas 78-828 (funciones install_*) en 008 antes de main()

#### 2. Actualizar en 008_debian-btrfs-installer.sh

**Ubicación:** Antes de `main()` (actualmente línea ~1727)

```bash
# ============================================
# BLOQUE: DRY-RUN FUNCTIONS
# ============================================
[CONTENIDO DE DRY_RUN.SH - líneas 66-726]

# ============================================  
# BLOQUE: INSTALL FUNCTIONS
# ============================================
[CONTENIDO DE INSTALL.SH - líneas 78-828]

main() {
    # ... contenido actual de main()
}
```

#### 3. Actualizar Funciones de Menú en 008

**run_install_part1()**
- Actual: Llama a `bash "$option1_path"` (install.sh externo)
- Cambiar a: Llamar `install_main_pipeline()` (función interna)

**run_dryrun_part1()**
- Actual: Llama a `bash "$option2_path"` (dry_run.sh externo)
- Cambiar a: Llamar `dryrun_main_pipeline()` (función interna)

#### 4. Agregar Funciones Orquestadoras Internas

Crear en 008 (antes de bloques dryrun/install):

```bash
install_main_pipeline() {
    # Orquestar el pipeline de instalación desde 008
    # Recibe variables: INSTALL_DISK, INSTALL_USER_PASSWORD, etc.
    # (la lógica actual de install.sh main() )
}

dryrun_main_pipeline() {
    # Orquestar análisis desde 008
    # (la lógica actual de dry_run.sh main() )
}
```

### 5. Validación Final

```bash
bash -n 008_debian-btrfs-installer.sh  # Sintaxis OK
wsl -- bash 008_debian-btrfs-installer.sh  # Test en WSL
```

## 📊 ESTADÍSTICAS FINALES

| Métrica | Valor |
|---------|-------|
| dry_run.sh (renombrado) | 726 líneas |
| install.sh (renombrado) | 975 líneas |
| 008 actual | ~1,750 líneas |
| **Total consolidad** | ~**3,450 líneas** |

## 🎯 Resultado Esperado

**UN ÚNICO ARCHIVO** (`008_debian-btrfs-installer.sh`) que contenga:
- ✅ UI completo (menús, boxes, colores)
- ✅ Flujo dry-run integrado
- ✅ Flujo de instalación integrado
- ✅ CERO dependencias de archivos externos
- ✅ Variables namerspacizadas (sin conflictos)

## 📝 Próximos Pasos

1. **Consolidar:** Ejecutar `python3 consolidate_final.py` O manual copy-paste
2. **Validar:** `bash -n 008_debian-btrfs-installer.sh`
3. **Commit:** `git commit -m "008: full consolidation - dry_run+install integrated"`
4. **Push:** `git push origin main`
5. **Test:** En ambiente Debian Live

---
**Guardado en:** `/memories/session/consolidation_status.md`
