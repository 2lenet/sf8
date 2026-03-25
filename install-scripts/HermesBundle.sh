#!/bin/bash

check() {
    if [ $? -eq 0 ]; then
        echo "✅ $1"
    else
        echo "❌ An error has occurred"
        exit 1
    fi
}

ask_and_update_env_var() {
    local var_name=$1
    local prompt_message=$2

    read -p "What is the $prompt_message? " value

    if [ -z "$value" ]; then
        echo "❌ You must enter the $prompt_message."
        exit 1
    fi

    if grep -Eq "^[#[:space:]]*$var_name=" .env; then
        sed -i "s|^[#[:space:]]*$var_name=.*|$var_name=$value|" .env
    else
        [ -s .env ] && [ -n "$(tail -c1 .env)" ] && echo >> .env
        echo "$var_name=$value" >> .env
    fi
}

CONFIG_DIRECTORY="init-config/HermesBundle"

# Install bundle
docker compose exec symfony composer require 2lenet/hermes-bundle

check "HermesBundle installed"

# Compile assets
docker compose exec symfony bin/console assets:install --symlink
docker compose exec symfony npm run build

echo "✅ Assets compiled"

# Configure env variables
ask_and_update_env_var "LLE_HERMES_APP_DOMAIN" "Hermes app domain"
ask_and_update_env_var "LLE_HERMES_BOUNCE_HOST" "Hermes bounce host"
ask_and_update_env_var "LLE_HERMES_BOUNCE_PORT" "Hermes bounce port"
ask_and_update_env_var "LLE_HERMES_BOUNCE_USER" "Hermes bounce user"
ask_and_update_env_var "LLE_HERMES_BOUNCE_PASSWORD" "Hermes bounce password"

echo "✅ .env file updated"

# Create cron file
mkdir ../cron.d
mv $CONFIG_DIRECTORY/hermes cron.d/

echo "✅ hermes cron created"

# Configure default locale
yq e -i --indent=4 '.parameters.default_locale = "fr"' config/services.yaml

echo "✅ services.yaml file updated"

# Route config
ROUTES_FILE="config/routes.yaml"
yq e -i --indent=4 '
.lle_hermes = {
    "resource": "@LleHermesBundle/Resources/config/routes.xml",
    "prefix": "/hermes"
}
' "$ROUTES_FILE"

echo "✅ routes.yaml file updated"

# Create and execute migration
read -p "Do you want to create and execute migration ? (y/n) : " reponse

if [[ "$reponse" == "y" ]]; then
    docker compose exec symfony bin/console make:migration
    docker compose exec symfony bin/console doctrine:migrations:migrate

    echo "✅ Migration generated and executed"
fi

echo "✅ HermesBundle installed and configured"
