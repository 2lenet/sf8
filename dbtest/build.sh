#!/bin/sh

docker build --no-cache -t registry.2le.net/2le/[PROJECT]:dbtest .
docker push registry.2le.net/2le/[PROJECT]:dbtest
