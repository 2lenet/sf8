#!/bin/bash

project=$(basename "$(pwd)")
project_capitalized="${project^}"

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

# Replace [PROJECT] with the project name (current folder)
#sed -i "s|\[PROJECT\]|$project|g" docker-compose.yml
#sed -i "s|\[PROJECT\]|$project_capitalized|g" Dockerfile
#sed -i "s|\[PROJECT\]|$project|g" Makefile
#sed -i "s|\[PROJECT\]|$project|g" sonar-project.properties
#sed -i "s|\[PROJECT\]|$project|g" .env
#sed -i "s|\[PROJECT\]|$project|g" .gitlab-ci.yml
#sed -i "s|\[PROJECT\]|$project|g" dbtest/build.sh
#sed -i "s|\[PROJECT\]|$project|g" dbtest/Dockerfile
#
#echo "✅ [PROJECT] replaced by $project"
#
## Replace [IDENTIFIER] with the project ID
#read -p "What is the project ID? " project_identifier
#
#if [ -z "$project_identifier" ]; then
#    echo "❌ You must enter the project ID."
#    exit 1
#fi
#
#sed -i "s|\[IDENTIFIER\]|$project_identifier|g" Makefile
#sed -i "s|\[IDENTIFIER\]|$project_identifier|g" docker-compose.yml
#
#echo "✅ [IDENTIFIER] replaced by $project_identifier"
#
## Setting up Git
#git init
#
#echo "✅ Git initialised"
#
## Project installation
#make install
#
#check "Project installed"

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

# Restart project to update dbtest container
make start

check "Project restarted"
