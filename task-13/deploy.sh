#!/bin/bash

set -e

USE_NETWORK="false"

YC_SERVICE_ACCOUNT_ID='aje9i647urk6u8t7t7oi'
YC_FOLDER_ID='b1g2ch5fjo9qkvb4gkrb'

REGISTRY_ID='crp54hhjchmpark0varh'

NGINX_FUNCTION_NAME="nginx-balancer"
APACHE_FUNCTION_NAME="apache-backend"
FALLBACK_FUNCTION_NAME="fallback-nginx"
RED_FUNCTION_NAME="red-page"
BLUE_FUNCTION_NAME="blue-page"
API_GATEWAY_NAME="playsdev-api-gateway"

NETWORK_NAME="default"
SUBNET_A_NAME="default-ru-central1-a"
SUBNET_B_NAME="default-ru-central1-b"

echo "Configuring Docker for Container Registry..."
yc container registry configure-docker

if [ "$USE_NETWORK" = "true" ]; then
  echo "Setting up network connectivity..."
  
  NETWORK_ID=$(yc vpc network get $NETWORK_NAME --format json 2>/dev/null | jq -r '.id' || echo "")

  if [ -z "$NETWORK_ID" ]; then
    echo "Creating new VPC network..."
    yc vpc network create \
      --name $NETWORK_NAME \
      --folder-id $YC_FOLDER_ID \
      --description "Network containers"
    NETWORK_ID=$(yc vpc network get $NETWORK_NAME --format json | jq -r '.id')
  else
    echo "Using existing VPC network: $NETWORK_ID"
  fi

  SUBNET_A_ID=$(yc vpc subnet get $SUBNET_A_NAME --format json 2>/dev/null | jq -r '.id' || echo "")
  if [ -z "$SUBNET_A_ID" ]; then
    yc vpc subnet create \
      --name $SUBNET_A_NAME \
      --folder-id $YC_FOLDER_ID \
      --network-id $NETWORK_ID \
      --range 10.0.1.0/24 \
      --zone ru-central1-a \
      --description "Subnet A containers"
    SUBNET_A_ID=$(yc vpc subnet get $SUBNET_A_NAME --format json | jq -r '.id')
  else
    echo "Using existing subnet A: $SUBNET_A_ID"
  fi

  SUBNET_B_ID=$(yc vpc subnet get $SUBNET_B_NAME --format json 2>/dev/null | jq -r '.id' || echo "")
  if [ -z "$SUBNET_B_ID" ]; then
    yc vpc subnet create \
      --name $SUBNET_B_NAME \
      --folder-id $YC_FOLDER_ID \
      --network-id $NETWORK_ID \
      --range 10.0.2.0/24 \
      --zone ru-central1-b \
      --description "Subnet B containers"
    SUBNET_B_ID=$(yc vpc subnet get $SUBNET_B_NAME --format json | jq -r '.id')
  else
    echo "Using existing subnet B: $SUBNET_B_ID"
  fi

  ALL_SUBNETS="$SUBNET_A_ID,$SUBNET_B_ID"

  echo "Network ID: $NETWORK_ID"
  echo "Subnets: $ALL_SUBNETS"
  
  # Prepare network parameters for container deployments
  NETWORK_PARAMS="--network-id $NETWORK_ID --subnets $ALL_SUBNETS"
else
  echo "Skipping network setup - containers will be deployed without VPC connectivity"
  NETWORK_PARAMS=""
fi

docker build --platform linux/amd64 -f Dockerfile.nginx-serverless -t cr.yandex/$REGISTRY_ID/nginx-balancer:latest .
docker build --platform linux/amd64 -f Dockerfile.apache-serverless -t cr.yandex/$REGISTRY_ID/apache-backend:latest .
docker build --platform linux/amd64 -f Dockerfile.fallback-nginx-serverless -t cr.yandex/$REGISTRY_ID/fallback-nginx:latest .

docker build --platform linux/amd64 -f Dockerfile.red-serverless -t cr.yandex/$REGISTRY_ID/red-page:latest .
docker build --platform linux/amd64 -f Dockerfile.blue-serverless -t cr.yandex/$REGISTRY_ID/blue-page:latest .

docker push cr.yandex/$REGISTRY_ID/nginx-balancer:latest
docker push cr.yandex/$REGISTRY_ID/apache-backend:latest
docker push cr.yandex/$REGISTRY_ID/fallback-nginx:latest

docker push cr.yandex/$REGISTRY_ID/red-page:latest
docker push cr.yandex/$REGISTRY_ID/blue-page:latest

echo "Creating red-page container..."
RED_CONTAINER_ID=$(yc serverless container get $RED_FUNCTION_NAME --format json 2>/dev/null | jq -r '.id' || echo "")

if [ -z "$RED_CONTAINER_ID" ]; then
  yc serverless container create \
    --name $RED_FUNCTION_NAME \
    --folder-id $YC_FOLDER_ID \
    --description "Red Page"

  RED_CONTAINER_ID=$(yc serverless container get $RED_FUNCTION_NAME --format json | jq -r '.id')
