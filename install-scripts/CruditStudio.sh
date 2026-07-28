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

# Credential config (rights matrix, managed via crudit-studio)
CREDENTIAL_FILE="config/packages/lle_credential.yaml"
if [ ! -f "$CREDENTIAL_FILE" ]; then
    touch "$CREDENTIAL_FILE"
    echo "✅ File $CREDENTIAL_FILE created."
fi

if [ "$(yq e '.lle_credential' "$CREDENTIAL_FILE")" = "null" ]; then
    yq e -i --indent=4 '
.lle_credential = {
    "client_url": "%env(CRUDIT_STUDIO_URL)%",
    "client_public_url": "%env(CRUDIT_STUDIO_PUBLIC_URL)%",
    "project_code": "%env(CRUDIT_STUDIO_PROJECT_CODE)%",
    "project_token": "%env(CRUDIT_STUDIO_PROJECT_TOKEN)%"
} |

."when@test".lle_credential = {
    "client_url": null,
    "client_public_url": null,
    "project_code": null,
    "project_token": null
}
' "$CREDENTIAL_FILE"
    echo "✅ lle_credential.yaml file updated"
else
    echo "⏭️ lle_credential.yaml already configured, skipping"
fi

# Configure env variable
ask_and_update_env_var "CRUDIT_STUDIO_URL" "Crudit Studio URL"
ask_and_update_env_var "CRUDIT_STUDIO_PUBLIC_URL" "Crudit Studio public URL"
ask_and_update_env_var "CRUDIT_STUDIO_PROJECT_CODE" "Crudit Studio project code"
ask_and_update_env_var "CRUDIT_STUDIO_PROJECT_TOKEN" "Crudit Studio project token"

echo "✅ .env file updated"

# Translations are also centralized on crudit-studio (config/packages/translation.yaml):
# derive the provider DSN from the same project code/token instead of asking again.
if grep -Eq "^CRUDIT_TRANSLATION_DSN=.+" .env 2>/dev/null; then
    echo "⏭️ CRUDIT_TRANSLATION_DSN already set, skipping"
else
    crudit_studio_host=$(grep -E "^CRUDIT_STUDIO_URL=" .env | cut -d= -f2- | sed -E 's#^[a-zA-Z]+://##')
    dsn="crudit://\${CRUDIT_STUDIO_PROJECT_CODE}:\${CRUDIT_STUDIO_PROJECT_TOKEN}@${crudit_studio_host}"

    if [ -s .env ] && [ -n "$(tail -c1 .env)" ]; then
        echo >> .env
    fi
    echo "CRUDIT_TRANSLATION_DSN=\"$dsn\"" >> .env
    echo "✅ CRUDIT_TRANSLATION_DSN derived from CRUDIT_STUDIO_* variables"
fi

echo "✅ Crudit Studio configured (rights + translations)"