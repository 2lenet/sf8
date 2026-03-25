#!/bin/bash

CONFIG_DIRECTORY="init-config/EntityFileBundle"

check() {
    if [ $? -eq 0 ]; then
        echo "✅ $1"
    else
        echo "❌ An error has occurred"
        exit 1
    fi
}

# Install bundle
docker compose exec symfony composer require 2lenet/entity-file-bundle

check "EntityFileBundle installed"

# Create config file
mv $CONFIG_DIRECTORY/lle_entity_file.yaml config/packages/

echo "✅ lle_entity_file.yaml created and configured"

# Create and execute migration
read -p "Do you want to create and execute migration ? (y/n) : " reponse

if [[ "$reponse" == "y" ]]; then
    docker compose exec symfony bin/console make:migration
    docker compose exec symfony bin/console doctrine:migrations:migrate

    echo "✅ Migration generated and executed"
fi

echo "✅ EntityFileBundle installed and configured"