fi

yc serverless container revision deploy \
  --container-id $RED_CONTAINER_ID \
  --memory 128m \
  --cores 1 \
  --core-fraction 5 \
  --execution-timeout 30s \
  --image cr.yandex/$REGISTRY_ID/red-page:latest \
  --service-account-id $YC_SERVICE_ACCOUNT_ID \
  $NETWORK_PARAMS

echo "Red page container created"

echo "Creating blue-page container..."
BLUE_CONTAINER_ID=$(yc serverless container get $BLUE_FUNCTION_NAME --format json 2>/dev/null | jq -r '.id' || echo "")

if [ -z "$BLUE_CONTAINER_ID" ]; then
  yc serverless container create \
    --name $BLUE_FUNCTION_NAME \
    --folder-id $YC_FOLDER_ID \
    --description "Blue Page"

  BLUE_CONTAINER_ID=$(yc serverless container get $BLUE_FUNCTION_NAME --format json | jq -r '.id')
fi

yc serverless container revision deploy \
  --container-id $BLUE_CONTAINER_ID \
  --memory 128m \
  --cores 1 \
  --core-fraction 5 \
  --execution-timeout 30s \
  --image cr.yandex/$REGISTRY_ID/blue-page:latest \
  --service-account-id $YC_SERVICE_ACCOUNT_ID \
  $NETWORK_PARAMS

echo "Blue page container created"

echo "Creating nginx-balancer container..."
NGINX_CONTAINER_ID=$(yc serverless container get $NGINX_FUNCTION_NAME --format json 2>/dev/null | jq -r '.id' || echo "")

if [ -z "$NGINX_CONTAINER_ID" ]; then
  yc serverless container create \
    --name $NGINX_FUNCTION_NAME \
    --folder-id $YC_FOLDER_ID \
    --description "Nginx Balancer"

  NGINX_CONTAINER_ID=$(yc serverless container get $NGINX_FUNCTION_NAME --format json | jq -r '.id')
fi

RED_CONTAINER_URL=$(yc serverless container get $RED_FUNCTION_NAME --format json | jq -r '.url')
BLUE_CONTAINER_URL=$(yc serverless container get $BLUE_FUNCTION_NAME --format json | jq -r '.url')

