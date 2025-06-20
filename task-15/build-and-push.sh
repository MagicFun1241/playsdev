#!/bin/bash

set -e

DOCKER_REGISTRY="magicfun"
TAG="latest"

echo "Building Docker images..."

# Build nginx image
echo "Building nginx image..."
docker build -f Dockerfile.nginx -t ${DOCKER_REGISTRY}/playsdev-nginx:${TAG} .

# Build apache image
echo "Building apache image..."
docker build -f Dockerfile.apache -t ${DOCKER_REGISTRY}/playsdev-apache:${TAG} .

# Build fallback-nginx image
echo "Building fallback-nginx image..."
docker build -f Dockerfile.fallback-nginx -t ${DOCKER_REGISTRY}/playsdev-fallback-nginx:${TAG} .

echo "Pushing images to registry..."

# Push images
docker push ${DOCKER_REGISTRY}/playsdev-nginx:${TAG}
docker push ${DOCKER_REGISTRY}/playsdev-apache:${TAG}
docker push ${DOCKER_REGISTRY}/playsdev-fallback-nginx:${TAG}

echo "All images built and pushed successfully!" 