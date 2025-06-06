#!/bin/bash

# This script deploys the ACT Labs Hub application to Azure Container Apps.
# It will deploy to the dev environment by default. To deploy to prod, pass "prod" as an argument.
# Usage: ./deploy.sh [dev|prod]

# Check if the script is running for prod or dev and set the environment variables accordingly.
if [ "$1" == "prod" ]; then
  export $(egrep -v '^#' .prod.containerapp.env | xargs)

else
  export $(egrep -v '^#' .nprd.containerapp.env | xargs)
fi

env_status=$(az containerapp env show --name actlabs-hub-env-eastus \
  --resource-group $ACTLABS_HUB_RESOURCE_GROUP \
  --subscription $ACTLABS_HUB_SUBSCRIPTION_NAME \
  --query properties.provisioningState \
  --output tsv)

if [ "$env_status" != "Succeeded" ]; then
  # Create the environment
  az containerapp env create --name actlabs-hub-env-eastus \
    --resource-group $ACTLABS_HUB_RESOURCE_GROUP \
    --subscription $ACTLABS_HUB_SUBSCRIPTION_NAME \
    --location eastus \
    --logs-destination none

  if [ $? -ne 0 ]; then
    echo "Failed to create environment"
    exit 1
  fi
else
  echo "Environment already exists"
fi

DEFAULT_DOMAIN=$(az containerapp env show --name actlabs-hub-env-eastus \
  --resource-group $ACTLABS_HUB_RESOURCE_GROUP \
  --subscription $ACTLABS_HUB_SUBSCRIPTION_NAME \
  --query properties.defaultDomain \
  --output tsv)
if [ $? -ne 0 ]; then
  echo "Failed to get defaultDomain of environment"
  exit 1
fi

