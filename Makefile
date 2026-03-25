EXEC := $(shell if [ -f /.dockerenv ]; then \
    	echo ""; \
	else \
    	echo "docker compose exec symfony"; \
	fi)
CONSOLE = $(EXEC) bin/console

# Run once after composer create-project
init:
	chmod +x init.sh
	chmod +x dbtest/update_dbtest.sh
	./init.sh

# Install project
install:
	docker compose build
	docker compose run --entrypoint "/bin/sh -c" symfony "chmod -R 777 var translations"
	docker compose run --entrypoint "/bin/sh -c" symfony "composer install --no-scripts"
	docker compose run --entrypoint "/bin/sh -c" symfony "npm install"
	docker compose run --entrypoint "/bin/sh -c" symfony "npm run build"

# Start project
start:
	git config core.hooksPath .githooks
	docker compose up -d --remove-orphans
	@echo "Sf at http://127.0.0.1:8[IDENTIFIER]/"
	@echo "PMA at http://127.0.0.1:9[IDENTIFIER]/"

# Stop project
stop:
	docker compose down --remove-orphans

build:
	docker build --build-arg app_version=dev-${CI_PIPELINE_ID} -t registry.2le.net/2le/[PROJECT] .
	docker push registry.2le.net/2le/[PROJECT]

# Clear cache
cc:
	$(CONSOLE) cache:clear

# Get into Symfony docker bash
console:
	docker compose exec symfony bash

# Run migrations
prepare:
	bin/console doctrine:migrations:migrate --no-interaction --allow-no-migration --all-or-nothing
	# bin/console translation:pull loco --force
	bin/console ckeditor:install --tag=4.6.0 --clear=drop
	bin/console assets:install --symlink
	bin/console cache:clear -q
	# bin/console lle:credential:load

# Download translations from Loco
translate:
	$(CONSOLE) translation:pull loco --force

# Start watching asset files
wp-watch:
	$(EXEC) ./node_modules/.bin/encore dev --watch

# Run tests
test:
	$(EXEC) cp phpunit.xml.dist phpunit.xml
	$(EXEC) cp phpstan.dist.neon phpstan.neon
	$(CONSOLE) lint:twig templates
	$(EXEC) ./vendor/bin/phpcs
	$(EXEC) ./vendor/bin/phpstan analyse
	$(CONSOLE) doctrine:database:drop --if-exists --force --env=test
	$(CONSOLE) doctrine:database:create --if-not-exists --env=test
	$(CONSOLE) doctrine:migrations:migrate --no-interaction --allow-no-migration --all-or-nothing --env=test
	$(CONSOLE) doctrine:schema:validate -v --env=test
	$(CONSOLE) lle:credential:warmup --env=test
	$(EXEC) bin/phpunit tests/ -v --coverage-clover phpunit-coverage.xml --log-junit phpunit-report.xml --coverage-cobertura=coverage-cobertura.xml

