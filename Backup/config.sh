#!/bin/bash
# ==========================================
# CONFIGURACIÓN - SERVIDOR 3 (Respaldo y Continuidad)
# Proyecto SiGeRU / terrabit
# ==========================================

# --- Identidad de este servidor ---
IP_SERVIDOR_BACKUP="192.168.100.30"

# --- Usuario que recibe los backups por SSH/SCP desde el Servidor 1 ---
USUARIO_BACKUP="admin"

# --- Dónde se guardan los backups recibidos ---
DESTINO_BACKUPS_REMOTO="/srv/backups/terrabit"

# --- Política de retención ---
# Backups más viejos que esta cantidad de días se consideran
# candidatos a borrado en la rotación automática.
DIAS_RETENCION=30
