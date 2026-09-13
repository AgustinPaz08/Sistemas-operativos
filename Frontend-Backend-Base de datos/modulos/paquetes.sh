#!/bin/bash
# ==========================================
# MÓDULO: GESTIÓN DE PAQUETES
# ==========================================
# Requiere permisos de root (se valida desde main.sh)

LOG_FILE="./logs/paquetes.log"

log_accion() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

actualizar_repositorios() {
    echo "[+] Actualizando lista de paquetes disponibles..."
    apt update
    log_accion "Repositorios actualizados"
}

actualizar_sistema() {
    echo "[+] Actualizando paquetes instalados..."
    apt update && apt upgrade -y
    log_accion "Sistema actualizado (upgrade)"
}

instalar_paquete() {
    read -p "Nombre del paquete a instalar: " paquete
    if [ -z "$paquete" ]; then
        echo "[-] No ingresaste ningún nombre."
        return
    fi
    apt install -y "$paquete"
    log_accion "Paquete instalado: $paquete"
}

desinstalar_paquete() {
    read -p "Nombre del paquete a desinstalar: " paquete
    if [ -z "$paquete" ]; then
        echo "[-] No ingresaste ningún nombre."
        return
    fi
    apt remove -y "$paquete"
    log_accion "Paquete desinstalado: $paquete"
}

listar_paquetes_instalados() {
    echo "[+] Últimos 20 paquetes instalados:"
    apt list --installed 2>/dev/null | tail -n 20
}

limpiar_paquetes() {
    echo "[+] Limpiando paquetes huérfanos y cachés..."
    apt autoremove -y
    apt autoclean -y
    log_accion "Limpieza de paquetes ejecutada"
}

menu_paquetes() {
    while true; do
        clear
        echo "=========================================="
        echo "        GESTIÓN DE PAQUETES DEL S.O.       "
        echo "=========================================="
        echo "1. Actualizar lista de repositorios"
        echo "2. Actualizar sistema completo (upgrade)"
        echo "3. Instalar un paquete"
        echo "4. Desinstalar un paquete"
        echo "5. Listar paquetes instalados"
        echo "6. Limpiar paquetes no usados"
        echo "7. Volver al menú principal"
        echo "=========================================="
        read -p "Seleccioná una opción [1-7]: " op

        case $op in
            1) actualizar_repositorios ;;
            2) actualizar_sistema ;;
            3) instalar_paquete ;;
            4) desinstalar_paquete ;;
            5) listar_paquetes_instalados ;;
            6) limpiar_paquetes ;;
            7) break ;;
            *) echo "[-] Opción inválida." ;;
        esac
        read -p "Presioná [Enter] para continuar..."
    done
}
