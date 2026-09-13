#!/bin/bash
# ==========================================
# SCRIPT DE ADMINISTRACIÓN - SERVIDOR 3
# Respaldo y Continuidad - Proyecto TERRABIT
# ==========================================

if [ "$EUID" -ne 0 ]; then
    echo "[-] Este script debe ejecutarse como root (usá sudo)."
    exit 1
fi

DIR_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR_SCRIPT" || exit 1

mkdir -p logs

source ./config.sh
source ./modulos/backup_servidor.sh

menu_backup_servidor
