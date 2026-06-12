#!/bin/bash

set -e
set -o pipefail
trap 'echo "❌ An error occurred at line $LINENO. Aborting."' ERR

ask_and_update_env_var() {
    local var_name=$1
    local prompt_message=$2

    if grep -Eq "^$var_name=.+" .env 2>/dev/null; then
        echo "⏭️ $var_name already set, skipping"
        return 0
    fi

    read -p "What is the $prompt_message? " value

    if [ -z "$value" ]; then
        echo "❌ You must enter the $prompt_message."
        exit 1
    fi

    if grep -Eq "^[#[:space:]]*$var_name=" .env 2>/dev/null; then
        sed -i "s|^[#[:space:]]*$var_name=.*|$var_name=$value|" .env
    else
        if [ -s .env ] && [ -n "$(tail -c1 .env)" ]; then
            echo >> .env
        fi
        echo "$var_name=$value" >> .env
    fi
}

CONFIG_DIRECTORY="init-config/HermesBundle"

# Install bundle
if [ ! -d "vendor/2lenet/hermes-bundle" ]; then
    docker compose exec symfony composer require 2lenet/hermes-bundle
    echo "✅ HermesBundle installed"

    # Compile assets (only on fresh install)
    docker compose exec symfony bin/console assets:install --symlink
    docker compose exec symfony npm run build
    echo "✅ Assets compiled"
else
    echo "⏭️ HermesBundle already installed, skipping"
fi

# Configure env variables
ask_and_update_env_var "LLE_HERMES_APP_DOMAIN" "Hermes app domain"
ask_and_update_env_var "LLE_HERMES_BOUNCE_HOST" "Hermes bounce host"
ask_and_update_env_var "LLE_HERMES_BOUNCE_PORT" "Hermes bounce port"
ask_and_update_env_var "LLE_HERMES_BOUNCE_USER" "Hermes bounce user"
ask_and_update_env_var "LLE_HERMES_BOUNCE_PASSWORD" "Hermes bounce password"

echo "✅ .env file updated"

# Create cron file
if [ ! -f "cron.d/hermes" ]; then
    mkdir -p ../cron.d
    mv "$CONFIG_DIRECTORY/hermes" cron.d/
    echo "✅ hermes cron created"
else
    echo "⏭️ hermes cron already exists, skipping"
fi

# Configure default locale
if [ "$(yq e '.parameters.default_locale' config/services.yaml)" = "null" ]; then
    yq e -i --indent=4 '.parameters.default_locale = "fr"' config/services.yaml
    echo "✅ services.yaml file updated"
else
    echo "⏭️ services.yaml already configured, skipping"
fi

# Route config
ROUTES_FILE="config/routes.yaml"
if [ "$(yq e '.lle_hermes' "$ROUTES_FILE")" = "null" ]; then
    yq e -i --indent=4 '
.lle_hermes = {
    "resource": "@LleHermesBundle/Resources/config/routes.xml",
    "prefix": "/hermes"
}
' "$ROUTES_FILE"
    echo "✅ routes.yaml file updated"
else
    echo "⏭️ routes.yaml already configured, skipping"
fi

# Create and execute migration
read -p "Do you want to create and execute migration ? (y/n) : " reponse

if [[ "$reponse" == "y" ]]; then
    docker compose exec symfony bin/console make:migration
    docker compose exec symfony bin/console doctrine:migrations:migrate
    echo "✅ Migration generated and executed"
fi

echo "✅ HermesBundle installed and configured"