#!/bin/bash

# Install bundle
docker compose exec symfony composer require 2lenet/pdf-generator-bundle

echo "✅ PdfGeneratorBundle installed"

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
    "path": "data/pdfmodel"
    "default_generator": "word_to_pdf",
    "class": "Lle\PdfGeneratorBundle\Entity\PdfModel"
}
' "$PDFGENERATOR_FILE"

echo "✅ lle_pdf_generator.yaml file created and configured"

# Route config
ROUTES_FILE="config/routes.yaml"
yq e -i --indent=4 '
.lle_pdf_generator = {
    "resource": "@LlePdfGeneratorBundle/Resources/config/routes.yaml"
    "prefix": "/"
}
' "$ROUTES_FILE"

echo "✅ routes.yaml file updated"

# Create and execute migration
read -p "Do you want to create and execute migration ? (y/n) : " reponse

if [[ "$reponse" == "y" ]]; then
    docker compose exec symfony bin/console make:migration
    docker compose exec symfony bin/console doctrine:migrations:migrate

    echo "✅ Migration generated and executed"
fi

echo "✅ PdfGeneratorBundle installed and configured"
