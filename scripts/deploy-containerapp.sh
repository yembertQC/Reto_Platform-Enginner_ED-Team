#!/usr/bin/env bash
# Crea o actualiza una Azure Container App a partir de una imagen pública de
# GitHub Container Registry (GHCR). No hace falta un registry en Azure (ACR) ni
# credenciales: Container Apps descarga la imagen de forma anónima.
# Ingress externo HTTPS, escala de 0 a 10 réplicas según tráfico HTTP.
#
# Uso: deploy-containerapp.sh <app-name> <resource-group> <environment-name> <image> <port>
#   ej. deploy-containerapp.sh ed-team-app-go rg-edteam-platform cae-edteam ghcr.io/owner/ed-team-app-go:abc1234 8080
# Requiere sesión de Azure CLI activa (Azure/login).
# Escribe url=https://<fqdn> en $GITHUB_OUTPUT (o stdout fuera de Actions).
set -euo pipefail

APP_NAME="$1"
RESOURCE_GROUP="$2"
ENVIRONMENT_NAME="$3"
IMAGE="$4"
PORT="$5"
OUT="${GITHUB_OUTPUT:-/dev/stdout}"

# Los paquetes de GHCR nacen privados (aunque el repo sea público). Si Container Apps
# no puede descargar la imagen sin credenciales, se avisa con el enlace para hacerla pública.
if [[ "$IMAGE" == ghcr.io/* ]]; then
  REF="${IMAGE#ghcr.io/}"
  if [[ "$REF" == *@* ]]; then
    NAME="${REF%@*}"; TAG="${REF#*@}"
  else
    NAME="${REF%:*}"; TAG="${REF##*:}"
  fi
  TOKEN=$(curl -fsS "https://ghcr.io/token?scope=repository:${NAME}:pull" 2>/dev/null \
    | sed -n 's/.*"token":"\([^"]*\)".*/\1/p' || true)
  STATUS=$(curl -s -o /dev/null -w '%{http_code}' -I \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Accept: application/vnd.oci.image.manifest.v1+json, application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.v2+json" \
    "https://ghcr.io/v2/${NAME}/manifests/${TAG}" || true)
  if [ "$STATUS" != "200" ]; then
    PACKAGE="${NAME##*/}"
    echo "::error::La imagen $IMAGE no se puede descargar sin credenciales (HTTP $STATUS): el paquete de GHCR es privado."
    echo "Hazlo público una sola vez: abre el paquete '$PACKAGE' (pestaña Packages del repo o del perfil),"
    echo "Package settings → Danger Zone → Change visibility → Public. Después relanza el workflow."
    if [ -n "${GITHUB_SERVER_URL:-}" ] && [ -n "${GITHUB_REPOSITORY:-}" ]; then
      echo "Paquete: $GITHUB_SERVER_URL/$GITHUB_REPOSITORY/pkgs/container/$PACKAGE"
    fi
    exit 1
  fi
  echo "✅ Imagen pública en GHCR: $IMAGE"
fi

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
  az containerapp create \
    --name "$APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --environment "$ENVIRONMENT_NAME" \
    --image "$IMAGE" \
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
