#!/bin/bash

set -e

NETWORK_NAME="playsdev-network"

docker network create --driver bridge $NETWORK_NAME 2>/dev/null || echo "Network $NETWORK_NAME already exists"

docker run -d \
  --name fallback-nginx \
  --network $NETWORK_NAME \
  -p 8080:80 \
  magicfun/playsdev-fallback-nginx:latest

docker run -d \
  --name apache \
  --network $NETWORK_NAME \
  -p 8090:80 \
  magicfun/playsdev-apache:latest

docker run -d \
  --name nginx \
  --network $NETWORK_NAME \
  -p 80:80 \
  -p 443:443 \
  -v /etc/letsencrypt:/etc/letsencrypt \
  magicfun/playsdev-nginx:latest
