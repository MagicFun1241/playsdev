#!/bin/bash

set -e

NETWORK_NAME="playsdev-network"

echo "Stopping and removing containers..."

docker stop nginx
docker rm nginx

docker stop apache
docker rm apache

docker stop fallback-nginx
docker rm fallback-nginx

echo "Removing network: $NETWORK_NAME"
docker network rm $NETWORK_NAME
