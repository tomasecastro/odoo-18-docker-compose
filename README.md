* Esta implementación esta basada en la realizada por https://github.com/minhng92/odoo-18-docker-compose. 
* Cambios realizados, actualizacion de la version del docker utilizado.
* Cambios en el run.sh para mis ajustes personales.
* Cambio en la forma de organizar el despliegue de los dockerfile.
* Implementacion de [MinIO](https://min.io/?), para mejorar el control de las imagenes y la portabilidad de la implementacion entre servidores.
* Se hace el cambio para postgres 15 porque es lo recomendado en la documentacion de odoo.
* Se creo el archivo de variables de entorno para mejorar la organización y seguriodad de los Docker.
* Se incluye el addons de auto backup, incluyendo la modificacion en el entrypoint.sh, para incluyir durante la instalación las dependencias de python del modulo (el modulo debe ser instalado y configurado manualmente despues de completarse la instalacion).
<<<<<<< HEAD

=======
>>>>>>> 41ff2a7e81fa03c90854811914b34951db2983f9

---
# Instalación de Odoo 17.0 con un solo comando (Admite múltiples instancias de Odoo en un solo servidor).

## Instalación rápida

Instale [docker](https://docs.docker.com/get-docker/) y [docker-compose](https://docs.docker.com/compose/install/) por su cuenta, luego ejecute lo siguiente para configurar la primera instancia de Odoo en `localhost:10017` (contraseña maestra predeterminada: **`minhng.info`**):
- Si desea iniciar el servidor con un puerto diferente, cambie **10017** por otro valor en **docker-compose.yml** dentro del directorio principal, el puerto por defecto del odoo es el 8069, para esta implementacion se utiliza el puerto 10017, para ser expuesto por el docker, si lo desea puede cambiarlo en la siguiente linea.
- Recuerde que puede modificar el docker-compose.yml para ajustar las configuraciones de sus docker una vez instalado.

``` bash
curl -s https://raw.githubusercontent.com/tomasecastro/odoo-18-docker-compose/master/run.sh | sudo bash -s odoo-one 10017 20017
```
y/o ejecute lo siguiente para configurar otra instancia de Odoo en `localhost:11017` (contraseña maestra predeterminada: `minhng.info`):

``` bash
curl -s https://raw.githubusercontent.com/tomasecastro/odoo-18-docker-compose/master/run.sh | sudo bash -s odoo-two 11017 21017
```

Algunos argumentos:
* Primer argumento (**odoo-one**): Carpeta de despliegue de Odoo
* Segundo argumento (**10017**): Puerto de Odoo
* Tercer argumento (**20017**): Puerto del chat en vivo

Si `curl` no se encuentra, instálelo:

``` bash
$ sudo apt-get install curl
# o
$ sudo yum install curl
```

## Uso

Iniciar el contenedor:
``` sh
docker-compose up
```
Luego abra `localhost:10017` o `IP_EQUIPO_DONDE_EJECUTA_EL_DOCKER:10017` para acceder a Odoo 17.

- **Si tiene problemas de permisos**, cambie los permisos de la carpeta para asegurarse de que el contenedor pueda acceder al directorio, en el equipo que ejecuta los docker:

``` sh
$ sudo chmod -R 775 addons
$ sudo chmod -R 775 etc
$ sudo chmod -R 775 postgresql
```

- Si desea iniciar el servidor con un puerto diferente, cambie **10017** por otro valor en **docker-compose.yml** dentro del directorio principal, el puerto por defecto del odoo es el 8069, si desea realizar cambios en el puerto:

```
ports:
 - "10017:8069"
```

- Para ejecutar el contenedor de Odoo en modo separado (para poder cerrar la terminal sin detener Odoo):

```
docker-compose up -d
```

- Para usar una política de reinicio, es decir, configurar la política de reinicio de un contenedor, cambie el valor relacionado con la clave **restart** en el archivo **docker-compose.yml** a una de las siguientes opciones:
   - `no` = No reiniciar automáticamente el contenedor. (valor predeterminado)
   - `on-failure[:max-retries]` = Reiniciar el contenedor si se detiene debido a un error, lo que se manifiesta como un código de salida distinto de cero. Opcionalmente, limite el número de intentos de reinicio con la opción `:max-retries`.
   - `always` = Siempre reiniciar el contenedor si se detiene. Si se detiene manualmente, solo se reiniciará cuando se reinicie el daemon de Docker o se reinicie manualmente el contenedor. (Consulte el segundo punto en los detalles de la política de reinicio).
   - `unless-stopped` = Similar a `always`, excepto que cuando el contenedor se detiene (manualmente o de otra manera), no se reinicia incluso después de que se reinicie el daemon de Docker.

```
 restart: always             # ejecutar como un servicio
```

- Para aumentar el número máximo de archivos en observación de **8192** (predeterminado) a **524288**, con el fin de evitar errores al ejecutar múltiples instancias de Odoo. Este paso es *opcional*. Estos comandos son para usuarios de Ubuntu:

```
$ if grep -qF "fs.inotify.max_user_watches" /etc/sysctl.conf; then echo $(grep -F "fs.inotify.max_user_watches" /etc/sysctl.conf); else echo "fs.inotify.max_user_watches = 524288" | sudo tee -a /etc/sysctl.conf; fi
$ sudo sysctl -p    # aplicar nueva configuración inmediatamente
``` 

## Complementos personalizados

La carpeta **addons/** contiene complementos personalizados. Simplemente coloque sus complementos personalizados si tiene alguno.

## Configuración y registro de Odoo

* Para cambiar la configuración de Odoo, edite el archivo: **odoo/etc/odoo.conf**.
* Archivo de registro: **odoo/etc/odoo-server.log**
* La contraseña de la base de datos por defecto (**admin_passwd**) es `minhng.info`, cámbiela en [odoo/etc/odoo.conf#L60](/odoo/etc/odoo.conf#L60).

## Administración del contenedor de Odoo

**Ejecutar Odoo**:

``` bash
docker-compose up -d
```

**Reiniciar Odoo**:

``` bash
docker-compose restart
```

**Detener Odoo**:

``` bash
docker-compose down
```

## Chat en vivo

En [docker-compose.yml#L21](docker-compose.yml#L21), se expuso el puerto **20017** para el chat en vivo en el host.

Configuración de **nginx** para activar la función de chat en vivo (en producción):

``` conf
#...
server {
    #...
    location /longpolling/ {
        proxy_pass http://0.0.0.0:20017/longpolling/;
    }
    #...
}
#...
```

## Configuracion inicial del odoo.
Cuando completada la instalacion y ejecucion del odoo, se solicita que indique la siguiente informacion para completar la instalacion y configuacion.
Se nos pide que completemos el proceso de configucion en la siguiente pantalla.
Agregando el Master Password
El nombre que deseamos para nuestra base de datos. Es recomendable que el nombre sea relacionado con la empresa y colocar la Fecha para futuros controles. ej empresa_2025
en email. realmente se refiere al usuario que usaras como admin, como el servidor de correo no esta configurado se recomienda usar un nombre de usuario, mas generico que admin.
Asignar una contraseña a este usuario.
El idioma en que inicialmente se instalar el Odoo, recomiendo en Ingles y posteriormente, lo cambies si es necesario.
El pais donde se utilizara.

Y si lo quieres para probar o demo activar el check de datos de Demo. En caso contrario dejarlo sin marcar.
Y ejecutamos crear una nueva base de datos. 

Nota. Esta guia no cubre el escenario donde se tenga bases de datos respaldadas previamente.

<img src="screenshots/odoo-17-welcome-screenshot.png" width="50%">

## Para remover el servicio cliente de MinIO del Host

* sudo umount -l RUTA_PATH_DOCKER/odoo/odoo-data
* sudo systemctl stop s3fs-odoo-bucket
* sudo systemctl disable s3fs-odoo-bucket
* sudo rm /etc/systemd/system/s3fs-odoo-bucket.service
* sudo systemctl daemon-reload
* sudo apt remove --purge s3fs

## Herramientas o addons adicionales

Para mejorar la funcionalida implementamos el addons:
  
https://apps.odoo.com/apps/modules/17.0/auto_database_backup, y su explicación esta en este video https://www.youtube.com/watch?v=Q2yMZyYjuTI  
Lo importante es que despues de instalarlo. hay que ir a Shcedule action y en auto_database_backup, activar la opción para que se ejecute.  
Tambien hay que tener una carpeta que pueda ser accesible desde el host, para poder extraer los backup a un sitio seguro si usamos la opción de backup local.  

## docker-compose.yml

* odoo:17
* postgres:15

## Capturas de pantalla de Odoo 17.0 después de una instalación exitosa.

<img src="screenshots/odoo-17-welcome-screenshot.png" width="50%">

<img src="screenshots/odoo-17-apps-screenshot.png" width="100%">

<img src="screenshots/odoo-17-sales-screen.png" width="100%">

<img src="screenshots/odoo-17-product-form.png" width="100%">


