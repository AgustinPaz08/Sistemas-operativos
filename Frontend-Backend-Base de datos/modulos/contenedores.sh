#!/bin/bash
# ==========================================
# MÓDULO: GESTIÓN DE CONTENEDORES (Docker)
# ==========================================

LOG_FILE="./logs/contenedores.log"

log_accion() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# CORREGIDO: "docker.io" + "docker-compose" (paquete viejo, v1) puede
# no estar disponible en distros nuevas, y quedó descontinuado por
# Docker. Ahora se instala desde el repositorio oficial de Docker,
# con el plugin moderno "docker compose" (sin guion).
instalar_docker() {
    if command -v docker &>/dev/null && docker compose version &>/dev/null; then
        echo "[+] Docker y el plugin de compose ya están instalados."
        docker --version
        docker compose version
        return
    fi

    echo "[+] Instalando Docker desde el repositorio oficial..."
    apt update
    apt install -y ca-certificates curl gnupg

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Usa el codename real de Ubuntu (funciona también en derivadas
    # como Debian/Mint siempre que exista UBUNTU_CODENAME; si no,
    # cae al VERSION_CODENAME normal).
    codename=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $codename stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    systemctl enable docker
    systemctl start docker
    log_accion "Docker instalado (repo oficial) y habilitado"
}

listar_contenedores() {
    echo "[+] Contenedores activos:"
    docker ps
    echo ""
    echo "[+] Todos los contenedores (incluyendo detenidos):"
    docker ps -a
}

iniciar_contenedor() {
    read -p "Nombre o ID del contenedor a iniciar: " cont
    docker start "$cont"
    log_accion "Contenedor iniciado: $cont"
}

detener_contenedor() {
    read -p "Nombre o ID del contenedor a detener: " cont
    docker stop "$cont"
    log_accion "Contenedor detenido: $cont"
}

# CORREGIDO: usa "docker compose" (plugin moderno) en vez de
# "docker-compose" (v1, que ya no se instala por defecto).
desplegar_compose() {
    ruta="$RUTA_DOCKER_COMPOSE"
    read -p "Ruta del docker-compose.yml [Enter = $ruta]: " ruta_ingresada
    if [ -n "$ruta_ingresada" ]; then
        ruta="$ruta_ingresada"
    fi
    if [ ! -f "$ruta/docker-compose.yml" ]; then
        echo "[-] No se encontró docker-compose.yml en $ruta."
        return
    fi
    echo "[+] Levantando servicios de terrabit definidos en $ruta..."
    (cd "$ruta" && docker compose up -d --build)
    echo "[+] Servicios levantados con docker compose."
    log_accion "docker compose up ejecutado en $ruta"
}

ver_logs_contenedor() {
    read -p "Nombre o ID del contenedor: " cont
    docker logs --tail 50 "$cont"
}

menu_contenedores() {
    while true; do
        clear
        echo "=========================================="
        echo "        GESTIÓN DE CONTENEDORES             "
        echo "=========================================="
        echo "1. Instalar Docker"
        echo "2. Listar contenedores"
        echo "3. Iniciar un contenedor"
        echo "4. Detener un contenedor"
        echo "5. Desplegar con docker compose"
        echo "6. Ver logs de un contenedor"
        echo "7. Volver al menú principal"
        echo "=========================================="
        read -p "Seleccioná una opción [1-7]: " op

        case $op in
            1) instalar_docker ;;
            2) listar_contenedores ;;
            3) iniciar_contenedor ;;
            4) detener_contenedor ;;
            5) desplegar_compose ;;
            6) ver_logs_contenedor ;;
            7) break ;;
            *) echo "[-] Opción inválida." ;;
        esac
        read -p "Presioná [Enter] para continuar..."
    done
}
