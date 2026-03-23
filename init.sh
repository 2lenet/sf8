#!/bin/bash

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

replace_dbtest_service() {
    input="docker-compose.yml"
    output="docker-compose.tmp"

    in_dbtest=0
    dbtest_indent=""

    while IFS= read -r line; do
        if [[ "$line" =~ ^([[:space:]]*)dbtest: ]]; then
            dbtest_indent="${BASH_REMATCH[1]}"
            echo "${dbtest_indent}dbtest:" >> "$output"
            echo "${dbtest_indent}    image: registry.2le.net/2le/$project:dbtest" >> "$output"
            in_dbtest=1
            continue
        fi

        if [ $in_dbtest -eq 1 ]; then
            if [[ "$line" =~ ^[[:space:]]+$ ]] || [[ "$line" =~ ^${dbtest_indent}[[:space:]]+ ]]; then
                continue
            else
                in_dbtest=0
            fi
        fi

        echo "$line" >> "$output"

    done < "$input"

    mv "$output" "$input"
}

add_or_replace_env_variable() {
    local key="$1"
    local value="$2"

    if grep -Eq "^[#[:space:]]*$key=" .env; then
      sed -i "s|^[#[:space:]]*$key=.*|$key=$value|" .env
    else
      [ -s .env ] && [ -n "$(tail -c1 .env)" ] && echo >> .env
      echo "$key=$value" >> .env
    fi
}

# Replace [PROJECT] with the project name (current folder)
sed -i "s|\[PROJECT\]|$project|g" docker-compose.yml
sed -i "s|\[PROJECT\]|$project_capitalized|g" Dockerfile
sed -i "s|\[PROJECT\]|$project|g" Makefile
sed -i "s|\[PROJECT\]|$project|g" sonar-project.properties
sed -i "s|\[PROJECT\]|$project|g" .env
sed -i "s|\[PROJECT\]|$project|g" .gitlab-ci.yml
sed -i "s|\[PROJECT\]|$project|g" dbtest/build.sh
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

# Export current database to create new dbtest
docker compose exec dbtest mariadb-dump -uroot -ppass $project > dbtest/db.sql

check "Database exported"

rm dbtest/db.sql.gz
gzip dbtest/db.sql
chmod +x dbtest/build.sh
cd dbtest; ./build.sh
cd ..

check "Dbtest builded"

# Replace current dbtest service in docker-compose.yml
replace_dbtest_service

check "Service dbtest updated in docker-compose.yml"

# Configure Monolog
cp init-config/monolog.yaml config/packages/monolog.yaml
sed -i "s|\[PROJECT\]|$project_uppercase|g" config/packages/monolog.yaml

url=smtp://smtp:1025
add_or_replace_env_variable MAILER_DSN "$url"

sed -i "/^parameters:/a\    locales: ['fr']" config/services.yaml

rm init-config/monolog.yaml

echo "✅ Monolog configured"

# Add AutoAddMissingTranslations listener
read -p "Do you want to add AutoAddMissingTranslations listener ? (y/n) : " reponse

if [[ "$reponse" == "y" ]]; then
    mkdir -p src/EventListener
    mv init-config/AutoAddMissingTranslations.php src/EventListener/

    sed -i '/autoconfigure: true/ a\        bind:\n            $locoDsn: '\''%env(LOCO_DSN)%'\'' ' config/services.yaml

    echo "✅ AutoAddMissingTranslations listener added"
else
    rm init-config/AutoAddMissingTranslations.php
fi

# Configure Sentry
cp init-config/sentry.yaml config/packages/sentry.yaml
read -p "What is the sentry DSN? " sentry_dsn

if [ -z "$sentry_dsn" ]; then
    echo "❌ You must enter the sentry DSN."
    exit 1
fi

add_or_replace_env_variable SENTRY_DSN "$sentry_dsn"

rm init-config/sentry.yaml

echo "✅ Sentry configured"

# Configure Translation (using loco)
cp init-config/translation.yaml config/packages/translation.yaml
read -p "What is the loco DSN? " loco_dsn

if [ -z "$loco_dsn" ]; then
    echo "❌ You must enter the loco DSN."
    exit 1
fi

add_or_replace_env_variable LOCO_DSN "$loco_dsn"

rm init-config/translation.yaml

echo "✅ Loco configured"

# Restart project to update dbtest container
make start

check "Project restarted"
