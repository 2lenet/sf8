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

# Credential config
CREDENTIAL_FILE="config/packages/lle_credential.yaml"
if [ ! -f "$CREDENTIAL_FILE" ]; then
    touch "$CREDENTIAL_FILE"
    echo "✅ File $CREDENTIAL_FILE created."
fi

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

# Configure env variable
ask_and_update_env_var "CRUDIT_STUDIO_URL" "Crudit Studio URL"
ask_and_update_env_var "CRUDIT_STUDIO_PUBLIC_URL" "Crudit Studio public URL"
ask_and_update_env_var "CRUDIT_STUDIO_PROJECT_CODE" "Crudit Studio project code"
ask_and_update_env_var "CRUDIT_STUDIO_PROJECT_TOKEN" "Crudit Studio project token"

echo "✅ .env file updated"

echo "✅ Crudit Studio configured"
