#!/bin/bash

check() {
    if [ $? -eq 0 ]; then
        echo "✅ $1"
    else
        echo "❌ An error has occurred"
        exit 1
    fi
}

docker compose exec db mariadb-dump -uroot -ppass [PROJECT] > db.sql

check "Database exported"

rm db.sql.gz
gzip db.sql
chmod +x build.sh
./build.sh

check "Db built"
