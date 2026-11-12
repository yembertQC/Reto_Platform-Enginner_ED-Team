#!/usr/bin/env bash
# Crea o actualiza una Azure Container App a partir de una imagen de GitHub
# Container Registry (GHCR). No hace falta un registry en Azure (ACR).
# Ingress externo HTTPS, escala de 0 a 10 réplicas según tráfico HTTP.
#
# Dos formas de descargar la imagen:
#   - Anónima (por defecto, la del repo del reto): el paquete de GHCR debe ser público.
#   - Con credencial (la de la plataforma): si GHCR_PULL_USER y GHCR_PULL_TOKEN están
#     definidas, la Container App guarda esa credencial de solo lectura (read:packages)
#     y el paquete puede seguir privado. Sirve para todos los servicios de la organización.
#
# Uso: deploy-containerapp.sh <app-name> <resource-group> <environment-name> <image> <port>
#   ej. deploy-containerapp.sh ed-team-app-go rg-edteam-platform cae-edteam ghcr.io/owner/ed-team-app-go:abc1234 8080
# Tamaño (opcional): CONTAINERAPP_CPU y CONTAINERAPP_MEMORY (por defecto 0.25 y 0.5Gi; pares válidos
#   de Container Apps: 0.25/0.5Gi, 0.5/1Gi, 1.0/2Gi...). Se aplican al crear y al actualizar.
# Requiere sesión de Azure CLI activa (Azure/login).
# Escribe url=https://<fqdn> en $GITHUB_OUTPUT (o stdout fuera de Actions).
set -euo pipefail

APP_NAME="$1"
RESOURCE_GROUP="$2"
ENVIRONMENT_NAME="$3"
IMAGE="$4"
PORT="$5"
OUT="${GITHUB_OUTPUT:-/dev/stdout}"
PULL_USER="${GHCR_PULL_USER:-}"
PULL_TOKEN="${GHCR_PULL_TOKEN:-}"
CPU="${CONTAINERAPP_CPU:-0.25}"
MEMORY="${CONTAINERAPP_MEMORY:-0.5Gi}"

if [[ -n "$PULL_USER" && -z "$PULL_TOKEN" ]] || [[ -z "$PULL_USER" && -n "$PULL_TOKEN" ]]; then
  echo "::error::Define GHCR_PULL_USER y GHCR_PULL_TOKEN juntas, o ninguna (descarga anónima)."
  exit 1
fi

# Antes de tocar Azure, comprueba que la imagen se puede descargar de la misma forma
# que lo hará Container Apps: anónima o con la credencial.
if [[ "$IMAGE" == ghcr.io/* ]]; then
  REF="${IMAGE#ghcr.io/}"
  if [[ "$REF" == *@* ]]; then
    NAME="${REF%@*}"; TAG="${REF#*@}"
  else
    NAME="${REF%:*}"; TAG="${REF##*:}"
  fi
  AUTH=()
  if [ -n "$PULL_TOKEN" ]; then
    echo "::add-mask::$PULL_TOKEN"
    AUTH=(-u "${PULL_USER}:${PULL_TOKEN}")
  fi
  TOKEN=$(curl -fsS ${AUTH[@]+"${AUTH[@]}"} "https://ghcr.io/token?scope=repository:${NAME}:pull" 2>/dev/null \
    | sed -n 's/.*"token":"\([^"]*\)".*/\1/p' || true)
  STATUS=$(curl -s -o /dev/null -w '%{http_code}' -I \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Accept: application/vnd.oci.image.manifest.v1+json, application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.v2+json" \
    "https://ghcr.io/v2/${NAME}/manifests/${TAG}" || true)
  if [ "$STATUS" != "200" ]; then
    PACKAGE="${NAME##*/}"
    if [ -n "$PULL_TOKEN" ]; then
      echo "::error::La imagen $IMAGE no se puede descargar con la credencial de GHCR_PULL_USER (HTTP $STATUS)."
      echo "Revisa que el token tenga read:packages, que no haya caducado y que '$PULL_USER' pueda leer el paquete '$PACKAGE'."
      exit 1
    fi
    echo "::error::La imagen $IMAGE no se puede descargar sin credenciales (HTTP $STATUS): el paquete de GHCR es privado."
    echo "Hazlo público una sola vez: abre el paquete '$PACKAGE' (pestaña Packages del repo o del perfil),"
    echo "Package settings → Danger Zone → Change visibility → Public. Después relanza el workflow."
    if [ -n "${GITHUB_SERVER_URL:-}" ] && [ -n "${GITHUB_REPOSITORY:-}" ]; then
      echo "Paquete: $GITHUB_SERVER_URL/$GITHUB_REPOSITORY/pkgs/container/$PACKAGE"
    fi
    exit 1
  fi
  if [ -n "$PULL_TOKEN" ]; then
    echo "✅ Imagen accesible en GHCR con la credencial de solo lectura: $IMAGE"
  else
    echo "✅ Imagen pública en GHCR: $IMAGE"
  fi
fi

az extension add --name containerapp --upgrade --only-show-errors

if az containerapp show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
  if [ -n "$PULL_TOKEN" ]; then
    # Idempotente: deja la credencial al día (por si el token se renovó).
    az containerapp registry set \
      --name "$APP_NAME" \
      --resource-group "$RESOURCE_GROUP" \
      --server ghcr.io \
      --username "$PULL_USER" \
      --password "$PULL_TOKEN" \
      --only-show-errors >/dev/null
  fi
  echo "🔄 Actualizando imagen de la Container App $APP_NAME -> $IMAGE"
  az containerapp update \
    --name "$APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --image "$IMAGE" \
    --cpu "$CPU" \
    --memory "$MEMORY" \
    --only-show-errors >/dev/null
else
  REGISTRY=()
  if [ -n "$PULL_TOKEN" ]; then
    REGISTRY=(--registry-server ghcr.io --registry-username "$PULL_USER" --registry-password "$PULL_TOKEN")
  fi
  echo "🆕 Creando Container App $APP_NAME con $IMAGE ($CPU vCPU, $MEMORY)"
  az containerapp create \
    --name "$APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --environment "$ENVIRONMENT_NAME" \
    --image "$IMAGE" \
    ${REGISTRY[@]+"${REGISTRY[@]}"} \
    --ingress external \
    --target-port "$PORT" \
    --min-replicas 0 \
    --max-replicas 10 \
    --cpu "$CPU" \
    --memory "$MEMORY" \
    --env-vars PORT="$PORT" ENVIRONMENT=production \
    --only-show-errors >/dev/null
fi

FQDN=$(az containerapp show \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query properties.configuration.ingress.fqdn -o tsv)

echo "✅ Container App desplegada: https://$FQDN"
echo "url=https://$FQDN" >> "$OUT"
