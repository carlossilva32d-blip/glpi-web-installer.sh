#!/bin/bash
# ============================================
# GLPI INSTALLATION - APLICACIONES (VM1)
# ============================================
# 
# BASADO EXACTAMENTE EN LOS PASOS DE PRUEBA
# 
# INSTRUCCIONES EN EL TRABAJO:
# 1. CAMBIAR los valores en la sección "===== CAMBIAR ====="
# 2. Copiar este script a la VM1
# 3. Ejecutar: chmod +x 02-install-web.sh && ./02-install-web.sh
# 4. DESPUÉS del script, configurar PHP manualmente
# 
# ============================================

set -e  # Detener si hay error

# ============================================
# ========== CAMBIAR ESTOS VALORES ==========
# ============================================

# IP del servidor de BASE DE DATOS (VM2) - poner la IP real en Proxmox
DB_IP="IP_DEL_SERVIDOR_BD_AQUI"        # <--- CAMBIAR

# Zona horaria
TIMEZONE="America/Caracas"              # <--- CAMBIAR si es necesario

# ============================================
# ========== NO CAMBIAR ==========
# ============================================

GLPI_VERSION="11.0.6"
GLPI_URL="https://github.com/glpi-project/glpi/releases/download/${GLPI_VERSION}/glpi-${GLPI_VERSION}.tgz"

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# ============================================
# INICIO
# ============================================

echo ""
echo "============================================"
echo "  GLPI - INSTALACIÓN APLICACIONES (VM1)"
echo "============================================"
echo ""
log_info "IP Base de Datos (VM2): ${DB_IP}"
echo ""
read -p "Presiona ENTER para continuar..."

# ============================================
# PASO 1: Actualizar e instalar Apache y PHP
# ============================================
log_info "Paso 1/11: Instalando Apache y PHP..."
apt update && apt upgrade -y
apt install -y apache2 php php-{apcu,cli,common,curl,gd,imap,ldap,mysql,xmlrpc,xml,mbstring,bcmath,intl,zip,redis,bz2} libapache2-mod-php php-soap php-cas wget netcat-openbsd

# ============================================
# PASO 2: Descargar GLPI
# ============================================
log_info "Paso 2/11: Descargando GLPI ${GLPI_VERSION}..."
cd /var/www/html
wget ${GLPI_URL}
tar -xvzf glpi-${GLPI_VERSION}.tgz

# ============================================
# PASO 3: Crear downstream.php
# ============================================
log_info "Paso 3/11: Configurando downstream.php..."
cat > /var/www/html/glpi/inc/downstream.php <<'EOF'
<?php
define('GLPI_CONFIG_DIR', '/etc/glpi/');
if (file_exists(GLPI_CONFIG_DIR . '/local_define.php')) {
    require_once GLPI_CONFIG_DIR . '/local_define.php';
}
EOF

# ============================================
# PASO 4: Crear estructura de directorios
# ============================================
log_info "Paso 4/11: Creando estructura de directorios..."
mkdir -p /etc/glpi
mkdir -p /var/lib/glpi
mkdir -p /var/log/glpi

# ============================================
# PASO 5: Crear local_define.php
# ============================================
log_info "Paso 5/11: Configurando local_define.php..."
cat > /etc/glpi/local_define.php <<'EOF'
<?php
define('GLPI_VAR_DIR', '/var/lib/glpi');
define('GLPI_DOC_DIR', GLPI_VAR_DIR);
define('GLPI_CRON_DIR', GLPI_VAR_DIR . '/_cron');
define('GLPI_DUMP_DIR', GLPI_VAR_DIR . '/_dumps');
define('GLPI_GRAPH_DIR', GLPI_VAR_DIR . '/_graphs');
define('GLPI_LOCK_DIR', GLPI_VAR_DIR . '/_lock');
define('GLPI_PICTURE_DIR', GLPI_VAR_DIR . '/_pictures');
define('GLPI_PLUGIN_DOC_DIR', GLPI_VAR_DIR . '/_plugins');
define('GLPI_RSS_DIR', GLPI_VAR_DIR . '/_rss');
define('GLPI_SESSION_DIR', GLPI_VAR_DIR . '/_sessions');
define('GLPI_TMP_DIR', GLPI_VAR_DIR . '/_tmp');
define('GLPI_UPLOAD_DIR', GLPI_VAR_DIR . '/_uploads');
define('GLPI_CACHE_DIR', GLPI_VAR_DIR . '/_cache');
define('GLPI_LOG_DIR', '/var/log/glpi');
EOF

# ============================================
# PASO 6: Mover directorios
# ============================================
log_info "Paso 6/11: Moviendo directorios a sus ubicaciones..."
mv /var/www/html/glpi/config /etc/glpi/
mv /var/www/html/glpi/files /var/lib/glpi/

