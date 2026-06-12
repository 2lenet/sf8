#!/bin/bash

set -e
set -o pipefail
trap 'echo "❌ An error occurred at line $LINENO. Aborting."' ERR

CONFIG_DIRECTORY="init-config/EntityFileBundle"

# Install bundle
if [ ! -d "vendor/2lenet/entity-file-bundle" ]; then
    docker compose exec symfony composer require 2lenet/entity-file-bundle
    echo "✅ EntityFileBundle installed"
else
    echo "⏭️ EntityFileBundle already installed, skipping"
fi

# Create config file
if [ ! -f "config/packages/lle_entity_file.yaml" ]; then
    mv "$CONFIG_DIRECTORY/lle_entity_file.yaml" config/packages/
    echo "✅ lle_entity_file.yaml created and configured"
else
    echo "⏭️ lle_entity_file.yaml already exists, skipping"
fi

# Create and execute migration
read -p "Do you want to create and execute migration ? (y/n) : " reponse

if [[ "$reponse" == "y" ]]; then
    docker compose exec symfony bin/console make:migration
    docker compose exec symfony bin/console doctrine:migrations:migrate
    echo "✅ Migration generated and executed"
fi

echo "✅ EntityFileBundle installed and configured"