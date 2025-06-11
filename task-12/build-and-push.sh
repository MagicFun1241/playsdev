#!/bin/bash

set -e

if ! docker info | grep -q "Username:"; then
    echo "Not logged in to Docker Hub. Please run 'docker login' first."
    read -p "Do you want to login now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker login
    else
        echo "Cannot push images without Docker Hub authentication."
        exit 1
    fi
fi

echo "Starting build and push process..."

echo "Building nginx image for amd64..."
docker build --platform linux/amd64 -f Dockerfile.nginx -t magicfun/playsdev-nginx:latest .
echo "Built magicfun/playsdev-nginx:latest"

echo "Pushing nginx image to Docker Hub..."
docker push magicfun/playsdev-nginx:latest
echo "Pushed magicfun/playsdev-nginx:latest"

echo "Building apache image for amd64..."
docker build --platform linux/amd64 -f Dockerfile.apache -t magicfun/playsdev-apache:latest .
echo "Built magicfun/playsdev-apache:latest"

echo "Pushing apache image to Docker Hub..."
docker push magicfun/playsdev-apache:latest
echo "Pushed magicfun/playsdev-apache:latest"

echo "Building fallback-nginx image for amd64..."
docker build --platform linux/amd64 -f Dockerfile.fallback-nginx -t magicfun/playsdev-fallback-nginx:latest .
echo "Built magicfun/playsdev-fallback-nginx:latest"

echo "Pushing fallback-nginx image to Docker Hub..."
docker push magicfun/playsdev-fallback-nginx:latest
echo "Pushed magicfun/playsdev-fallback-nginx:latest"

echo "All images have been successfully built and pushed to Docker Hub!"

read -p "Do you want to remove local images to save space? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Removing local images..."
    docker rmi magicfun/playsdev-nginx:latest || true
    docker rmi magicfun/playsdev-apache:latest || true
    docker rmi magicfun/playsdev-fallback-nginx:latest || true
    echo "Local images cleaned up"
fi

echo "Build and push process completed successfully!" 