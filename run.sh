#!/bin/bash

DESTINATION=$1
PORT=$2
CHAT=$3
# Obtener el nombre de usuario y grupo actuales
USER=$(whoami)
GROUP=$(id -gn $USER)

# Obtener la ruta absoluta del directorio actual
CURRENT_DIR=$(pwd)
ABSOLUTE_DESTINATION="$CURRENT_DIR/$DESTINATION"

# Función para instalar Docker
install_docker() {
    echo "Docker no detectado. Instalando Docker..."
    # Actualizar paquetes
    apt-get update
    # Instalar dependencias
    apt-get install -y ca-certificates curl gnupg lsb-release nano sudo
    # Agregar clave GPG oficial de Docker
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    # Configurar repositorio
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    # Actualizar paquetes e instalar Docker
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    # Agregar usuario al grupo docker
    usermod -aG docker $USER
    # Iniciar y habilitar Docker
    systemctl start docker
    systemctl enable docker
    echo "Docker instalado exitosamente."
}

# Función para instalar Docker Compose
install_docker_compose() {
    echo "Docker Compose no detectado. Instalando Docker Compose..."
    # Primero intentar con apt (Debian/Ubuntu)
    if apt-get install -y docker-compose-plugin 2>/dev/null; then
        echo "Docker Compose plugin instalado via apt."
    else
        # Si falla, instalar manualmente
        echo "Instalando Docker Compose manualmente..."
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi
    echo "Docker Compose instalado exitosamente."
}

# Verificar e instalar Docker si no existe
if ! command -v docker &> /dev/null; then
    install_docker
    echo "Por favor, reinicie la sesión o ejecute 'newgrp docker' para aplicar los cambios de grupo."
    echo "Luego ejecute este script nuevamente."
    exit 1
fi

# Verificar e instalar Docker Compose si no existe
if ! command -v docker-compose &> /dev/null; then
    # Verificar si docker compose (con espacio) está disponible
    if docker compose version &> /dev/null 2>&1; then
        echo "Detectado 'docker compose'. Creando alias docker-compose..."
        # Crear alias permanente para docker-compose
        echo 'alias docker-compose="docker compose"' >> ~/.bashrc
        echo 'alias docker-compose="docker compose"' >> ~/.bash_aliases 2>/dev/null || true
        # Crear symlink para todo el sistema
        echo '#!/bin/bash
exec docker compose "$@"' | sudo tee /usr/local/bin/docker-compose > /dev/null
        sudo chmod +x /usr/local/bin/docker-compose
        echo "Alias docker-compose creado exitosamente."
    else
        install_docker_compose
    fi
fi

echo "Docker y Docker Compose están disponibles."

# Clonar el directorio de Odoo
git clone --depth=1 https://github.com/tomasecastro/odoo-18-docker-compose $ABSOLUTE_DESTINATION
rm -rf $ABSOLUTE_DESTINATION/.git

# Crear el directorio de PostgreSQL
mkdir -p $ABSOLUTE_DESTINATION/postgresql

apt-get update && apt-get install -y sudo unzip
# Cambiar la propiedad al usuario actual y establecer permisos restrictivos por seguridad
sudo chown -R $USER:$USER $ABSOLUTE_DESTINATION
sudo chmod -R 700 $ABSOLUTE_DESTINATION  # Solo el usuario tiene acceso

# Generar claves dinámicamente si no están definidas en el archivo .env
if ! grep -q "^POSTGRES_PASSWORD=" $ABSOLUTE_DESTINATION/.env; then
  export POSTGRES_PASSWORD=$(openssl rand -base64 12)  # Generar una clave de acceso aleatoria
  echo "POSTGRES_PASSWORD=$POSTGRES_PASSWORD" >> $ABSOLUTE_DESTINATION/.env
else
  # Si ya existe, actualizar el valor
  sed -i "s#^POSTGRES_PASSWORD=.*#POSTGRES_PASSWORD=$(openssl rand -base64 12)#" $ABSOLUTE_DESTINATION/.env
fi

# Actualizar las variables ODOO_PORT y ODOO_LONGPOLLING_PORT en el archivo .env
if ! grep -q "^ODOO_PORT=" $ABSOLUTE_DESTINATION/.env; then
  echo "ODOO_PORT=$PORT" >> $ABSOLUTE_DESTINATION/.env
else
  # Si ya existe, actualizar el valor
  sed -i "s#^ODOO_PORT=.*#ODOO_PORT=$PORT#" $ABSOLUTE_DESTINATION/.env
fi

if ! grep -q "^ODOO_LONGPOLLING_PORT=" $ABSOLUTE_DESTINATION/.env; then
  echo "ODOO_LONGPOLLING_PORT=$CHAT" >> $ABSOLUTE_DESTINATION/.env
else
  # Si ya existe, actualizar el valor
  sed -i "s#^ODOO_LONGPOLLING_PORT=.*#ODOO_LONGPOLLING_PORT=$CHAT#" $ABSOLUTE_DESTINATION/.env
fi


# Establecer permisos de archivos y directorios después de la instalación
find $ABSOLUTE_DESTINATION -type f -exec chmod 644 {} \;
find $ABSOLUTE_DESTINATION -type d -exec chmod 755 {} \;



# Obtener la dirección IP local
IP_ADDRESS=$(hostname -I | awk '{print $1}')

# Descomprimir archivos zip de addons si existen
if ls $ABSOLUTE_DESTINATION/odoo/addons/*.zip 1> /dev/null 2>&1; then
    unzip -x $ABSOLUTE_DESTINATION/odoo/addons/*.zip -d $ABSOLUTE_DESTINATION/odoo/addons/
    rm -r $ABSOLUTE_DESTINATION/odoo/addons/*.zip
fi

# Establecer permisos 777 para los directorios específicos
chmod -R 777 $ABSOLUTE_DESTINATION/odoo/addons $ABSOLUTE_DESTINATION/odoo/etc $ABSOLUTE_DESTINATION/postgresql
chmod -R 777 $ABSOLUTE_DESTINATION/odoo/build/entrypoint.sh
chmod -R 777 $ABSOLUTE_DESTINATION/odoo/etc/logrotate

# Ejecutar Odoo
docker-compose -f $ABSOLUTE_DESTINATION/docker-compose.yml up -d

# Mostrar información de acceso
echo "Todas los datos de acceso como usuarios y contraselas estan dentro en el archivo $ABSOLUTE_DESTINATION/.env"
echo "Odoo iniciado en http://$IP_ADDRESS:$PORT | Contraseña maestra: minhng.info | Puerto de chat en vivo: $CHAT"
