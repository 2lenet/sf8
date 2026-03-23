#!/bin/bash

project=$(basename "$(pwd)")
project_capitalized="${project^}"
#project_upper="${project^^}"

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

if [ $? -eq 0 ]; then
    echo "✅ Dbtest initialised"
else
    echo "❌ An error has occurred"
    exit 1
fi

# Setting up Git
git init

echo "✅ Git initialised"

# Project installation
make install

if [ $? -eq 0 ]; then
    echo "✅ Project installed"
else
    echo "❌ An error has occurred"
    exit 1
fi
