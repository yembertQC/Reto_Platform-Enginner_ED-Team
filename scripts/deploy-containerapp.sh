#!/usr/bin/env bash
# Crea o actualiza una Azure Container App a partir de una imagen de ACR.
# Ingress externo HTTPS, escala de 0 a 10 réplicas según tráfico HTTP.
#
# Uso: deploy-containerapp.sh <app-name> <resource-group> <environment-name> <image> <acr-name> <port>
# Requiere sesión de Azure CLI activa (Azure/login).
# Escribe url=https://<fqdn> en $GITHUB_OUTPUT (o stdout fuera de Actions).
set -euo pipefail

APP_NAME="$1"
RESOURCE_GROUP="$2"
ENVIRONMENT_NAME="$3"
IMAGE="$4"
REGISTRY_NAME="$5"
PORT="$6"
OUT="${GITHUB_OUTPUT:-/dev/stdout}"

az extension add --name containerapp --upgrade --only-show-errors

if az containerapp show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
  echo "🔄 Actualizando imagen de la Container App $APP_NAME -> $IMAGE"
  az containerapp update \
    --name "$APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --image "$IMAGE" \
    --only-show-errors >/dev/null
else
  echo "🆕 Creando Container App $APP_NAME con $IMAGE"
  ACR_USERNAME=$(az acr credential show --name "$REGISTRY_NAME" --query username -o tsv)
  ACR_PASSWORD=$(az acr credential show --name "$REGISTRY_NAME" --query 'passwords[0].value' -o tsv)
  echo "::add-mask::$ACR_PASSWORD"

  az containerapp create \
    --name "$APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --environment "$ENVIRONMENT_NAME" \
    --image "$IMAGE" \
    --registry-server "$REGISTRY_NAME.azurecr.io" \
    --registry-username "$ACR_USERNAME" \
    --registry-password "$ACR_PASSWORD" \
    --ingress external \
    --target-port "$PORT" \
    --min-replicas 0 \
    --max-replicas 10 \
    --cpu 0.25 \
    --memory 0.5Gi \
    --env-vars PORT="$PORT" ENVIRONMENT=production \
    --only-show-errors >/dev/null
fi

FQDN=$(az containerapp show \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query properties.configuration.ingress.fqdn -o tsv)

echo "✅ Container App desplegada: https://$FQDN"
echo "url=https://$FQDN" >> "$OUT"
