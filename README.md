```
GLPI EN DEBIAN 12 - DOS VIRTUAL MACHINES

Autor: Carlos Silva
Sistema: Debian 12

================================================================================

ESTRUCTURA DE VMS:

VM1: Base de Datos (MariaDB)
VM2: Web / Aplicación (Apache + PHP + GLPI)

================================================================================

SCRIPT 1: BASE DE DATOS (VM2)
================================================================================

chmod +x glpi-db-installer.sh
./glpi-db-installer.sh

CAMBIAR ANTES DE EJECUTAR:
- WEB_IP = IP de la VM1 (servidor web)
- DB_PASSWORD = contraseña para la base de datos

================================================================================

SCRIPT 2: WEB/APP (VM1)
================================================================================

chmod +x glpi-web-installer.sh
./glpi-web-installer.sh

CAMBIAR ANTES DE EJECUTAR:
- DB_IP = IP de la VM2 (servidor de base de datos)
- TIMEZONE = tu zona horaria (ej: America/Caracas)

================================================================================

DESPUÉS DE EJECUTAR AMBOS SCRIPTS
================================================================================

1. Accede a GLPI: http://IP_VM1

2. Datos para la instalación web:
   - Servidor SQL: IP_VM2
   - Usuario SQL: glpi
   - Contraseña SQL: (la que pusiste en DB_PASSWORD)
   - Base de datos: glpi

3. Credenciales por defecto:
   - Administrador: glpi / glpi
   - Técnico: tech / tech
   - Usuario: normal / normal

4. Eliminar install.php por seguridad:
   rm /var/www/html/glpi/install/install.php

================================================================================

CONFIGURAR PHP MANUALMENTE
================================================================================

nano /etc/php/8.2/apache2/php.ini

Cambiar:
- upload_max_filesize = 20M
- post_max_size = 20M
- max_execution_time = 60
- max_input_vars = 5000
- memory_limit = 256M
- session.cookie_httponly = On
- date.timezone = America/Caracas

systemctl restart apache2

================================================================================

CONTACTO
================================================================================
GitHub: CarlosSilva32d-blip
Correo: carlossilva32d@gmail.com

LICENCIA: Uso libre para fines educativos y profesionales.
```
