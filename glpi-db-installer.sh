#!/bin/bash
# ============================================
# GLPI INSTALLATION - BASE DE DATOS (VM2)
# ============================================
# 
# INSTRUCCIONES EN EL TRABAJO:
# 1. CAMBIAR los valores en la sección "===== CAMBIAR ====="
# 2. Copiar este script a la VM2
# 3. Ejecutar: chmod +x 01-install-db.sh && ./01-install-db.sh
# 
# ============================================

set -e  # Detener si hay error

# ============================================
# ========== CAMBIAR ESTOS VALORES ==========
# ============================================

# IP del servidor WEB (VM1) - poner la IP real en Proxmox
WEB_IP="IP_DEL_SERVIDOR_WEB_AQUI"              # <--- CAMBIAR

# Contraseña para el usuario 'glpi' de la base de datos
DB_PASSWORD="TU_CONTRASEÑA_GLPI_AQUI"          # <--- CAMBIAR

# ============================================
# ========== NO CAMBIAR ==========
# ============================================

DB_NAME="glpi"
DB_USER="glpi"
MYSQL_ROOT_PASSWORD="${DB_PASSWORD}"

# Colores
GREEN='\033[0;32m'
NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }

# ============================================
# INICIO
# ============================================

echo ""
echo "============================================"
echo "  GLPI - INSTALACIÓN BASE DE DATOS (VM2)"
echo "============================================"
echo ""
log_info "IP Web (VM1): ${WEB_IP}"
log_info "Contraseña DB: ${DB_PASSWORD}"
echo ""
read -p "Presiona ENTER para continuar..."

# ============================================
# PASO 1: Actualizar e instalar MariaDB
# ============================================
log_info "Paso 1/5: Instalando MariaDB..."
apt update && apt upgrade -y
apt install -y mariadb-server
systemctl enable mariadb
systemctl start mariadb

# ============================================
# PASO 2: Configurar seguridad (mysql_secure_installation)
# ============================================
log_info "Paso 2/5: Configurando seguridad..."

mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';" 2>/dev/null || true
mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "DELETE FROM mysql.user WHERE User='';" 2>/dev/null || true
mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "DROP DATABASE IF EXISTS test;" 2>/dev/null || true
mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" 2>/dev/null || true
mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "FLUSH PRIVILEGES;" 2>/dev/null || true

# ============================================
# PASO 3: Zonas horarias
# ============================================
log_info "Paso 3/5: Cargando zonas horarias..."
mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -u root -p${MYSQL_ROOT_PASSWORD} mysql

# ============================================
# PASO 4: Crear base de datos y usuarios
# ============================================
log_info "Paso 4/5: Creando base de datos y usuarios..."

mysql -u root -p${MYSQL_ROOT_PASSWORD} <<EOF
CREATE DATABASE ${DB_NAME};
CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
GRANT SELECT ON mysql.time_zone_name TO '${DB_USER}'@'localhost';
CREATE USER '${DB_USER}'@'${WEB_IP}' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'${WEB_IP}';
GRANT SELECT ON mysql.time_zone_name TO '${DB_USER}'@'${WEB_IP}';
FLUSH PRIVILEGES;
EOF

# ============================================
# PASO 5: Configurar bind-address y reiniciar
# ============================================
log_info "Paso 5/5: Configurando escucha remota..."

sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf
systemctl restart mariadb

# ============================================
# FINAL
# ============================================
echo ""
log_info "=========================================="
log_info "¡INSTALACIÓN COMPLETADA!"
log_info "=========================================="
echo ""
log_info "Datos para VM1 (Web):"
echo "  Servidor BD: $(hostname -I | awk '{print $1}')"
echo "  Usuario: ${DB_USER}"
echo "  Contraseña: ${DB_PASSWORD}"
echo "  Base datos: ${DB_NAME}"
echo ""
log_info "Verifica conectividad desde VM1:"
echo "  nc -zv $(hostname -I | awk '{print $1}') 3306"
echo ""
