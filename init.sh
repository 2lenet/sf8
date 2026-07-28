#!/bin/bash

CONFIG_DIRECTORY="init-config/init"

project=$(basename "$(pwd)")
project_capitalized="${project^}"
project_uppercase="${project^^}"

check() {
    if [ $? -eq 0 ]; then
        echo "✅ $1"
    else
        echo "❌ An error has occurred"
        exit 1
    fi
}

replace_service_image() {
    local service_name="$1"
    input="docker-compose.yml"
    output="docker-compose.tmp"

    in_service=0
    service_indent=""

    while IFS= read -r line; do
        if [[ "$line" =~ ^([[:space:]]*)${service_name}: ]]; then
            service_indent="${BASH_REMATCH[1]}"
            echo "${service_indent}${service_name}:" >> "$output"
            echo "${service_indent}    image: registry.2le.net/2le/$project:${service_name}" >> "$output"
            in_service=1
            continue
        fi

        if [ $in_service -eq 1 ]; then
            if [[ "$line" =~ ^[[:space:]]+$ ]] || [[ "$line" =~ ^${service_indent}[[:space:]]+ ]]; then
                continue
            else
                in_service=0
            fi
        fi

        echo "$line" >> "$output"

    done < "$input"

    mv "$output" "$input"
}

# yq is required to manage yaml file
if ! command -v yq &> /dev/null; then
    echo "The yq package is required for the script to run correctly."

    read -p "Would you like to install it now? ? (y/n) " answer
    if [[ "$answer" != "y" ]]; then
        echo "yq is required for this script. Exit."
        exit 1
    fi

    echo "Installation of yq..."
    sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq
    sudo chmod +x /usr/bin/yq

    if ! command -v yq &> /dev/null; then
        echo "Error: yq could not be installed."
        exit 1
    fi

    echo "yq has been successfully installed."
fi

# Replace [PROJECT] with the project name (current folder)
sed -i "s|\[PROJECT\]|$project|g" docker-compose.yml
sed -i "s|\[PROJECT\]|$project_capitalized|g" Dockerfile
sed -i "s|\[PROJECT\]|$project|g" Makefile
sed -i "s|\[PROJECT\]|$project|g" sonar-project.properties
sed -i "s|\[PROJECT\]|$project|g" .env
sed -i "s|\[PROJECT\]|$project|g" .env.test
sed -i "s|\[PROJECT\]|$project|g" .gitlab-ci.yml
sed -i "s|\[PROJECT\]|$project|g" db/build.sh
sed -i "s|\[PROJECT\]|$project|g" db/Dockerfile
sed -i "s|\[PROJECT\]|$project|g" db/update_db.sh
sed -i "s|\[PROJECT\]|$project|g" dbtest/build.sh
sed -i "s|\[PROJECT\]|$project|g" dbtest/create_empty_dbtest.sh
sed -i "s|\[PROJECT\]|$project|g" dbtest/Dockerfile

echo "✅ [PROJECT] replaced by $project"

# Replace [IDENTIFIER] with the project ID
read -p "What is the project ID? " project_identifier

if [ -z "$project_identifier" ]; then
    echo "❌ You must enter the project ID."
    exit 1
fi

sed -i "s|\[IDENTIFIER\]|$project_identifier|g" Makefile
sed -i "s|\[IDENTIFIER\]|$project_identifier|g" docker-compose.yml

echo "✅ [IDENTIFIER] replaced by $project_identifier"

# Setting up Git
git init

echo "✅ Git initialized"

# Project installation
make install

check "Project installed"

# Start the project
make start

check "Project started"

# Create and execute migration
docker compose exec symfony bin/console make:migration

check "Migration created"

docker compose exec symfony bin/console doctrine:migrations:migrate

check "Migration executed"

yq e -i '.parameters.locales = ["fr"]' config/services.yaml

# Configure Crudit Studio (rights matrix + centralized translations, see
# install-scripts/CruditStudio.sh — it can be re-run later from ./install.sh to rotate the token)
bash install-scripts/CruditStudio.sh