# Extract host from URL by removing https:// prefix and / suffix
RED_CONTAINER_HOST=${RED_CONTAINER_URL#https://}
RED_CONTAINER_HOST=${RED_CONTAINER_HOST%/}
BLUE_CONTAINER_HOST=${BLUE_CONTAINER_URL#https://}
BLUE_CONTAINER_HOST=${BLUE_CONTAINER_HOST%/}

yc serverless container revision deploy \
  --container-id $NGINX_CONTAINER_ID \
  --memory 128m \
  --cores 1 \
  --core-fraction 5 \
  --execution-timeout 30s \
  --image cr.yandex/$REGISTRY_ID/nginx-balancer:latest \
  --environment RED_CONTAINER_URL=$RED_CONTAINER_URL,BLUE_CONTAINER_URL=$BLUE_CONTAINER_URL,RED_CONTAINER_HOST=$RED_CONTAINER_HOST,BLUE_CONTAINER_HOST=$BLUE_CONTAINER_HOST \
  --service-account-id $YC_SERVICE_ACCOUNT_ID \
  $NETWORK_PARAMS

echo "Nginx balancer container created"

echo "Creating apache-backend container..."
APACHE_CONTAINER_ID=$(yc serverless container get $APACHE_FUNCTION_NAME --format json 2>/dev/null | jq -r '.id' || echo "")

if [ -z "$APACHE_CONTAINER_ID" ]; then
  yc serverless container create \
    --name $APACHE_FUNCTION_NAME \
    --folder-id $YC_FOLDER_ID \
    --description "Apache Backend"
  APACHE_CONTAINER_ID=$(yc serverless container get $APACHE_FUNCTION_NAME --format json | jq -r '.id')
fi

yc serverless container revision deploy \
  --container-id $APACHE_CONTAINER_ID \
  --memory 256m \
  --cores 1 \
  --core-fraction 5 \
  --execution-timeout 30s \
  --image cr.yandex/$REGISTRY_ID/apache-backend:latest \
  --environment RED_CONTAINER_URL=$RED_CONTAINER_URL,BLUE_CONTAINER_URL=$BLUE_CONTAINER_URL \
  --service-account-id $YC_SERVICE_ACCOUNT_ID \
  $NETWORK_PARAMS

echo "Apache backend container created"

echo "Creating fallback-nginx container..."
FALLBACK_CONTAINER_ID=$(yc serverless container get $FALLBACK_FUNCTION_NAME --format json 2>/dev/null | jq -r '.id' || echo "")

if [ -z "$FALLBACK_CONTAINER_ID" ]; then
  yc serverless container create \
    --name $FALLBACK_FUNCTION_NAME \
    --folder-id $YC_FOLDER_ID \
    --description "Fallback Nginx"
  FALLBACK_CONTAINER_ID=$(yc serverless container get $FALLBACK_FUNCTION_NAME --format json | jq -r '.id')
fi

yc serverless container revision deploy \
  --container-id $FALLBACK_CONTAINER_ID \
  --memory 128m \
  --cores 1 \
  --core-fraction 5 \
  --execution-timeout 30s \
  --image cr.yandex/$REGISTRY_ID/fallback-nginx:latest \
  --service-account-id $YC_SERVICE_ACCOUNT_ID \
  $NETWORK_PARAMS

echo "Fallback nginx container created"

yc serverless container allow-unauthenticated-invoke $NGINX_CONTAINER_ID
yc serverless container allow-unauthenticated-invoke $APACHE_CONTAINER_ID
yc serverless container allow-unauthenticated-invoke $FALLBACK_CONTAINER_ID

yc serverless container allow-unauthenticated-invoke $RED_CONTAINER_ID
yc serverless container allow-unauthenticated-invoke $BLUE_CONTAINER_ID

echo "Creating API Gateway..."

cat >api-gateway-spec.yaml <<EOF
openapi: "3.0.0"
info:
  title: PlaysDev API Gateway
  version: 1.0.0
paths:
  /:
    get:
      x-yc-apigateway-integration:
        type: serverless_containers
        container_id: $NGINX_CONTAINER_ID
        service_account_id: $YC_SERVICE_ACCOUNT_ID
    post:
      x-yc-apigateway-integration:
        type: serverless_containers
        container_id: $NGINX_CONTAINER_ID
        service_account_id: $YC_SERVICE_ACCOUNT_ID
  /info.php:
    get:
      x-yc-apigateway-integration:
        type: serverless_containers
        container_id: $APACHE_CONTAINER_ID
        service_account_id: $YC_SERVICE_ACCOUNT_ID
  /redblue.php:
    get:
      x-yc-apigateway-integration:
        type: serverless_containers
        container_id: $APACHE_CONTAINER_ID
        service_account_id: $YC_SERVICE_ACCOUNT_ID
  /secondpage:
    get:
      x-yc-apigateway-integration:
        type: serverless_containers
        container_id: $FALLBACK_CONTAINER_ID
        service_account_id: $YC_SERVICE_ACCOUNT_ID
  /redblue:
    get:
      x-yc-apigateway-integration:
        type: serverless_containers
        container_id: $NGINX_CONTAINER_ID
        service_account_id: $YC_SERVICE_ACCOUNT_ID
  /red:
    get:
      x-yc-apigateway-integration:
        type: serverless_containers
        container_id: $RED_CONTAINER_ID
        service_account_id: $YC_SERVICE_ACCOUNT_ID
  /blue:
    get:
      x-yc-apigateway-integration:
        type: serverless_containers
        container_id: $BLUE_CONTAINER_ID
        service_account_id: $YC_SERVICE_ACCOUNT_ID
  /cpu:
    get:
      x-yc-apigateway-integration:
        type: serverless_containers
        container_id: $NGINX_CONTAINER_ID
        service_account_id: $YC_SERVICE_ACCOUNT_ID
  /music:
    get:
      x-yc-apigateway-integration:
        type: serverless_containers
        container_id: $NGINX_CONTAINER_ID
        service_account_id: $YC_SERVICE_ACCOUNT_ID
  /image1/{file}:
    get:
      parameters:
        - name: file
          in: path
          required: true
          schema:
            type: string
      x-yc-apigateway-integration:
        type: serverless_containers
        container_id: $NGINX_CONTAINER_ID
        service_account_id: $YC_SERVICE_ACCOUNT_ID
  /image2/{file}:
    get:
      parameters:
        - name: file
          in: path
          required: true
          schema:
            type: string
      x-yc-apigateway-integration:
        type: serverless_containers
        container_id: $NGINX_CONTAINER_ID
        service_account_id: $YC_SERVICE_ACCOUNT_ID
EOF

API_GATEWAY_ID=$(yc serverless api-gateway get $API_GATEWAY_NAME --format json 2>/dev/null | jq -r '.id' || echo "")

if [ ! -z "$API_GATEWAY_ID" ]; then
  echo "Deleting old API Gateway..."
  yc serverless api-gateway delete $API_GATEWAY_ID
fi

echo "Creating API Gateway..."
yc serverless api-gateway create \
  --name $API_GATEWAY_NAME \
  --folder-id $YC_FOLDER_ID \
  --spec api-gateway-spec.yaml \
  --description "API Gateway with load balancing"

API_GATEWAY_DOMAIN=$(yc serverless api-gateway get $API_GATEWAY_NAME --format json | jq -r '.domain')

rm -f api-gateway-spec.yaml

echo "Deployment completed successfully"
echo ""
echo "API Gateway domain: https://$API_GATEWAY_DOMAIN"
