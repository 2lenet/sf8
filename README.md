# SF8 2LE project template

To bootstrap a project, use the following steps:

```bash
composer create-project 2lenet/sf8 project_name --no-scripts
```

or with docker :

```bash
docker run -it -v $PWD:/app registry.2le.net/2le/2le:base-sf8 composer create-project 2lenet/sf8 project_name --no-scripts
```

Say "Yes" to all recipes question except Doctrine

Next, you will need to configure the project permissions as follows:
```bash
sudo chown -R $USER project_name
```

Then, initialize the project
```bash
cd project_name
make init
```

This script will create your project and configure it:
* Docker and Docker Compose config
* CI with test, build and deploy
* Create a dbtest image for your project and test
* Monolog, Sentry and Translation (Crudit Studio) config
* Rights management (Crudit Studio) config
* PHPStan, PHPCS and SonarQube config

When the script is finished, your project is ready to use.
