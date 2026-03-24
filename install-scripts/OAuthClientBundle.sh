#!/bin/bash

ask_and_update_env_var() {
    local var_name=$1
    local prompt_message=$2

    read -p "What is the $prompt_message? " value

    if [ -z "$value" ]; then
        echo "❌ You must enter the $prompt_message."
        exit 1
    fi

    if grep -Eq "^[#[:space:]]*$var_name=" .env; then
        sed -i "s|^[#[:space:]]*$var_name=.*|$var_name=$value|" .env
    else
        [ -s .env ] && [ -n "$(tail -c1 .env)" ] && echo >> .env
        echo "$var_name=$value" >> .env
    fi
}

update_env_var() {
    local var_name=$1
    local value=$2

    if grep -Eq "^[#[:space:]]*$var_name=" .env; then
        sed -i "s|^[#[:space:]]*$var_name=.*|$var_name=$value|" .env
    else
        [ -s .env ] && [ -n "$(tail -c1 .env)" ] && echo >> .env
        echo "$var_name=$value" >> .env
    fi
}

# Install bundle
docker compose exec symfony composer require 2lenet/oauth-client-bundle

echo "✅ OAuthClientBundle installed"

# Create User Entity
docker compose exec symfony bin/console make:user

# Security config
SECURITY_FILE="config/packages/security.yaml"
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

# Configure env variables
password=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 20)

ask_and_update_env_var "OAUTH_PUBLIC_URL" "Connect public URL"
ask_and_update_env_var "OAUTH_API_URL" "Connect API URL"
ask_and_update_env_var "OAUTH_CLIENT_ID" "Connect client ID"
ask_and_update_env_var "OAUTH_CLIENT_SECRET" "Connect client secret"
update_env_var "OAUTHAPI_USERNAME" "api_admin"
update_env_var "OAUTHAPI_PASSWORD" "$password"

echo "✅ .env file updated"

# Create and execute migration
read -p "Do you want to create and execute migration ? (y/n) : " reponse

if [[ "$reponse" == "y" ]]; then
    docker compose exec symfony bin/console make:migration
    docker compose exec symfony bin/console doctrine:migrations:migrate

    echo "✅ Migration generated and executed"
fi

echo "✅ OAuthClientBundle installed and configured"
