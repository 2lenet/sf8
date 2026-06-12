#!/bin/bash

set -e
set -o pipefail
trap 'echo "❌ An error occurred at line $LINENO. Aborting."' ERR

ask_and_update_env_var() {
    local var_name=$1
    local prompt_message=$2

    if grep -Eq "^$var_name=.+" .env 2>/dev/null; then
        echo "⏭️ $var_name already set, skipping"
        return 0
    fi

    read -p "What is the $prompt_message? " value

    if [ -z "$value" ]; then
        echo "❌ You must enter the $prompt_message."
        exit 1
    fi

    if grep -Eq "^[#[:space:]]*$var_name=" .env 2>/dev/null; then
        sed -i "s|^[#[:space:]]*$var_name=.*|$var_name=$value|" .env
    else
        if [ -s .env ] && [ -n "$(tail -c1 .env)" ]; then
            echo >> .env
        fi
        echo "$var_name=$value" >> .env
    fi
}

update_env_var() {
    local var_name=$1
    local value=$2

    if grep -Eq "^$var_name=.+" .env 2>/dev/null; then
        echo "⏭️ $var_name already set, skipping"
        return 0
    fi

    if grep -Eq "^[#[:space:]]*$var_name=" .env 2>/dev/null; then
        sed -i "s|^[#[:space:]]*$var_name=.*|$var_name=$value|" .env
    else
        if [ -s .env ] && [ -n "$(tail -c1 .env)" ]; then
            echo >> .env
        fi
        echo "$var_name=$value" >> .env
    fi
}

CONFIG_DIRECTORY="init-config/OAuthClientBundle"

# Install bundle
if [ ! -d "vendor/2lenet/oauth-client-bundle" ]; then
    docker compose exec symfony composer require 2lenet/oauth-client-bundle
    echo "✅ OAuthClientBundle installed"
else
    echo "⏭️ OAuthClientBundle already installed, skipping"
fi

# Create User Entity and Repository files
mkdir -p src/Entity src/Repository

if [ ! -f "src/Entity/User.php" ]; then
    mv "$CONFIG_DIRECTORY/User.php" src/Entity/
    echo "✅ User Entity file created"
else
    echo "⏭️ User Entity already exists, skipping"
fi

if [ ! -f "src/Repository/UserRepository.php" ]; then
    mv "$CONFIG_DIRECTORY/UserRepository.php" src/Repository/
    echo "✅ UserRepository file created"
else
    echo "⏭️ UserRepository already exists, skipping"
fi

# Create User CRUD
mkdir -p src/Controller/Crudit src/Crudit/Config src/Crudit/Datasource/Filterset src/Form/Crudit templates/crudit/user

[ ! -f "src/Controller/Crudit/UserController.php" ] && cp "$CONFIG_DIRECTORY/UserController.php" src/Controller/Crudit/
[ ! -f "src/Crudit/Config/UserCrudConfig.php" ] && cp "$CONFIG_DIRECTORY/UserCrudConfig.php" src/Crudit/Config/
[ ! -f "src/Crudit/Datasource/UserDatasource.php" ] && cp "$CONFIG_DIRECTORY/UserDatasource.php" src/Crudit/Datasource/
[ ! -f "src/Crudit/Datasource/Filterset/UserFilterSet.php" ] && cp "$CONFIG_DIRECTORY/UserFilterSet.php" src/Crudit/Datasource/Filterset/
[ ! -f "src/Form/Crudit/UserType.php" ] && cp "$CONFIG_DIRECTORY/UserType.php" src/Form/Crudit/
[ ! -f "templates/crudit/user/_impersonate.html.twig" ] && cp "$CONFIG_DIRECTORY/_impersonate.html.twig" templates/crudit/user/

echo "✅ CRUD files created"

# Add Crudit config
CRUDIT_FILE="config/packages/lle_crudit.yaml"
if [ ! -f "$CRUDIT_FILE" ]; then
    touch "$CRUDIT_FILE"
    echo "✅ File $CRUDIT_FILE created."
fi

if [ "$(yq e '.lle_crudit' "$CRUDIT_FILE")" = "null" ]; then
    yq e -i --indent=4 '
.lle_crudit = {
    "add_connect_profile_link": true,
    "add_exit_impersonation_button": true
}
' "$CRUDIT_FILE"
    echo "✅ lle_crudit.yaml file updated"
else
    echo "⏭️ lle_crudit.yaml already configured, skipping"
fi

# Security config
SECURITY_FILE="config/packages/security.yaml"
if [ "$(yq e '.security.providers.main.entity' "$SECURITY_FILE")" = "null" ]; then
    yq e -i --indent=4 '
.security.providers.main.entity = {
    "class": "App\\Entity\\User",
    "property": "username"
} |

.security.firewalls.main = {
    "pattern": "^/",
    "provider": "main",
    "form_login": {
        "login_path": "login",
        "check_path": "login_check"
    },
    "logout": {
        "path": "logout",
        "target": "logout_oauth"
    },
    "switch_user": true,
    "custom_authenticators": ["App\\Security\\OAuthAuthenticator"]
} |

.security.access_control = (
    (.access_control // []) + [
        {"path": "^/login$", "roles": "PUBLIC_ACCESS"},
        {"path": "^/logout_oauth$", "roles": "PUBLIC_ACCESS"},
        {"path": "^/", "roles": "ROLE_USER"}
    ]
)
' "$SECURITY_FILE"
    echo "✅ security.yaml file updated"
else
    echo "⏭️ security.yaml already configured, skipping"
fi

# Create OAuthAuthenticator file
mkdir -p src/Security

if [ ! -f "src/Security/OAuthAuthenticator.php" ]; then
    mv "$CONFIG_DIRECTORY/OAuthAuthenticator.php" src/Security/
    echo "✅ OAuthAuthenticator.php file created"
else
    echo "⏭️ OAuthAuthenticator.php already exists, skipping"
fi

# Configure env variables
password=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 20 || true)

ask_and_update_env_var "OAUTH_PUBLIC_URL" "Connect public URL"
ask_and_update_env_var "OAUTH_API_URL" "Connect API URL"
ask_and_update_env_var "OAUTH_CLIENT_ID" "Connect client ID"
ask_and_update_env_var "OAUTH_CLIENT_SECRET" "Connect client secret"
update_env_var "OAUTH_API_USERNAME" "api_admin"
update_env_var "OAUTH_API_PASSWORD" "$password"

echo "✅ .env file updated"

# Create and execute migration
read -p "Do you want to create and execute migration ? (y/n) : " reponse

if [[ "$reponse" == "y" ]]; then
    docker compose exec symfony bin/console make:migration
    docker compose exec symfony bin/console doctrine:migrations:migrate
    echo "✅ Migration generated and executed"
fi

echo "✅ OAuthClientBundle installed and configured"