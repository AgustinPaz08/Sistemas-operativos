#!/bin/bash
# ==========================================
# MÓDULO: RECEPCIÓN Y CUSTODIA DE BACKUPS
# Servidor 3 - Respaldo y Continuidad
# ==========================================

LOG_FILE="./logs/backup_servidor.log"

log_accion() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# --- 1. Dejar el servidor listo para recibir backups ---
preparar_servidor() {
    echo "[+] Instalando SSH (si no está)..."
    apt update
    apt install -y openssh-server
    systemctl enable ssh
    systemctl start ssh

    if ! id "$USUARIO_BACKUP" &>/dev/null; then
        echo "[+] Creando usuario '$USUARIO_BACKUP'..."
        adduser --disabled-password --gecos "" "$USUARIO_BACKUP"
    else
        echo "[+] El usuario '$USUARIO_BACKUP' ya existe."
    fi

    echo "[+] Creando carpeta de backups en $DESTINO_BACKUPS_REMOTO..."
    mkdir -p "$DESTINO_BACKUPS_REMOTO"
    chown "$USUARIO_BACKUP":"$USUARIO_BACKUP" "$DESTINO_BACKUPS_REMOTO"
    chmod 750 "$DESTINO_BACKUPS_REMOTO"

    home_usuario=$(eval echo "~$USUARIO_BACKUP")
    sudo -u "$USUARIO_BACKUP" mkdir -p "$home_usuario/.ssh"
    sudo -u "$USUARIO_BACKUP" touch "$home_usuario/.ssh/authorized_keys"
    chmod 700 "$home_usuario/.ssh"
    chmod 600 "$home_usuario/.ssh/authorized_keys"

    echo "[+] Servidor listo. Ahora falta agregar la clave pública del"
    echo "    Servidor 1 con la opción 2 de este menú (o con ssh-copy-id"
    echo "    desde el Servidor 1, opción 'Copiar llave a otro servidor')."
    log_accion "Servidor de backups preparado (usuario, carpeta, SSH)"
}

# --- 2. Agregar a mano la clave pública que llega del Servidor 1 ---
# Útil si preferís pegar la clave acá en vez de usar ssh-copy-id
# desde el otro lado.
agregar_clave_publica() {
    home_usuario=$(eval echo "~$USUARIO_BACKUP")
    archivo_authorized="$home_usuario/.ssh/authorized_keys"

    if [ ! -d "$home_usuario/.ssh" ]; then
        echo "[-] Todavía no preparaste el servidor (opción 1)."
        return
    fi

    echo "Pegá la clave pública completa (una línea, empieza con 'ssh-rsa' o 'ssh-ed25519')"
    read -p "y presioná Enter: " clave_publica

    if [ -z "$clave_publica" ]; then
        echo "[-] No ingresaste ninguna clave."
        return
    fi

    if grep -qF "$clave_publica" "$archivo_authorized" 2>/dev/null; then
        echo "[i] Esa clave ya estaba agregada, no se duplica."
        return
    fi

    echo "$clave_publica" >> "$archivo_authorized"
    chown "$USUARIO_BACKUP":"$USUARIO_BACKUP" "$archivo_authorized"
    chmod 600 "$archivo_authorized"
    echo "[+] Clave agregada. El Servidor 1 ya puede conectarse sin contraseña."
    log_accion "Clave pública agregada a authorized_keys de $USUARIO_BACKUP"
}

# --- 3. Ver qué backups llegaron ---
listar_backups() {
    echo "[+] Backups en $DESTINO_BACKUPS_REMOTO:"
    ls -lh "$DESTINO_BACKUPS_REMOTO" 2>/dev/null || echo "  (todavía no llegó ningún backup)"
    echo ""
    echo "[+] Espacio usado por los backups:"
    du -sh "$DESTINO_BACKUPS_REMOTO" 2>/dev/null
    echo ""
    echo "[+] Espacio disponible en el disco:"
    df -h "$DESTINO_BACKUPS_REMOTO" 2>/dev/null
}

