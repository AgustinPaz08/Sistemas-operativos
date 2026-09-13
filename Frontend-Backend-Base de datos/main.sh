#!/bin/bash
# ==========================================
# SCRIPT DE ADMINISTRACIÓN - PROYECTO TERRABIT
# 2da Entrega - Administración de Sistemas Operativos
# ==========================================

# Verificar que se ejecute como root
if [ "$EUID" -ne 0 ]; then
    echo "[-] Este script debe ejecutarse como root (usá sudo)."
    exit 1
fi

# Ubicarnos en la carpeta del script para que las rutas relativas
# (logs/, modulos/) funcionen sin importar desde dónde se lo invoque.
DIR_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR_SCRIPT" || exit 1

mkdir -p logs

# Cargar la configuración del proyecto (IPs, nombre de BD, rutas, etc.)
source ./config.sh

# Cargar todos los módulos
source ./modulos/paquetes.sh
source ./modulos/ssh.sh
source ./modulos/respaldos.sh
source ./modulos/contenedores.sh

menu_principal() {
    while true; do
        clear
        echo "=========================================="
        echo "     ADMINISTRACIÓN DE SISTEMAS - TERRABIT "
        echo "=========================================="
        echo "1. Gestión de Paquetes"
        echo "2. Configuración de SSH"
        echo "3. Gestión de Respaldos (Backups)"
        echo "4. Gestión de Contenedores (Docker)"
        echo "5. Salir"
        echo "=========================================="
        read -p "Seleccioná una opción [1-5]: " opcion

        case $opcion in
            1) menu_paquetes ;;
            2) menu_ssh ;;
            3) menu_respaldos ;;
            4) menu_contenedores ;;
            5) echo "Saliendo del script..."; exit 0 ;;
            *) echo "[-] Opción inválida. Elegí un número del 1 al 5."; sleep 2 ;;
        esac
    done
}

menu_principal