# Mover logs si existen
if [ -d "/var/lib/glpi/_log" ]; then
    mv /var/lib/glpi/_log/* /var/log/glpi/ 2>/dev/null || true
    rm -rf /var/lib/glpi/_log
fi

# ============================================
# PASO 7: Configurar permisos
# ============================================
log_info "Paso 7/11: Configurando permisos..."
chown root:root /var/www/html/glpi/ -R
chown www-data:www-data /etc/glpi -R
chown www-data:www-data /var/lib/glpi -R
chown www-data:www-data /var/log/glpi -R
chown www-data:www-data /var/www/html/glpi/marketplace -Rf 2>/dev/null || true

find /var/www/html/glpi/ -type f -exec chmod 0644 {} \;
find /var/www/html/glpi/ -type d -exec chmod 0755 {} \;
find /etc/glpi -type f -exec chmod 0644 {} \;
find /etc/glpi -type d -exec chmod 0755 {} \;
find /var/lib/glpi -type f -exec chmod 0644 {} \;
find /var/lib/glpi -type d -exec chmod 0755 {} \;
find /var/log/glpi -type f -exec chmod 0644 {} \;
find /var/log/glpi -type d -exec chmod 0755 {} \;

# ============================================
# PASO 8: Configurar Virtual Host de Apache
# ============================================
log_info "Paso 8/11: Configurando Virtual Host..."
cat > /etc/apache2/sites-available/glpi.conf <<'EOF'
<VirtualHost *:80>
    ServerName glpi.local
    DocumentRoot /var/www/html/glpi/public
    
    <Directory /var/www/html/glpi/public>
        Require all granted
        RewriteEngine On
        
        RewriteCond %{HTTP:Authorization} ^(.+)$
        RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
        
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteRule ^(.*)$ index.php [QSA,L]
    </Directory>
    
    ErrorLog ${APACHE_LOG_DIR}/glpi_error.log
    CustomLog ${APACHE_LOG_DIR}/glpi_access.log combined
</VirtualHost>
EOF

# ============================================
# PASO 9: Habilitar sitio y módulos
# ============================================
log_info "Paso 9/11: Habilitando sitio y módulos..."
a2dissite 000-default.conf 2>/dev/null || true
a2ensite glpi.conf
a2enmod rewrite
systemctl restart apache2

# ============================================
# PASO 10: Verificar conectividad con Base de Datos
# ============================================
log_info "Paso 10/11: Verificando conexión con Base de Datos..."
echo ""
log_info "Ejecutando: nc -zv ${DB_IP} 3306"
nc -zv ${DB_IP} 3306

echo ""
log_info "Si ves '(UNKNOWN) [${DB_IP}] 3306 (mysql) open', la conexión es exitosa"
log_warn "El mensaje 'inverse host lookup failed' se puede ignorar"
echo ""
read -p "¿La conexión fue exitosa? Presiona ENTER para continuar..."

# ============================================
# PASO 11: Configuración manual de PHP
# ============================================
log_info "Paso 11/11: Configuración manual de PHP..."
echo ""
log_warn "=========================================="
log_warn "AHORA DEBES CONFIGURAR PHP MANUALMENTE"
log_warn "=========================================="
echo ""
log_info "1. Detecta la versión de PHP instalada:"
echo "   php -v"
echo ""
log_info "2. Edita el archivo php.ini correspondiente:"
PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
echo "   nano /etc/php/${PHP_VERSION}/apache2/php.ini"
echo ""
log_info "3. Busca y cambia estos valores:"
echo "   upload_max_filesize = 20M"
echo "   post_max_size = 20M"
echo "   max_execution_time = 60"
echo "   max_input_vars = 5000"
echo "   memory_limit = 256M"
echo "   session.cookie_httponly = On"
echo "   date.timezone = ${TIMEZONE}"
echo ""
log_info "4. Reinicia Apache:"
echo "   systemctl restart apache2"
echo ""

# ============================================
# FINAL
# ============================================
echo ""
log_info "=========================================="
log_info "¡INSTALACIÓN DE APLICACIONES COMPLETADA!"
log_info "=========================================="
echo ""
log_info "Accede a GLPI desde tu navegador:"
echo "  http://$(hostname -I | awk '{print $1}')"
echo ""
log_info "Datos para la instalación web:"
echo "  Servidor SQL: ${DB_IP}"
echo "  Usuario SQL: glpi"
echo "  Contraseña SQL: TU_CONTRASEÑA_GLPI_AQUI"
echo "  Base de datos: glpi"
echo ""
log_info "Credenciales por defecto:"
echo "  Administrador: glpi / glpi"
echo "  Técnico: tech / tech"
echo "  Usuario: normal / normal"
echo ""
log_warn "DESPUÉS DE LA INSTALACIÓN WEB, elimina install.php:"
echo "  rm /var/www/html/glpi/install/install.php"
echo ""


