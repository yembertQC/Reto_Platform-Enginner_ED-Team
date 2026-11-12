#!/usr/bin/env bash
# Monta la plataforma en una organización de GitHub a partir de plataforma/repos/.
# Cada carpeta de repos/ se sube como un repo de la organización. Es idempotente:
# un repo que ya existe no se toca, así que se puede relanzar si algo falló a medias.
#
# Uso:  bash plataforma/bootstrap.sh <org>
# Requiere: gh con sesión iniciada como owner de la organización (gh auth login), y git.
#
# No crea secretos ni credenciales de nube: al final imprime qué falta y con qué comando.
set -euo pipefail

ORG="${1:?Uso: bash plataforma/bootstrap.sh <org>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"

# carpeta en repos/  →  nombre del repo en la organización (el orden importa: pipelines antes que las plantillas)
REPOS=(
  "org-profile:.github"
  "pipelines:pipelines"
  "template-go:template-go"
  "template-python:template-python"
  "catalog:catalog"
  "platform:platform"
  "portal:portal"
)
TEAMS=(platform pagos web)
LABELS=(pending running "done" rejected failed agent)

command -v gh >/dev/null || { echo "❌ Falta gh: https://cli.github.com"; exit 1; }
command -v git >/dev/null || { echo "❌ Falta git"; exit 1; }
gh api "orgs/$ORG" >/dev/null 2>&1 || { echo "❌ La organización '$ORG' no existe o no tienes acceso. Créala en https://github.com/organizations/plan"; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "👥 Teams"
for t in "${TEAMS[@]}"; do
  if gh api "orgs/$ORG/teams/$t" >/dev/null 2>&1; then
    echo "   = $t ya existe"
  else
    gh api -X POST "orgs/$ORG/teams" -f name="$t" -f privacy=closed >/dev/null
    echo "   + $t"
  fi
done

echo "📦 Repos"
for entry in "${REPOS[@]}"; do
  dir="${entry%%:*}"; repo="${entry#*:}"
  if gh repo view "$ORG/$repo" >/dev/null 2>&1; then
    echo "   = $repo ya existe (no se toca)"
    continue
  fi

  src="$WORK/$repo"
  mkdir -p "$src"
  cp -R "$HERE/repos/$dir/." "$src/"

  # pipelines lleva los scripts de despliegue del reto: una sola fuente, scripts/ en la raíz.
  if [ "$repo" = "pipelines" ]; then
    mkdir -p "$src/scripts"
    cp "$ROOT/scripts/deploy-containerapp.sh" "$ROOT/scripts/deploy-lambda.sh" "$ROOT/scripts/smoke-test.sh" "$src/scripts/"
  fi

  # __ORG__ es el marcador de la organización en uses:, CODEOWNERS y enlaces.
  grep -rl "__ORG__" "$src" 2>/dev/null | while read -r f; do
    sed -i.bak "s/__ORG__/$ORG/g" "$f" && rm -f "$f.bak"
  done

  git -C "$src" init -q -b main
  git -C "$src" add -A
  git -C "$src" commit -q -m "Plataforma: $repo"
  gh repo create "$ORG/$repo" --public --source "$src" --push >/dev/null
  echo "   + $repo"

  case "$repo" in
    pipelines)
      # Los servicios llaman a build.yml@v1
      git -C "$src" tag v1
      git -C "$src" push -q origin v1
      echo "     tag v1" ;;
    template-*)
      gh api -X PATCH "repos/$ORG/$repo" -F is_template=true >/dev/null
      echo "     marcado como plantilla" ;;
    platform)
      for l in "${LABELS[@]}"; do
        gh label create "platform/$l" -R "$ORG/platform" --force >/dev/null
      done
      echo "     etiquetas platform/*" ;;
    portal)
      # GitHub Pages directo desde main: sin build ni workflow
      gh api -X POST "repos/$ORG/portal/pages" -f "source[branch]=main" -f "source[path]=/" >/dev/null 2>&1 \
        || echo "     ⚠️  Activa Pages a mano: Settings → Pages → Deploy from a branch → main / (root)"
      echo "     Pages: https://${ORG,,}.github.io/portal/" ;;
  esac

  # El team platform es dueño de todo lo que crea este script
  gh api -X PUT "orgs/$ORG/teams/platform/repos/$ORG/$repo" -f permission=maintain >/dev/null
done

cat <<EOF

✅ Repos de la plataforma en https://github.com/$ORG

Falta lo que no debe hacer un script (credenciales y decisiones de la organización):

1. Variables de organización
   gh variable set CLOUD_PROVIDER        --org $ORG --visibility all --body azure
   gh variable set RESOURCE_GROUP        --org $ORG --visibility all --body rg-edteam-platform
   gh variable set CONTAINERAPP_ENV_NAME --org $ORG --visibility all --body cae-edteam
   gh variable set GHCR_PULL_USER        --org $ORG --visibility all --body <usuario-dueño-del-token>
   gh variable set LAMBDA_ROLE_NAME      --org $ORG --visibility all --body <rol-de-ejecucion-lambda>   # solo AWS

2. Secretos de organización (gh los pide sin mostrarlos)
   gh secret set AZURE_CREDENTIALS     --org $ORG --visibility all < azure-credentials.json
   gh secret set GHCR_PULL_TOKEN       --org $ORG --visibility all     # token clásico, solo read:packages
   gh secret set AWS_ACCESS_KEY_ID     --org $ORG --visibility all     # solo AWS
   gh secret set AWS_SECRET_ACCESS_KEY --org $ORG --visibility all     # solo AWS

3. GitHub App de la plataforma (permisos en el README de platform), instalada en todos los repos:
   gh variable set PLATFORM_APP_CLIENT_ID   --org $ORG --visibility all --body <client-id>
   gh secret set   PLATFORM_APP_PRIVATE_KEY --org $ORG --visibility all < clave-privada.pem

4. Prueba desde el portal (Pages tarda un par de minutos la primera vez):
   https://${ORG,,}.github.io/portal/
   o directo: https://github.com/$ORG/platform/issues/new?template=nuevo-servicio.yml
EOF
