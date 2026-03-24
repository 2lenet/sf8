#!/bin/bash

db_name=$(grep '^DATABASE_URL=' ../.env \
  | cut -d '=' -f2- \
  | tr -d '"' \
  | sed -E 's|^.*/([^/?]+).*|\1|')

check() {
    if [ $? -eq 0 ]; then
        echo "✅ $1"
    else
        echo "❌ An error has occurred"
        exit 1
    fi
}

docker compose exec dbtest mariadb-dump -uroot -ppass $db_name > db.sql

check "Database exported"

rm db.sql.gz
gzip db.sql
chmod +x build.sh
./build.sh

check "Dbtest builded"
