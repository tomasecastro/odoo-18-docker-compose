#!/bin/bash

DESTINATION=$1
PORT=$2
CHAT=$3
MINIO_PATH=$DESTINATION/odoo/odoo-data
# Obtener el nombre de usuario y grupo actuales
USER=$(whoami)
GROUP=$(id -gn $USER)

# Clonar el directorio de Odoo
git clone --depth=1 https://github.com/tomasecastro/odoo-18-docker-compose $DESTINATION
rm -rf $DESTINATION/.git

# Crear el directorio de PostgreSQL
mkdir -p $DESTINATION/postgresql

apt-get update && apt-get install -y sudo unzip
# Cambiar la propiedad al usuario actual y establecer permisos restrictivos por seguridad
sudo chown -R $USER:$USER $DESTINATION
sudo chmod -R 700 $DESTINATION  # Solo el usuario tiene acceso

# Generar claves de Minio dinámicamente si no están definidas en el archivo .env
if ! grep -q "^POSTGRES_PASSWORD=" $DESTINATION/.env; then
  export POSTGRES_PASSWORD=$(openssl rand -base64 12)  # Generar una clave de acceso aleatoria
  echo "POSTGRES_PASSWORD=$POSTGRES_PASSWORD" >> $DESTINATION/.env
else
  # Si ya existe, actualizar el valor
  sed -i "s#^POSTGRES_PASSWORD=.*#POSTGRES_PASSWORD=$(openssl rand -base64 12)#" $DESTINATION/.env
fi


if ! grep -q "^MINIO_ROOT_USER=" $DESTINATION/.env; then
  export MINIO_ROOT_USER=$(openssl rand -base64 12)  # Generar una clave de acceso aleatoria
  echo "MINIO_ROOT_USER=$MINIO_ROOT_USER" >> $DESTINATION/.env
else
  # Si ya existe, actualizar el valor
  export MINIO_ROOT_USER=$(openssl rand -base64 12)  # Generar una clave de acceso aleatoria
  sed -i "s#^MINIO_ROOT_USER=.*#MINIO_ROOT_USER=$MINIO_ROOT_USER#" $DESTINATION/.env
fi

if ! grep -q "^MINIO_ROOT_PASSWORD=" $DESTINATION/.env; then
  export MINIO_ROOT_PASSWORD=$(openssl rand -base64 16)  # Generar una contraseña aleatoria
  echo "MINIO_ROOT_PASSWORD=$MINIO_ROOT_PASSWORD" >> $DESTINATION/.env
else
  # Si ya existe, actualizar el valor
  export MINIO_ROOT_PASSWORD=$(openssl rand -base64 16)  # Generar una contraseña aleatoria
  sed -i "s#^MINIO_ROOT_PASSWORD=.*#MINIO_ROOT_PASSWORD=$MINIO_ROOT_PASSWORD#" $DESTINATION/.env
fi

if ! grep -q "^MINIO_ACCESS_KEY=" $DESTINATION/.env; then
  export MINIO_ACCESS_KEY=$(openssl rand -base64 12)  # Generar una clave de acceso aleatoria
  echo "MINIO_ACCESS_KEY=$MINIO_ACCESS_KEY" >> $DESTINATION/.env
else
  # Si ya existe, actualizar el valor
  export MINIO_ACCESS_KEY=$(openssl rand -base64 12)  # Generar una clave de acceso aleatoria
  sed -i "s#^MINIO_ACCESS_KEY=.*#MINIO_ACCESS_KEY=$MINIO_ACCESS_KEY#" $DESTINATION/.env
fi

if ! grep -q "^MINIO_SECRET_KEY=" $DESTINATION/.env; then
  export MINIO_SECRET_KEY=$(openssl rand -base64 16)  # Generar una contraseña aleatoria
  echo "MINIO_SECRET_KEY=$MINIO_SECRET_KEY" >> $DESTINATION/.env
else
  # Si ya existe, actualizar el valor
  export MINIO_SECRET_KEY=$(openssl rand -base64 16)  # Generar una contraseña aleatoria
  sed -i "s#^MINIO_SECRET_KEY=.*#MINIO_SECRET_KEY=$MINIO_SECRET_KEY#" $DESTINATION/.env
fi

# Actualizar las variables ODOO_PORT y ODOO_LONGPOLLING_PORT en el archivo .env
if ! grep -q "^ODOO_PORT=" $DESTINATION/.env; then
  export ODOO_PORT=$(openssl rand -base64 16)  # Generar una contraseña aleatoria
  echo "ODOO_PORT=$PORT" >> $DESTINATION/.env
else
  # Si ya existe, actualizar el valor
  sed -i "s#^ODOO_PORT=.*#ODOO_PORT=$PORT#" $DESTINATION/.env
fi

if ! grep -q "^ODOO_LONGPOLLING_PORT=" $DESTINATION/.env; then
  export ODOO_LONGPOLLING_PORT=$(openssl rand -base64 16)  # Generar una contraseña aleatoria
  echo "ODOO_LONGPOLLING_PORT=$CHAT" >> $DESTINATION/.env
