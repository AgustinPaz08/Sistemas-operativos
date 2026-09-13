#!/bin/bash
# ==========================================
# MÓDULO: CONFIGURACIÓN DE SSH
# ==========================================

LOG_FILE="./logs/ssh.log"
SSHD_CONFIG="/etc/ssh/sshd_config"

log_accion() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

instalar_ssh() {
    echo "[+] Instalando servidor SSH..."
    apt install -y openssh-server
    systemctl enable ssh
    systemctl start ssh
    log_accion "SSH instalado y habilitado"
}

estado_ssh() {
    echo "[+] Estado actual del servicio SSH:"
    systemctl status ssh --no-pager
}

cambiar_puerto_ssh() {
    read -p "Ingresá el nuevo puerto para SSH (ej: 2222): " puerto
    if ! [[ "$puerto" =~ ^[0-9]+$ ]]; then
        echo "[-] Puerto inválido."
        return
    fi
    cp "$SSHD_CONFIG" "$SSHD_CONFIG.bak"
    sed -i "s/^#Port 22/Port $puerto/" "$SSHD_CONFIG"
    sed -i "s/^Port .*/Port $puerto/" "$SSHD_CONFIG"
    systemctl restart ssh
    echo "[+] Puerto SSH cambiado a $puerto (backup en $SSHD_CONFIG.bak)"
    log_accion "Puerto SSH cambiado a $puerto"
}

deshabilitar_root_login() {
    # CORREGIDO: aviso de seguridad antes de cortar el acceso remoto
    # como root, para no dejar la VM inaccesible por SSH.
    echo "[!] Antes de continuar, confirmá que tenés OTRO usuario con"
    echo "    sudo y acceso SSH ya funcionando (por ejemplo con la"
    echo "    opción 'Generar par de llaves' de este menú), porque"
    echo "    después de esto ya no vas a poder entrar como root por SSH."
    read -p "¿Confirmás que ya tenés otro usuario con acceso? [s/n]: " confirmar
    if [[ "$confirmar" != "s" && "$confirmar" != "S" ]]; then
        echo "[-] Operación cancelada."
        return
    fi
    cp "$SSHD_CONFIG" "$SSHD_CONFIG.bak"
    sed -i "s/^#PermitRootLogin.*/PermitRootLogin no/" "$SSHD_CONFIG"
    sed -i "s/^PermitRootLogin.*/PermitRootLogin no/" "$SSHD_CONFIG"
    systemctl restart ssh
    echo "[+] Login remoto como root deshabilitado."
    log_accion "PermitRootLogin puesto en 'no'"
}

generar_llaves() {
    read -p "Usuario para el cual generar la llave: " usuario
    if ! id "$usuario" &>/dev/null; then
        echo "[-] El usuario '$usuario' no existe."
        return
    fi
    home_usuario=$(eval echo "~$usuario")

    # CORREGIDO: si ya existe una llave, ssh-keygen se queda esperando
    # confirmación para sobreescribir y el script parece "colgado".
    # Ahora se detecta antes y se pregunta explícitamente.
    if [ -f "$home_usuario/.ssh/id_rsa" ]; then
        read -p "Ya existe una llave para $usuario. ¿Sobreescribir? [s/n]: " sobreescribir
        if [[ "$sobreescribir" != "s" && "$sobreescribir" != "S" ]]; then
            echo "[-] Operación cancelada. Se conserva la llave existente."
            return
        fi
    fi

    sudo -u "$usuario" mkdir -p "$home_usuario/.ssh"
    sudo -u "$usuario" ssh-keygen -t rsa -b 4096 -f "$home_usuario/.ssh/id_rsa" -N "" <<< y >/dev/null 2>&1
    echo "[+] Llave generada en $home_usuario/.ssh/id_rsa"
    echo "    Clave pública para distribuir (copiar a authorized_keys del servidor destino):"
    cat "$home_usuario/.ssh/id_rsa.pub"
    log_accion "Llave SSH generada para $usuario"
}

# NUEVO: faltaba una forma de copiar la llave pública a otro servidor.
# Sin esto, los backups automáticos (cron) piden contraseña y se
# quedan colgados porque no hay nadie para tipearla.
copiar_llave_a_servidor() {
    read -p "Usuario local dueño de la llave (ej: root, admin): " usuario_local
    home_usuario=$(eval echo "~$usuario_local")
    if [ ! -f "$home_usuario/.ssh/id_rsa.pub" ]; then
        echo "[-] $usuario_local no tiene una llave pública generada todavía."
        echo "    Usá primero la opción 'Generar par de llaves'."
        return
    fi

    read -p "Usuario remoto en el servidor destino (ej: admin): " usuario_remoto
    read -p "IP del servidor destino (ej: 192.168.100.30 para el de backups): " ip_remota

    if ! command -v ssh-copy-id &>/dev/null; then
        echo "[-] ssh-copy-id no está instalado. Instalando..."
        apt install -y openssh-client
    fi

    sudo -u "$usuario_local" ssh-copy-id -i "$home_usuario/.ssh/id_rsa.pub" "$usuario_remoto@$ip_remota"
    if [ $? -eq 0 ]; then
        echo "[+] Llave copiada correctamente a $usuario_remoto@$ip_remota."
        echo "    A partir de ahora, $usuario_local puede conectarse a ese"
        echo "    servidor por SSH/SCP sin pedir contraseña."
        log_accion "Llave de $usuario_local copiada a $usuario_remoto@$ip_remota"
    else
        echo "[-] No se pudo copiar la llave. Verificá conectividad, usuario y contraseña."
        log_accion "ERROR copiando llave de $usuario_local a $usuario_remoto@$ip_remota"
    fi
}

menu_ssh() {
    while true; do
        clear
        echo "=========================================="
        echo "          CONFIGURACIÓN DE SSH             "
        echo "=========================================="
        echo "1. Instalar servicio SSH"
        echo "2. Ver estado del servicio"
        echo "3. Cambiar puerto de SSH"
        echo "4. Deshabilitar login root remoto"
        echo "5. Generar par de llaves para un usuario"
        echo "6. Copiar llave a otro servidor (para backups sin clave)"
        echo "7. Volver al menú principal"
        echo "=========================================="
        read -p "Seleccioná una opción [1-7]: " op

        case $op in
            1) instalar_ssh ;;
            2) estado_ssh ;;
            3) cambiar_puerto_ssh ;;
            4) deshabilitar_root_login ;;
            5) generar_llaves ;;
            6) copiar_llave_a_servidor ;;
            7) break ;;
            *) echo "[-] Opción inválida." ;;
        esac
        read -p "Presioná [Enter] para continuar..."
    done
}
