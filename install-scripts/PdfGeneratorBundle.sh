#!/bin/bash

set -e
set -o pipefail
trap 'echo "❌ An error occurred at line $LINENO. Aborting."' ERR

CONFIG_DIRECTORY="init-config/PdfGeneratorBundle"

# Install bundle
if [ ! -d "vendor/2lenet/pdf-generator-bundle" ]; then
    docker compose exec symfony composer require 2lenet/pdf-generator-bundle
    echo "✅ PdfGeneratorBundle installed"
else
    echo "⏭️ PdfGeneratorBundle already installed, skipping"
fi

# Create PdfModel CRUD
mkdir -p src/Controller/Crudit src/Crudit/Config src/Crudit/Datasource src/Form/Crudit

[ ! -f "src/Controller/Crudit/PdfModelController.php" ] && cp "$CONFIG_DIRECTORY/PdfModelController.php" src/Controller/Crudit/
[ ! -f "src/Crudit/Config/PdfModelCrudConfig.php" ] && cp "$CONFIG_DIRECTORY/PdfModelCrudConfig.php" src/Crudit/Config/
[ ! -f "src/Crudit/Datasource/PdfModelDatasource.php" ] && cp "$CONFIG_DIRECTORY/PdfModelDatasource.php" src/Crudit/Datasource/
[ ! -f "src/Form/Crudit/PdfModelType.php" ] && cp "$CONFIG_DIRECTORY/PdfModelType.php" src/Form/Crudit/

echo "✅ CRUD files created"

# Add unoserver to docker-compose.yml
DOCKERCOMPOSE_FILE="docker-compose.yml"
if [ "$(yq e '.services.unoserver.image' "$DOCKERCOMPOSE_FILE")" = "null" ]; then
    yq e -i --indent=4 '.services.unoserver.image = "registry.2le.net/2le/2le:unoserver"' "$DOCKERCOMPOSE_FILE"
    echo "✅ docker-compose.yml file updated"
else
    echo "⏭️ docker-compose.yml already configured, skipping"
fi

# PdfGenerator config
PDFGENERATOR_FILE="config/packages/lle_pdf_generator.yaml"
if [ ! -f "$PDFGENERATOR_FILE" ]; then
    touch "$PDFGENERATOR_FILE"
    echo "✅ File $PDFGENERATOR_FILE created."
fi

if [ "$(yq e '.lle_pdf_generator' "$PDFGENERATOR_FILE")" = "null" ]; then
    yq e -i --indent=4 '
.lle_pdf_generator = {
    "path": "data/pdfmodel",
    "default_generator": "word_to_pdf",
    "class": "Lle\PdfGeneratorBundle\Entity\PdfModel"
}
' "$PDFGENERATOR_FILE"
    echo "✅ lle_pdf_generator.yaml file created and configured"
else
    echo "⏭️ lle_pdf_generator.yaml already configured, skipping"
fi

# Route config
ROUTES_FILE="config/routes.yaml"
if [ "$(yq e '.lle_pdf_generator' "$ROUTES_FILE")" = "null" ]; then
    yq e -i --indent=4 '
.lle_pdf_generator = {
    "resource": "@LlePdfGeneratorBundle/Resources/config/routes.yaml",
    "prefix": "/"
}
' "$ROUTES_FILE"
    echo "✅ routes.yaml file updated"
else
    echo "⏭️ routes.yaml already configured, skipping"
fi

# VichUploader config
VICHUPLOADER_FILE="config/packages/vich_uploader.yaml"
if [ ! -f "$VICHUPLOADER_FILE" ]; then
    touch "$VICHUPLOADER_FILE"
    echo "✅ File $VICHUPLOADER_FILE created."
fi

if [ "$(yq e '.vich_uploader' "$VICHUPLOADER_FILE")" = "null" ]; then
    yq e -i --indent=4 '
.vich_uploader = {
    "db_driver": "orm",
    "metadata": {
        "type": "attribute"
    },
    "mappings": {
        "pdf_model": {
            "upload_destination": "%app.path.pdf_model%",
            "namer": "Vich\UploaderBundle\Naming\UniqidNamer"
        }
    }
}
' "$VICHUPLOADER_FILE"
    echo "✅ vich_uploader.yaml file updated"
else
    echo "⏭️ vich_uploader.yaml already configured, skipping"
fi

if [ "$(yq e '.parameters."app.path.pdf_model"' config/services.yaml)" = "null" ]; then
    yq e -i --indent=4 '.parameters."app.path.pdf_model" = ""' config/services.yaml
    echo "✅ services.yaml file updated"
else
    echo "⏭️ services.yaml already configured, skipping"
fi

echo "⚠️ You must configure the value of pdf_model yourself in the services.yaml file"

# Create and execute migration
read -p "Do you want to create and execute migration ? (y/n) : " reponse

if [[ "$reponse" == "y" ]]; then
    docker compose exec symfony bin/console make:migration
    docker compose exec symfony bin/console doctrine:migrations:migrate
    echo "✅ Migration generated and executed"
fi

echo "✅ PdfGeneratorBundle installed and configured"