else
  # Si ya existe, actualizar el valor
  sed -i "s#^ODOO_LONGPOLLING_PORT=.*#ODOO_LONGPOLLING_PORT=$CHAT#" $DESTINATION/.env
fi


# Establecer permisos de archivos y directorios después de la instalación
find $DESTINATION -type f -exec chmod 644 {} \;
find $DESTINATION -type d -exec chmod 755 {} \;



# Ejecutar Odoo
docker-compose -f $DESTINATION/docker-compose.yml up -d minio

# Esperar hasta que MinIO esté completamente operativo
echo "Esperando a que MinIO esté disponible..."
while ! curl -s http://localhost:9000/minio/health/live >/dev/null; do
    echo "MinIO aún no está listo. Esperando..."
    sleep 5
done
echo "MinIO está listo."

# Descargar y configurar el cliente mc si no existe
if ! command -v mc &> /dev/null; then
    echo "Descargando MinIO Client (mc)..."
    wget -q https://dl.min.io/client/mc/release/linux-amd64/mc -O /usr/local/bin/mc
    chmod +x /usr/local/bin/mc
fi

# Configurar MinIO Client
mc alias set myminio http://localhost:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD

# Crear bucket si no existe
if ! mc ls myminio | grep -q "odoo-bucket"; then
    echo "Creando bucket 'odoo-bucket'..."
    mc mb myminio/odoo-bucket
    mc anonymous set private myminio/odoo-bucket
fi

# Crear credenciales adicionales si es necesario
if ! mc admin user list myminio | grep -q "odoo-user"; then
    echo "Creando usuario 'odoo-user'..."
    mc admin user add myminio odoo-user $MINIO_SECRET_KEY
    echo "Asignar privilegios usuario 'odoo-user'..."
    mc admin policy attach myminio readwrite --user odoo-user
    echo "Crear access key usuario 'odoo-user'..."
    mc admin accesskey create myminio/ odoo-user --access-key $MINIO_ACCESS_KEY --secret-key $MINIO_SECRET_KEY
fi

# Obtener la dirección IP local
IP_ADDRESS=$(hostname -I | awk '{print $1}')

#mkdir $MINIO_PATH
#chmod -R 777 $MINIO_PATH
#echo "$MINIO_ACCESS_KEY:$MINIO_SECRET_KEY" >> $DESTINATION/.passwd-s3fs
#chmod 600 $DESTINATION/.passwd-s3fs
#apt-get update && apt-get install -y s3fs
#s3fs odoo-bucket $MINIO_PATH -o dbglevel=info -f -o curldbg -o passwd_file=$DESTINATION/.passwd-s3fs -o host=http://$IP_ADDRESS:9000 -o endpoint=us-east-1 -o use_path_request_style -o allow_other &

# Definir la ruta completa del directorio de Minio
#MINIO_DIR="$BASE_DIR/$MINIO_PATH"  # Esto asume que odoo está dentro de la ruta actual

# Crear el archivo de servicio systemd para s3fs
#@cat <<EOF | sudo tee /etc/systemd/system/s3fs-odoo-bucket.service
#[Unit]
#Description=Montar el bucket S3 odoo-bucket usando s3fs
#After=network.target

#[Service]
#ExecStartPre=/bin/sh -c "until docker ps | grep -q 'minio'; do echo 'Esperando a que el contenedor minio esté arriba...'; sleep 5; done"
#ExecStart=/usr/bin/s3fs odoo-bucket $MINIO_DIR -o passwd_file=$BASE_DIR/$DESTINATION/.passwd-s3fs -o host=http://$IP_ADDRESS:9000 -o endpoint=us-east-1 -o use_path_request_style -o allow_other
#Restart=always
#User=$USER
#Group=$GROUP

#[Install]
#WantedBy=multi-user.target
#EOF

# Recargar systemd para reconocer el nuevo servicio
#sudo systemctl daemon-reload

# Habilitar el servicio para que se inicie automáticamente al arrancar el sistema
#sudo systemctl enable s3fs-odoo-bucket.service

# Iniciar el servicio
#sudo systemctl start s3fs-odoo-bucket.service

unzip -x $DESTINATION/odoo/addons/*.zip
rm -r $DESTINATION/odoo/addons/*.zip

# Establecer permisos 777 para los directorios específicos
chmod -R 777 $DESTINATION/odoo/addons $DESTINATION/odoo/etc $DESTINATION/odoo/postgresql
chmod -R 777 $DESTINATION/odoo/build/entrypoint.sh

# Ejecutar Odoo
docker-compose -f $DESTINATION/docker-compose.yml up -d

# Mostrar información de acceso
echo "Todas los datos de acceso como usuarios y contraselas estan dentro en el archivo $BASE_DIR/$DESTINATION/.env"
echo "Odoo iniciado en http://$IP_ADDRESS:$PORT | Contraseña maestra: minhng.info | Puerto de chat en vivo: $CHAT"
echo "El minIOiniciado en http://$IP_ADDRESS:9001 | Usuario por defecto: $MINIO_ROOT_USER, y la contraseña maestra: $MINIO_ROOT_PASSWORD"
#echo "Se creo el servicio /etc/systemd/system/s3fs-odoo-bucket.service para controlar el s3fs"
