FROM registry.2le.net/2le/2le:base-sf8

# --- Composer deps: cached until composer.lock changes ---
COPY composer.json composer.lock /app/
RUN COMPOSER_MEMORY_LIMIT=-1 composer install --no-scripts --no-autoloader

# --- NPM deps: cached until package-lock.json changes ---
COPY package.json package-lock.json /app/
RUN cd /app/ && npm ci

# --- NPM build: cached until assets/, webpack.config.js or package-lock.json change ---
COPY assets/ /app/assets/
COPY webpack.config.js /app/
RUN cd /app \
    && npm run build

# --- Full source copy (vendor/ et node_modules/ exclus via .dockerignore) ---
COPY ./docker/php/php.ini /usr/local/etc/php/
COPY . /app/

WORKDIR /app

ENV APP_NAME="[PROJECT]"
ARG app_version=dev
ENV APP_VERSION=$app_version

# --- Post-copy: finalize composer + Symfony setup ---
RUN COMPOSER_MEMORY_LIMIT=-1 COMPOSER_ALLOW_SUPERUSER=1 composer install \
    && bin/console ckeditor:install --tag=4.6.0 --clear=drop \
    && bin/console assets:install --symlink

VOLUME ["/app/var/cache"]

EXPOSE 80