# --- 4. Verificar que un backup no esté corrupto ---
# Para .tar.gz prueba que se pueda listar sin errores; para .sql
# chequea que no esté vacío y que tenga contenido de un dump válido.
verificar_backup() {
    listar_backups
    read -p "Nombre del archivo a verificar: " archivo
    ruta="$DESTINO_BACKUPS_REMOTO/$archivo"

    if [ ! -f "$ruta" ]; then
        echo "[-] No se encontró ese archivo."
        return
    fi

    case "$archivo" in
        *.tar.gz)
            if tar -tzf "$ruta" &>/dev/null; then
                echo "[+] El archivo comprimido está íntegro (se puede leer sin errores)."
            else
                echo "[-] El archivo parece estar corrupto."
            fi
            ;;
        *.sql)
            if [ -s "$ruta" ] && head -n 5 "$ruta" | grep -qi "mysql\|CREATE\|INSERT"; then
                echo "[+] El dump de SQL tiene contenido con forma válida."
            else
                echo "[-] El archivo está vacío o no parece un dump de SQL válido."
            fi
            ;;
        *)
            echo "[i] No sé verificar este tipo de archivo automáticamente."
            echo "    Tamaño: $(du -h "$ruta" | cut -f1)"
            ;;
    esac
    log_accion "Verificación ejecutada sobre $archivo"
}

# --- 5. Rotación: borrar backups viejos para no llenar el disco ---
rotar_backups_antiguos() {
    echo "Backups con más de $DIAS_RETENCION días de antigüedad:"
    encontrados=$(find "$DESTINO_BACKUPS_REMOTO" -type f -mtime "+$DIAS_RETENCION" 2>/dev/null)

    if [ -z "$encontrados" ]; then
        echo "[i] No hay backups que superen los $DIAS_RETENCION días."
        return
    fi

    echo "$encontrados"
    read -p "¿Borrar estos archivos? [s/n]: " confirmar
    if [[ "$confirmar" == "s" || "$confirmar" == "S" ]]; then
        find "$DESTINO_BACKUPS_REMOTO" -type f -mtime "+$DIAS_RETENCION" -delete
        echo "[+] Backups antiguos eliminados."
        log_accion "Rotación ejecutada: backups de más de $DIAS_RETENCION días eliminados"
    else
        echo "[-] Operación cancelada."
    fi
}

# --- 6. Programar la rotación para que corra sola todos los días ---
programar_rotacion_automatica() {
    read -p "Hora del día para rotar backups viejos automáticamente (0-23): " hora
    if ! [[ "$hora" =~ ^([0-9]|1[0-9]|2[0-3])$ ]]; then
        echo "[-] Hora inválida."
        return
    fi

    dir_script="$(pwd)"
    linea_cron="0 $hora * * * root find $DESTINO_BACKUPS_REMOTO -type f -mtime +$DIAS_RETENCION -delete"
    (crontab -l 2>/dev/null; echo "$linea_cron") | crontab -
    echo "[+] Rotación automática programada todos los días a las $hora:00 hs,"
    echo "    borra backups con más de $DIAS_RETENCION días."
    log_accion "Rotación automática programada a las $hora hs (retención $DIAS_RETENCION días)"
}

# --- 7. Copiar un backup de vuelta al servidor de apps, para restaurar ---
enviar_backup_a_servidor1() {
    listar_backups
    read -p "Nombre del archivo a devolver: " archivo
    read -p "Usuario en el Servidor 1: " usuario_destino
    read -p "IP del Servidor 1: " ip_destino
    ruta="$DESTINO_BACKUPS_REMOTO/$archivo"

    if [ ! -f "$ruta" ]; then
        echo "[-] No se encontró ese archivo."
        return
    fi

    scp "$ruta" "${usuario_destino}@${ip_destino}:/tmp/"
    if [ $? -eq 0 ]; then
        echo "[+] Backup copiado a /tmp/ en el Servidor 1."
        log_accion "Backup $archivo devuelto a $usuario_destino@$ip_destino"
    else
        echo "[-] No se pudo copiar. Verificá conexión y que el Servidor 1 acepte esta llave."
    fi
}

menu_backup_servidor() {
    while true; do
        clear
        echo "=========================================="
        echo "   SERVIDOR 3 - RESPALDO Y CONTINUIDAD      "
        echo "=========================================="
        echo "1. Preparar servidor (usuario, carpeta, SSH)"
        echo "2. Agregar clave pública recibida"
        echo "3. Listar backups recibidos y espacio usado"
        echo "4. Verificar integridad de un backup"
        echo "5. Rotar backups antiguos (borrado manual)"
        echo "6. Programar rotación automática (cron)"
        echo "7. Devolver un backup al Servidor 1"
        echo "8. Salir"
        echo "=========================================="
        read -p "Seleccioná una opción [1-8]: " op

        case $op in
            1) preparar_servidor ;;
            2) agregar_clave_publica ;;
            3) listar_backups ;;
            4) verificar_backup ;;
            5) rotar_backups_antiguos ;;
            6) programar_rotacion_automatica ;;
            7) enviar_backup_a_servidor1 ;;
            8) exit 0 ;;
            *) echo "[-] Opción inválida." ;;
        esac
        read -p "Presioná [Enter] para continuar..."
    done
}
