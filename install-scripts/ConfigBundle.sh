#!/bin/bash

set -e
set -o pipefail
trap 'echo "❌ An error occurred at line $LINENO. Aborting."' ERR

CONFIG_DIRECTORY="init-config/ConfigBundle"

# Install bundle
if [ ! -d "vendor/2lenet/config-bundle" ]; then
    docker compose exec symfony composer require 2lenet/config-bundle
    echo "✅ ConfigBundle installed"
else
    echo "⏭️ ConfigBundle already installed, skipping"
fi

# Create Config Entity and Repository files
mkdir -p src/Entity src/Repository

if [ ! -f "src/Entity/Config.php" ]; then
    mv "$CONFIG_DIRECTORY/Config.php" src/Entity/
    echo "✅ Config Entity file created"
else
    echo "⏭️ Config Entity already exists, skipping"
fi

if [ ! -f "src/Repository/ConfigRepository.php" ]; then
    mv "$CONFIG_DIRECTORY/ConfigRepository.php" src/Repository/
    echo "✅ ConfigRepository file created"
else
    echo "⏭️ ConfigRepository already exists, skipping"
fi

# Doctrine config
DOCTRINE_FILE="config/packages/doctrine.yaml"
if [ "$(yq e '.doctrine.orm.resolve_target_entities' "$DOCTRINE_FILE")" = "null" ]; then
    yq e -i --indent=4 '.doctrine.orm.resolve_target_entities = {"Lle\\ConfigBundle\\Contracts\\ConfigInterface": "App\\Entity\\Config"}' "$DOCTRINE_FILE"
    echo "✅ doctrine.yaml file updated"
else
    echo "⏭️ doctrine.yaml already configured, skipping"
fi

# Route config
ROUTES_FILE="config/routes.yaml"
if [ "$(yq e '.lle_config' "$ROUTES_FILE")" = "null" ]; then
    yq e -i --indent=4 '.lle_config = {"resource": "@LleConfigBundle/Resources/config/routes.yaml"}' "$ROUTES_FILE"
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

echo "✅ ConfigBundle installed and configured"