# Deploy the Container App
az containerapp create \
  --name $ACTLABS_HUB_APP_NAME \
  --resource-group $ACTLABS_HUB_RESOURCE_GROUP \
  --subscription $ACTLABS_HUB_SUBSCRIPTION_NAME \
  --environment actlabs-hub-env-eastus \
  --allow-insecure false \
  --image $ACTLABS_HUB_IMAGE \
  --ingress 'external' \
  --min-replicas 1 \
  --max-replicas 1 \
  --target-port $ACTLABS_HUB_PORT \
  --user-assigned $ACTLABS_HUB_MANAGED_IDENTITY_RESOURCE_ID \
  --env-vars \
  "ACTLABS_HUB_URL=https://$ACTLABS_HUB_APP_NAME.$DEFAULT_DOMAIN/" \
  "ACTLABS_HUB_LOG_LEVEL=$ACTLABS_HUB_LOG_LEVEL" \
  "ACTLABS_HUB_SUBSCRIPTION_ID=$ACTLABS_HUB_SUBSCRIPTION_ID" \
  "ACTLABS_HUB_RESOURCE_GROUP=$ACTLABS_HUB_RESOURCE_GROUP" \
  "ACTLABS_HUB_STORAGE_ACCOUNT=$ACTLABS_HUB_STORAGE_ACCOUNT" \
  "ACTLABS_HUB_MANAGED_IDENTITY_RESOURCE_ID=$ACTLABS_HUB_MANAGED_IDENTITY_RESOURCE_ID" \
  "ACTLABS_HUB_MANAGED_SERVERS_TABLE_NAME=$ACTLABS_HUB_MANAGED_SERVERS_TABLE_NAME" \
  "ACTLABS_HUB_READINESS_ASSIGNMENTS_TABLE_NAME=$ACTLABS_HUB_READINESS_ASSIGNMENTS_TABLE_NAME" \
  "ACTLABS_HUB_CHALLENGES_TABLE_NAME=$ACTLABS_HUB_CHALLENGES_TABLE_NAME" \
  "ACTLABS_HUB_PROFILES_TABLE_NAME=$ACTLABS_HUB_PROFILES_TABLE_NAME" \
  "ACTLABS_HUB_DEPLOYMENTS_TABLE_NAME=$ACTLABS_HUB_DEPLOYMENTS_TABLE_NAME" \
  "ACTLABS_HUB_EVENTS_TABLE_NAME=$ACTLABS_HUB_EVENTS_TABLE_NAME" \
  "ACTLABS_HUB_DEPLOYMENT_OPERATIONS_TABLE_NAME=$ACTLABS_HUB_DEPLOYMENT_OPERATIONS_TABLE_NAME" \
  "ACTLABS_HUB_CLIENT_ID=$ACTLABS_HUB_CLIENT_ID" \
  "ACTLABS_HUB_USE_MSI=$ACTLABS_HUB_USE_MSI" \
  "PORT=$ACTLABS_HUB_PORT" \
  "ACTLABS_HUB_AUTO_DESTROY_POLLING_INTERVAL_SECONDS=$ACTLABS_HUB_AUTO_DESTROY_POLLING_INTERVAL_SECONDS" \
  "ACTLABS_HUB_AUTO_DESTROY_IDLE_TIME_SECONDS=$ACTLABS_HUB_AUTO_DESTROY_IDLE_TIME_SECONDS" \
  "ACTLABS_HUB_DEPLOYMENTS_POLLING_INTERVAL_SECONDS=$ACTLABS_HUB_DEPLOYMENTS_POLLING_INTERVAL_SECONDS" \
  "ACTLABS_SERVER_PORT=$ACTLABS_SERVER_PORT" \
  "ACTLABS_SERVER_READINESS_PROBE_PATH=$ACTLABS_SERVER_READINESS_PROBE_PATH" \
  "ACTLABS_SERVER_ROOT_DIR=$ACTLABS_SERVER_ROOT_DIR" \
  "ACTLABS_SERVER_UP_WAIT_TIME_SECONDS=$ACTLABS_SERVER_UP_WAIT_TIME_SECONDS" \
  "ACTLABS_SERVER_USE_MSI=$ACTLABS_SERVER_USE_MSI" \
  "ACTLABS_SERVER_CPU=$ACTLABS_SERVER_CPU" \
  "ACTLABS_SERVER_MEMORY=$ACTLABS_SERVER_MEMORY" \
  "ACTLABS_SERVER_IMAGE=$ACTLABS_SERVER_IMAGE" \
  "ACTLABS_SERVER_MANAGED_ENVIRONMENT_ID=$ACTLABS_SERVER_MANAGED_ENVIRONMENT_ID" \
  "ACTLABS_SERVER_RESOURCE_GROUP=$ACTLABS_SERVER_RESOURCE_GROUP" \
  "ACTLABS_SERVER_USE_SERVICE_PRINCIPAL=$ACTLABS_SERVER_USE_SERVICE_PRINCIPAL" \
  "ACTLABS_SERVER_SERVICE_PRINCIPAL_CLIENT_ID=$ACTLABS_SERVER_SERVICE_PRINCIPAL_CLIENT_ID" \
  "ACTLABS_SERVER_SERVICE_PRINCIPAL_OBJECT_ID=$ACTLABS_SERVER_SERVICE_PRINCIPAL_OBJECT_ID" \
  "ACTLABS_SERVER_SERVICE_PRINCIPAL_CLIENT_SECRET_KEYVAULT_URL=$ACTLABS_SERVER_SERVICE_PRINCIPAL_CLIENT_SECRET_KEYVAULT_URL" \
  "ACTLABS_SERVER_FDPO_SERVICE_PRINCIPAL_CLIENT_ID=$ACTLABS_SERVER_FDPO_SERVICE_PRINCIPAL_CLIENT_ID" \
  "ACTLABS_SERVER_FDPO_SERVICE_PRINCIPAL_OBJECT_ID=$ACTLABS_SERVER_FDPO_SERVICE_PRINCIPAL_OBJECT_ID" \
  "ACTLABS_SERVER_FDPO_SERVICE_PRINCIPAL_SECRET=$ACTLABS_SERVER_FDPO_SERVICE_PRINCIPAL_SECRET" \
  "ACTLABS_SERVER_FDPO_SERVICE_PRINCIPAL_CLIENT_SECRET_KEYVAULT_URL=$ACTLABS_SERVER_FDPO_SERVICE_PRINCIPAL_CLIENT_SECRET_KEYVAULT_URL" \
  "AUTH_TOKEN_AUD=$AUTH_TOKEN_AUD" \
  "AUTH_TOKEN_ISS=$AUTH_TOKEN_ISS" \
  "HTTPS_PORT=$HTTPS_PORT" \
  "HTTP_PORT=$HTTP_PORT" \
  "PROTECTED_LAB_SECRET=$PROTECTED_LAB_SECRET" \
  "TENANT_ID=$TENANT_ID" \
  "FDPO_TENANT_ID=$FDPO_TENANT_ID"

if [ $? -ne 0 ]; then
  echo "Failed to create container app"
  exit 1
fi
