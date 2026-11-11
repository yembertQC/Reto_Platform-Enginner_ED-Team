#!/usr/bin/env bash
# Borra la infraestructura serverless de Azure del curso, en orden de dependencias:
#   Container App (Go) → Container Apps Environment → Function App (Python) y su plan Flex → Storage Account.
# Es idempotente: lo que ya no existe se salta, así que se puede relanzar sin miedo.
# Conserva el Resource Group (puede tener otras cosas y los permisos del Service Principal)
# y las imágenes de GHCR (ver doc/13-Que-NO-hacer.md).
#
# Uso: destroy-azure.sh <resource-group> <container-app> <containerapp-env> <function-app> <storage-account>
#   ej. destroy-azure.sh rg-edteam-platform ed-team-app-go cae-edteam func-edteam-app stedteamfunc
# Requiere una sesión de az ya iniciada (Azure/login).
# Escribe el resultado en $GITHUB_STEP_SUMMARY si existe.
set -euo pipefail

if [ "$#" -ne 5 ]; then
  echo "Uso: $0 <resource-group> <container-app> <containerapp-env> <function-app> <storage-account>" >&2
  exit 2
fi
for ARG in "$@"; do
  if [ -z "$ARG" ]; then
    echo "::error::Falta un nombre (¿variable de repo vacía?). Argumentos: $*" >&2
    exit 2
  fi
done

RG="$1"
APP="$2"
ENV_NAME="$3"
FUNC="$4"
STORAGE="$5"

SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/null}"
report() { echo "$1"; echo "| $2 | \`$3\` | $4 |" >> "$SUMMARY"; }

{
  echo ""
  echo "## 🗑️ Azure · limpieza de la infraestructura"
  echo ""
  echo "| Recurso | Nombre | Resultado |"
  echo "|---------|--------|-----------|"
} >> "$SUMMARY"

if ! az group show --name "$RG" > /dev/null 2>&1; then
  report "ℹ️ El Resource Group $RG no existe: no hay nada que borrar" "Resource Group" "$RG" "No existe"
  exit 0
fi

az extension add --name containerapp --upgrade --only-show-errors

# 1. Container App de Go (la crea el primer CD)
if az containerapp show --name "$APP" --resource-group "$RG" > /dev/null 2>&1; then
  az containerapp delete --name "$APP" --resource-group "$RG" --yes --only-show-errors
  report "🗑️ Container App borrada: $APP" "Container App" "$APP" "🗑️ Borrada"
else
  report "- Container App $APP: no existe" "Container App" "$APP" "No existía"
fi

# 2. Container Apps Environment (tarda unos minutos)
if az containerapp env show --name "$ENV_NAME" --resource-group "$RG" > /dev/null 2>&1; then
  az containerapp env delete --name "$ENV_NAME" --resource-group "$RG" --yes --only-show-errors
  report "🗑️ Container Apps Environment borrado: $ENV_NAME" "Container Apps Environment" "$ENV_NAME" "🗑️ Borrado"
else
  report "- Container Apps Environment $ENV_NAME: no existe" "Container Apps Environment" "$ENV_NAME" "No existía"
fi

# 3. Function App y su plan.
# En Flex Consumption los campos van dentro de "properties" (serverFarmId arriba viene vacío).
PLAN_IDS=""
if az functionapp show --name "$FUNC" --resource-group "$RG" > /dev/null 2>&1; then
  PLAN_IDS=$(az functionapp show --name "$FUNC" --resource-group "$RG" \
    --query "properties.serverFarmId || serverFarmId" -o tsv)
  az functionapp delete --name "$FUNC" --resource-group "$RG" --only-show-errors
  report "🗑️ Function App borrada: $FUNC" "Function App" "$FUNC" "🗑️ Borrada"
else
  report "- Function App $FUNC: no existe" "Function App" "$FUNC" "No existía"
fi

# Planes Flex Consumption vacíos del RG: los que dejó esta Function App o un destroy anterior.
# Un plan Flex sin apps no sirve para nada, así que es seguro borrarlo.
EMPTY_FLEX=$(az appservice plan list --resource-group "$RG" \
  --query "[?sku.tier=='FlexConsumption' && numberOfSites==\`0\`].id" -o tsv 2>/dev/null || true)
for PLAN_ID in $(printf '%s\n%s\n' "$PLAN_IDS" "$EMPTY_FLEX" | sort -u); do
  if az resource show --ids "$PLAN_ID" > /dev/null 2>&1; then
    az resource delete --ids "$PLAN_ID" --only-show-errors
    report "🗑️ Plan borrado: ${PLAN_ID##*/}" "Plan Flex Consumption" "${PLAN_ID##*/}" "🗑️ Borrado"
  fi
done

# 4. Storage Account de la Function App (después de la app, que la usa)
if az storage account show --name "$STORAGE" --resource-group "$RG" > /dev/null 2>&1; then
  az storage account delete --name "$STORAGE" --resource-group "$RG" --yes --only-show-errors
  report "🗑️ Storage Account borrada: $STORAGE" "Storage Account" "$STORAGE" "🗑️ Borrada"
else
  report "- Storage Account $STORAGE: no existe" "Storage Account" "$STORAGE" "No existía"
fi

report "✅ Resource Group conservado: $RG" "Resource Group" "$RG" "✅ Conservado"
echo "| Imágenes de GHCR | \`<CONTAINER_NAME>-go\` | ✅ Conservadas (se borran en la pestaña Packages) |" >> "$SUMMARY"

# 5. Comprobación: qué queda en el RG (este script no borra lo que no creó el curso)
LEFT=$(az resource list --resource-group "$RG" --query "[].[name, type]" -o tsv)
if [ -n "$LEFT" ]; then
  echo "::warning::Quedan recursos en $RG que no crea el curso; revísalos en el portal si no los esperabas"
  { echo ""; echo "### ⚠️ Recursos que siguen en \`$RG\`"; echo ""; echo '```'; echo "$LEFT"; echo '```'; } >> "$SUMMARY"
  echo "$LEFT"
else
  echo "" >> "$SUMMARY"
  echo "✅ El Resource Group \`$RG\` ha quedado vacío." >> "$SUMMARY"
fi

echo "✅ Limpieza de Azure terminada"
