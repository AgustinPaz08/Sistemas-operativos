#!/bin/bash
# ==========================================
# MÓDULO: GESTIÓN DE RESPALDOS (BACKUPS)
# Proyecto SiGeRU / terrabit
# ==========================================
# Usa las variables definidas en config.sh (IP_SERVIDOR_BACKUP,
# NOMBRE_BD, DESTINO_BACKUPS_LOCAL, DESTINO_BACKUPS_REMOTO, etc.)

LOG_FILE="./logs/respaldos.log"

log_accion() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# NUEVO: mysqldump/mysql no vienen instalados por defecto en un
# servidor limpio. Sin esto, crear_backup_bd fallaba con
# "mysqldump: command not found" y no quedaba claro por qué.
verificar_cliente_mysql() {
    if ! command -v mysqldump &>/dev/null || ! command -v mysql &>/dev/null; then
        echo "[!] No se encontró el cliente de MySQL en este servidor."
        read -p "¿Instalar mysql-client ahora? [s/n]: " instalar
        if [[ "$instalar" == "s" || "$instalar" == "S" ]]; then
            apt update && apt install -y default-mysql-client
        else
            return 1
        fi
    fi
    return 0
}

# Copia un archivo de backup ya generado hacia el Servidor 3
# (Respaldo y Continuidad), usando scp por SSH.
enviar_a_servidor_backup() {
    archivo="$1"
    echo "[+] Enviando $archivo al servidor de respaldos ($IP_SERVIDOR_BACKUP)..."
    scp "$archivo" "${USUARIO_BACKUP}@${IP_SERVIDOR_BACKUP}:${DESTINO_BACKUPS_REMOTO}/"
    if [ $? -eq 0 ]; then
        echo "[+] Copia enviada correctamente al Servidor 3."
        log_accion "Backup enviado a $IP_SERVIDOR_BACKUP: $(basename "$archivo")"
    else
        echo "[-] No se pudo enviar el backup al servidor remoto. Queda solo en local."
        echo "    Verificá que la llave SSH esté copiada (menú SSH, opción 6)"
        echo "    y que la carpeta $DESTINO_BACKUPS_REMOTO exista en el Servidor 3."
        log_accion "ERROR al enviar backup a $IP_SERVIDOR_BACKUP: $(basename "$archivo")"
    fi
}

# Backup de las carpetas de la aplicación (Servidor 1).
# CORREGIDO: las opciones ahora reflejan la estructura real del
# proyecto (Backend/ y Frontend/), no las 3 APIs separadas que
# no existen en el repo.
crear_backup_aplicaciones() {
    echo "Carpetas configuradas para backup:"
    echo "  1. Backend    ($RUTA_BACKEND)"
    echo "  2. Frontend   ($RUTA_FRONTEND)"
    echo "  3. Todo el proyecto junto ($RUTA_PROYECTO)"
    read -p "Elegí qué respaldar [1-3]: " op

    case $op in
        1) origen="$RUTA_BACKEND"; nombre="backend" ;;
        2) origen="$RUTA_FRONTEND"; nombre="frontend" ;;
        3) origen="$RUTA_PROYECTO"; nombre="terrabit_completo" ;;
        *) echo "[-] Opción inválida."; return ;;
    esac

    if [ ! -d "$origen" ]; then
        echo "[-] La ruta $origen no existe en este servidor."
        return
    fi

    mkdir -p "$DESTINO_BACKUPS_LOCAL"
    fecha=$(date '+%Y%m%d_%H%M%S')
    archivo="$DESTINO_BACKUPS_LOCAL/backup_${nombre}_$fecha.tar.gz"
    tar -czf "$archivo" -C "$(dirname "$origen")" "$(basename "$origen")"
    echo "[+] Backup local creado: $archivo"
    log_accion "Backup de $nombre creado en local"

    read -p "¿Enviar copia al Servidor 3 (Respaldo y Continuidad)? [s/n]: " enviar
    if [[ "$enviar" == "s" || "$enviar" == "S" ]]; then
        enviar_a_servidor_backup "$archivo"
    fi
}

# Backup de la base de datos (Servidor 2), pensado para correrse
# desde el servidor de aplicaciones o desde el propio servidor de BD.
# CORREGIDO: valida que exista el cliente de mysql antes de intentar
# el dump, y usa el puerto de config.sh en vez de asumir el 3306
# por defecto (por si en algún servidor se publica en otro puerto).
crear_backup_bd() {
    if ! verificar_cliente_mysql; then
        echo "[-] No se puede continuar sin el cliente de MySQL."
        return
    fi

    read -p "Usuario de MySQL: " usuario_bd
    mkdir -p "$DESTINO_BACKUPS_LOCAL"
    fecha=$(date '+%Y%m%d_%H%M%S')
    archivo="$DESTINO_BACKUPS_LOCAL/backup_bd_${NOMBRE_BD}_$fecha.sql"

    # Si este script corre en el servidor de apps y la BD está en el
    # Servidor 2 (en un contenedor Docker), se conecta por red con -h;
    # si corre en el propio servidor de BD, -h 127.0.0.1 también sirve
    # porque el docker-compose publica el puerto en el host.
    mysqldump -h "$IP_SERVIDOR_BD" -P "$PUERTO_BD" -u "$usuario_bd" -p "$NOMBRE_BD" > "$archivo"

    if [ $? -eq 0 ]; then
        echo "[+] Backup de la base '$NOMBRE_BD' creado en $archivo"
        log_accion "Backup de BD '$NOMBRE_BD' creado"
        read -p "¿Enviar copia al Servidor 3 (Respaldo y Continuidad)? [s/n]: " enviar
        if [[ "$enviar" == "s" || "$enviar" == "S" ]]; then
            enviar_a_servidor_backup "$archivo"
        fi
    else
        echo "[-] Falló el backup de la base de datos."
        echo "    Verificá conexión a $IP_SERVIDOR_BD:$PUERTO_BD y que el"
        echo "    contenedor de MySQL esté corriendo en el Servidor 2."
        rm -f "$archivo"
    fi
}

