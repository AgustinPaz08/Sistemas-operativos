#!/bin/bash
# ==========================================
# CONFIGURACIÓN DEL PROYECTO - SiGeRU / terrabit
# ==========================================
# Este archivo centraliza los datos de la infraestructura
# para no repetirlos en cada módulo. Si cambia una IP o un
# nombre, se edita acá una sola vez.

# --- Servidores del proyecto ---
IP_SERVIDOR_APP="192.168.100.10"       # Web Frontend / API Backend
IP_SERVIDOR_BD="192.168.100.20"        # Motor de Base de Datos (MySQL, en Docker)
IP_SERVIDOR_BACKUP="192.168.100.30"    # Respaldo y Continuidad

# --- Usuario SSH para conectarse al servidor de respaldos ---
# (tiene que existir en el servidor 3 y tener acceso por llave SSH
# configurada, para que el backup se copie sin pedir contraseña.
# Usá la opción "Copiar llave a otro servidor" del menú de SSH
# para configurarlo antes de programar backups automáticos.)
USUARIO_BACKUP="admin"

# --- Base de datos ---
# CORREGIDO: en este proyecto MySQL corre dentro de un contenedor
# Docker (ver docker-compose.yml), no instalado nativo en el
# Servidor 2. La imagen oficial de MySQL ya crea el usuario con
# permiso de acceso desde cualquier host ('%'), así que mysqldump/
# mysql remotos funcionan mientras el puerto 3306 esté publicado
# (docker-compose ya lo hace) y el firewall del Servidor 2 lo permita.
NOMBRE_BD="terrabit"
PUERTO_BD="3306"

# --- Rutas de la aplicación en el servidor de apps ---
# CORREGIDO: el proyecto real solo tiene Backend/ y Frontend/
# dentro de la carpeta del repo (no existen api-usuarios,
# api-gestion, api-recoleccion, ni landing como carpetas separadas).
# Si en el futuro se separan en microservicios, agregar acá las
# rutas nuevas y las opciones correspondientes en respaldos.sh.
RUTA_PROYECTO="/var/www/terrabit"
RUTA_BACKEND="$RUTA_PROYECTO/Backend"
RUTA_FRONTEND="$RUTA_PROYECTO/Frontend"

# --- Ruta local donde se guardan los backups antes de enviarlos ---
DESTINO_BACKUPS_LOCAL="/var/backups/terrabit"

# --- Ruta remota en el servidor de respaldos donde se almacenan ---
DESTINO_BACKUPS_REMOTO="/srv/backups/terrabit"

# --- Ruta del docker-compose que levanta los servicios ---
RUTA_DOCKER_COMPOSE="$RUTA_PROYECTO"
