#!/bin/bash

project=$(basename "$(pwd)")
project_capitalized="${project^}"
#project_upper="${project^^}"

check() {
    if [ $? -eq 0 ]; then
        echo "✅ $1"
    else
        echo "❌ An error has occurred"
        exit 1
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

# Building a dbtest
chmod +x dbtest/build.sh
./dbtest/build.sh

check "Dbtest initialised"

# Setting up Git
git init

echo "✅ Git initialised"

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
./dbtest/build.sh

check "Dbtest builded"

# Replace dbtest image in gitlab-ci.yml
awk '
/^[[:space:]]*dbtest:/ {
    print
    in_dbtest=1
    next
}

in_dbtest && /^[[:space:]]*#image:/ {
    sub(/#/, "")
    print
    in_dbtest=0
    skip=1
    next
}

skip && /^[[:space:]]+[a-zA-Z0-9_-]+:/ {
    skip=0
}

!skip {
    print
}
' gitlab-ci.yml

check "Service dbtest updated in gitlab-ci.yml"

# Restart project to update dbtest
make start

check "Project restarted"