listar_backups_locales() {
    echo "[+] Backups locales en $DESTINO_BACKUPS_LOCAL:"
    ls -lh "$DESTINO_BACKUPS_LOCAL" 2>/dev/null || echo "  (aún no hay backups locales)"
}

listar_backups_remotos() {
    echo "[+] Backups en el Servidor 3 ($IP_SERVIDOR_BACKUP):"
    ssh "${USUARIO_BACKUP}@${IP_SERVIDOR_BACKUP}" "ls -lh $DESTINO_BACKUPS_REMOTO" 2>/dev/null \
        || echo "[-] No se pudo conectar al servidor de respaldos."
}

restaurar_backup_bd() {
    if ! verificar_cliente_mysql; then
        echo "[-] No se puede continuar sin el cliente de MySQL."
        return
    fi

    listar_backups_locales
    read -p "Nombre del archivo .sql a restaurar (debe estar en local): " archivo
    read -p "Usuario de MySQL: " usuario_bd
    ruta_completa="$DESTINO_BACKUPS_LOCAL/$archivo"
    if [ ! -f "$ruta_completa" ]; then
        echo "[-] El archivo no existe en $DESTINO_BACKUPS_LOCAL."
        return
    fi
    mysql -h "$IP_SERVIDOR_BD" -P "$PUERTO_BD" -u "$usuario_bd" -p "$NOMBRE_BD" < "$ruta_completa"
    if [ $? -eq 0 ]; then
        echo "[+] Restauración completada sobre la base '$NOMBRE_BD' en $IP_SERVIDOR_BD."
        log_accion "Restauración ejecutada desde $archivo"
    else
        echo "[-] Falló la restauración. Verificá conexión y credenciales."
    fi
}

programar_backup_automatico() {
    echo "Este cron va a respaldar la carpeta completa de terrabit todos los días"
    echo "y enviar la copia al Servidor 3 automáticamente."
    echo "[!] Recordá haber configurado antes el acceso SSH sin contraseña"
    echo "    (menú SSH, opción 6), o el cron va a fallar en silencio."
    read -p "Hora del backup diario (0-23): " hora
    if ! [[ "$hora" =~ ^([0-9]|1[0-9]|2[0-3])$ ]]; then
        echo "[-] Hora inválida."
        return
    fi

    linea_cron="0 $hora * * * root bash -c 'tar -czf ${DESTINO_BACKUPS_LOCAL}/auto_\$(date +\%Y\%m\%d).tar.gz ${RUTA_PROYECTO} && scp ${DESTINO_BACKUPS_LOCAL}/auto_\$(date +\%Y\%m\%d).tar.gz ${USUARIO_BACKUP}@${IP_SERVIDOR_BACKUP}:${DESTINO_BACKUPS_REMOTO}/'"
    (crontab -l 2>/dev/null; echo "$linea_cron") | crontab -
    echo "[+] Backup automático programado todos los días a las $hora:00 hs,"
    echo "    con envío al Servidor 3 ($IP_SERVIDOR_BACKUP) incluido."
    log_accion "Cron de backup programado a las $hora hs, envío a $IP_SERVIDOR_BACKUP"
}

menu_respaldos() {
    while true; do
        clear
        echo "=========================================="
        echo "   GESTIÓN DE RESPALDOS - terrabit          "
        echo "   (Servidor 3: $IP_SERVIDOR_BACKUP)        "
        echo "=========================================="
        echo "1. Backup de carpetas de la aplicación (Servidor 1)"
        echo "2. Backup de base de datos '$NOMBRE_BD' (Servidor 2)"
        echo "3. Listar backups locales"
        echo "4. Listar backups en el Servidor 3"
        echo "5. Restaurar backup de base de datos"
        echo "6. Programar backup automático (cron)"
        echo "7. Volver al menú principal"
        echo "=========================================="
        read -p "Seleccioná una opción [1-7]: " op

        case $op in
            1) crear_backup_aplicaciones ;;
            2) crear_backup_bd ;;
            3) listar_backups_locales ;;
            4) listar_backups_remotos ;;
            5) restaurar_backup_bd ;;
            6) programar_backup_automatico ;;
            7) break ;;
            *) echo "[-] Opción inválida." ;;
        esac
        read -p "Presioná [Enter] para continuar..."
    done
}
