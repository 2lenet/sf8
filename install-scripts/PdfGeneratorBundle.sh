#!/bin/bash

check() {
    if [ $? -eq 0 ]; then
        echo "✅ $1"
    else
        echo "❌ An error has occurred"
        exit 1
    fi
}

CONFIG_DIRECTORY="init-config/PdfGeneratorBundle"

# Install bundle
docker compose exec symfony composer require 2lenet/pdf-generator-bundle

check "PdfGeneratorBundle installed"

# Create PdfModel CRUD
mkdir -p src/Controller/Crudit src/Crudit/Config src/Crudit/Datasource src/Form/Crudit
cp $CONFIG_DIRECTORY/PdfModelController.php src/Controller/Crudit/
cp $CONFIG_DIRECTORY/PdfModelCrudConfig.php src/Crudit/Config/
cp $CONFIG_DIRECTORY/PdfModelDatasource.php src/Crudit/Datasource/
cp $CONFIG_DIRECTORY/PdfModelType.php src/Form/Crudit/

echo "✅ CRUD files created"

# Add unoserver to docker-compose.yml
DOCKERCOMPOSE_FILE="docker-compose.yml"
yq e -i --indent=4 '.services.unoserver.image = "registry.2le.net/2le/2le:unoserver"' "$DOCKERCOMPOSE_FILE"

echo "✅ docker-compose.yml file updated"

# PdfGenerator config
PDFGENERATOR_FILE="config/packages/lle_pdf_generator.yaml"
if [ ! -f "$PDFGENERATOR_FILE" ]; then
    touch "$PDFGENERATOR_FILE"
    echo "✅ File $PDFGENERATOR_FILE created."
fi

yq e -i --indent=4 '
.lle_pdf_generator = {
    "path": "data/pdfmodel",
    "default_generator": "word_to_pdf",
    "class": "Lle\PdfGeneratorBundle\Entity\PdfModel"
}
' "$PDFGENERATOR_FILE"

echo "✅ lle_pdf_generator.yaml file created and configured"

# Route config
ROUTES_FILE="config/routes.yaml"
yq e -i --indent=4 '
.lle_pdf_generator = {
    "resource": "@LlePdfGeneratorBundle/Resources/config/routes.yaml",
    "prefix": "/"
}
' "$ROUTES_FILE"

echo "✅ routes.yaml file updated"

# VichUploader config
VICHUPLOADER_FILE="config/packages/vich_uploader.yaml"
if [ ! -f "$VICHUPLOADER_FILE" ]; then
    touch "$VICHUPLOADER_FILE"
    echo "✅ File $VICHUPLOADER_FILE created."
fi

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

yq e -i --indent=4 '.parameters.app.path.pdf_model = ""' config/services.yaml

echo "✅ services.yaml file updated"

echo "⚠️ You must configure the value of pdf_model yourself in the services.yaml file"

# Create and execute migration
read -p "Do you want to create and execute migration ? (y/n) : " reponse

if [[ "$reponse" == "y" ]]; then
    docker compose exec symfony bin/console make:migration
    docker compose exec symfony bin/console doctrine:migrations:migrate

    echo "✅ Migration generated and executed"
fi

echo "✅ PdfGeneratorBundle installed and configured"
