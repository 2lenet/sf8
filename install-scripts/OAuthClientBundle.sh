#!/bin/bash

CONFIG_DIRECTORY="init-config/OAuthClientBundle"

check() {
    if [ $? -eq 0 ]; then
        echo "✅ $1"
    else
        echo "❌ An error has occurred"
        exit 1
    fi
}

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

check "OAuthClientBundle installed"

# Create User Entity and Repository files
mkdir -p src/Entity src/Repository
mv $CONFIG_DIRECTORY/User.php src/Entity/
mv $CONFIG_DIRECTORY/UserRepository.php src/Repository/

echo "✅ User Entity and Repository files created"

# Create User CRUD
mkdir -p src/Controller/Crudit src/Crudit/Config src/Crudit/Datasource/Filterset src/Form/Crudit templates/crudit/user
cp $CONFIG_DIRECTORY/UserController.php src/Controller/Crudit/
cp $CONFIG_DIRECTORY/UserCrudConfig.php src/Crudit/Config/
cp $CONFIG_DIRECTORY/UserDatasource.php src/Crudit/Datasource/
cp $CONFIG_DIRECTORY/UserFilterSet.php src/Crudit/Datasource/Filterset/
cp $CONFIG_DIRECTORY/UserType.php src/Form/Crudit/
cp $CONFIG_DIRECTORY/_impersonate.html.twig templates/crudit/user/

echo "✅ CRUD files created"

# Add Crudit config
CRUDIT_FILE="config/packages/lle_crudit.yaml"
if [ ! -f "$CRUDIT_FILE" ]; then
    touch "$CRUDIT_FILE"
    echo "✅ File $CRUDIT_FILE created."
fi

yq e -i --indent=4 '
.lle_crudit = {
    "add_connect_profile_link": true,
    "add_exit_impersonation_button": true
}
' "$CRUDIT_FILE"

echo "✅ lle_crudit.yaml file updated"

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

# Create OAuthAuthenticator file
mkdir -p src/Security
mv $CONFIG_DIRECTORY/OAuthAuthenticator.php src/Security/

echo "✅ OAuthAuthenticator.php file created"

# Configure env variables
password=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 20)

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
