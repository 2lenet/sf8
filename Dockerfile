FROM registry.2le.net/2le/2le:base-sf8

COPY ./docker/php/php.ini /usr/local/etc/php/conf.d/app.ini
COPY . /app/

WORKDIR /app

ENV APP_NAME="[PROJECT]"
ARG app_version=dev
ENV APP_VERSION=$app_version

RUN COMPOSER_MEMORY_LIMIT=-1 COMPOSER_ALLOW_SUPERUSER=1 composer install  --no-scripts
RUN bin/console assets:install --symlink
RUN npm install
RUN npm run build

VOLUME ["/app/var/cache"]

EXPOSE 80
