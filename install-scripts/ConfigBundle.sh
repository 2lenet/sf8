#!/bin/bash

CONFIG_DIRECTORY="init-config/ConfigBundle"

check() {
    if [ $? -eq 0 ]; then
        echo "✅ $1"
    else
        echo "❌ An error has occurred"
        exit 1
    fi
}

# Install bundle
docker compose exec symfony composer require 2lenet/config-bundle

check "ConfigBundle installed"

# Create Config Entity and Repository files
mkdir -p src/Entity src/Repository
mv $CONFIG_DIRECTORY/Config.php src/Entity/
mv $CONFIG_DIRECTORY/ConfigRepository.php src/Repository/

echo "✅ Config Entity and Repository files created"

# Doctrine config
DOCTRINE_FILE="config/packages/doctrine.yaml"
yq e -i --indent=4 '.doctrine.orm.resolve_target_entities = {"Lle\\ConfigBundle\\Contracts\\ConfigInterface": "App\\Entity\\Config"}' "$DOCTRINE_FILE"

echo "✅ doctrine.yaml file updated"

# Route config
ROUTES_FILE="config/routes.yaml"
yq e -i --indent=4 '.lle_config = {"resource": "@LleConfigBundle/Resources/config/routes.yaml"}' "$ROUTES_FILE"

echo "✅ routes.yaml file updated"

# Create and execute migration
read -p "Do you want to create and execute migration ? (y/n) : " reponse

if [[ "$reponse" == "y" ]]; then
    docker compose exec symfony bin/console make:migration
    docker compose exec symfony bin/console doctrine:migrations:migrate

    echo "✅ Migration generated and executed"
fi

echo "✅ ConfigBundle installed and configured"