check "Crudit Studio configured"

# Configure Translation (provider set up by CruditStudio.sh above)
mv $CONFIG_DIRECTORY/translation.yaml config/packages/translation.yaml

echo "✅ Translation configured"

# Create Group CRUD
mkdir -p src/Controller/Crudit src/Crudit/Config src/Crudit/Datasource src/Form/Crudit
cp $CONFIG_DIRECTORY/GroupController.php src/Controller/Crudit/
cp $CONFIG_DIRECTORY/GroupCrudConfig.php src/Crudit/Config/
cp $CONFIG_DIRECTORY/GroupDatasource.php src/Crudit/Datasource/
cp $CONFIG_DIRECTORY/GroupType.php src/Form/Crudit/

# Create CredentialWarmup
mkdir -p src/Warmup
mv $CONFIG_DIRECTORY/CredentialWarmup.php src/Warmup/CredentialWarmup.php

# Generate roles
docker compose exec symfony bin/console lle:credential:warmup

check "Roles generated"

# One-time bootstrap: push the warmed-up roles/groups to crudit-studio
docker compose exec symfony bin/console lle:credential:init-project

check "Project initialized on Crudit Studio"

# Build the db image from the freshly migrated schema (dev seed data)
cd db
./update_db.sh
cd ..

check "Db built"

# Build the dbtest image, always from an empty schema (migrations run fresh in tests)
cd dbtest
./create_empty_dbtest.sh
cd ..

check "Dbtest built"

# Replace the db and dbtest services in docker-compose.yml with the freshly built images
replace_service_image "db"
replace_service_image "dbtest"

check "Services db and dbtest updated in docker-compose.yml"

# Configure PHPStan
mv $CONFIG_DIRECTORY/phpstan.dist.neon phpstan.dist.neon

# Configure Monolog
mv $CONFIG_DIRECTORY/monolog.yaml config/packages/monolog.yaml
sed -i "s|\[PROJECT\]|$project_uppercase|g" config/packages/monolog.yaml

url=smtp://smtp:1025
if grep -Eq "^[#[:space:]]*MAILER_DSN=" .env; then
  sed -i "s|^[#[:space:]]*MAILER_DSN=.*|MAILER_DSN=${url}|" .env
else
  [ -s .env ] && [ -n "$(tail -c1 .env)" ] && echo >> .env
  echo "MAILER_DSN=${url}" >> .env
fi

echo "✅ Monolog configured"

# Configure Sentry
mv $CONFIG_DIRECTORY/sentry.yaml config/packages/sentry.yaml
read -p "What is the sentry DSN? " sentry_dsn

if [ -z "$sentry_dsn" ]; then
    echo "❌ You must enter the sentry DSN."
    exit 1
fi

if grep -Eq "^[#[:space:]]*SENTRY_DSN=" .env; then
  sed -i "s|^[#[:space:]]*SENTRY_DSN=.*|SENTRY_DSN=${sentry_dsn}|" .env
else
  [ -s .env ] && [ -n "$(tail -c1 .env)" ] && echo >> .env
  echo "SENTRY_DSN=${sentry_dsn}" >> .env
fi

echo "✅ Sentry configured"

# Add AutoAddMissingTranslations listener
read -p "Do you want to add AutoAddMissingTranslations listener ? (y/n) : " reponse

if [[ "$reponse" == "y" ]]; then
    mkdir -p src/EventListener
    mv $CONFIG_DIRECTORY/AutoAddMissingTranslations.php src/EventListener/

    yq e -i '.services._defaults.bind."$cruditTranslationDsn" = "%env(CRUDIT_TRANSLATION_DSN)%"' config/services.yaml

    echo "✅ AutoAddMissingTranslations listener added"
else
    rm $CONFIG_DIRECTORY/AutoAddMissingTranslations.php
fi

# Restart project to update dbtest container
make start

check "Project restarted"
