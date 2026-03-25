#!/bin/bash

check() {
    if [ $? -eq 0 ]; then
        echo "✅ $1"
    else
        echo "❌ An error has occurred"
        exit 1
    fi
}

docker compose exec dbtest mariadb -uroot -ppass -e "DROP DATABASE IF EXISTS [PROJECT]"
docker compose exec dbtest mariadb -uroot -ppass -e "CREATE DATABASE [PROJECT]"
docker compose exec dbtest mariadb-dump -uroot -ppass [PROJECT] > db.sql

check "Database exported"

rm db.sql.gz
gzip db.sql
chmod +x build.sh
./build.sh

check "Dbtest built"
