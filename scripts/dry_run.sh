#!/bin/bash
set -euo pipefail

# Opcion 2 (v008) - Modo prueba (dry-run)
# Primera parte: validaciones seguras para integrar el flujo de pruebas por etapas.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

printf "[dry-run] inicio\n"
printf "[dry-run] repo: %s\n" "$REPO_ROOT"
printf "[dry-run] chequeo de entorno basico\n"

if ! command -v bash >/dev/null 2>&1; then
    printf "[dry-run] error: bash no disponible\n" >&2
    exit 1
fi

if ! command -v tput >/dev/null 2>&1; then
    printf "[dry-run] warning: tput no disponible (continuando)\n"
fi

printf "[dry-run] parte 1 completada\n"
exit 0
