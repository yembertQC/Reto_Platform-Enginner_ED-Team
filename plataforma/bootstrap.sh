#!/usr/bin/env bash
# Monta la plataforma en una organización de GitHub: cada carpeta de plataforma/repos/ es un repo.
#
# Uso:  bash plataforma/bootstrap.sh <org> [--completo] [--portal]
#
#   (sin opciones)  Modo curso (M1 · Clase 3): lo que viene hecho. platformctl con la regla OPA
#                   apagada, el catálogo, las dos plantillas y pipelines con scripts/ pero sin
#                   build.yml. Lo demás lo construye el alumno, clase a clase:
#                     M1 · C4  pipelines/build.yml y el tag v1
#                     M1 · C5  teams y CODEOWNERS
#                     M1 · C6  el formulario de solicitud
#                     M2 · C3  production con aprobación y la regla OPA encendida
#   --completo      Añade lo de plataforma/soluciones/ (build.yml + v1, CODEOWNERS, formulario)
#                   y crea los teams. Para preparar las clases o llegar directo al final del M1.
#   --portal        Extra InnerSource: el team web propone un portal de autoservicio con un pull
#                   request al repo platform (carpeta docs/, publicada con GitHub Pages al fusionar).
#
# Es idempotente: un repo que ya existe no se toca. Requiere gh con sesión de owner de la org y git.
# No crea secretos ni credenciales de nube: al final imprime qué falta y con qué comando.
set -euo pipefail

ORG=""; COMPLETO=false; PORTAL=false
for arg in "$@"; do
  case "$arg" in
    --completo) COMPLETO=true ;;
    --portal) PORTAL=true ;;
    -*) echo "Opción desconocida: $arg"; exit 1 ;;
    *) ORG="$arg" ;;
  esac
done
[ -n "$ORG" ] || { echo "Uso: bash plataforma/bootstrap.sh <org> [--completo] [--portal]"; exit 1; }
ORG_LC="$(printf %s "$ORG" | tr "[:upper:]" "[:lower:]")"   # Pages usa el nombre en minúsculas (bash 3.2 de macOS no tiene ${var,,})

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"

# carpeta en repos/  →  repo en la organización
REPOS=(
  "org-profile:.github"
  "pipelines:pipelines"
  "template-go:template-go"
  "template-python:template-python"
  "catalog:catalog"
  "platform:platform"
)
TEAMS=(platform pagos web)
LABELS=(pending running "done" rejected failed agent)

command -v gh >/dev/null || { echo "❌ Falta gh: https://cli.github.com"; exit 1; }
command -v git >/dev/null || { echo "❌ Falta git"; exit 1; }
gh api "orgs/$ORG" >/dev/null 2>&1 || { echo "❌ La organización '$ORG' no existe o no tienes acceso. Créala en https://github.com/organizations/plan"; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Sustituye el marcador __ORG__ en todos los archivos de una carpeta
set_org() {
  { grep -rl "__ORG__" "$1" 2>/dev/null || true; } | while read -r f; do
    sed -i.bak "s/__ORG__/$ORG/g" "$f" && rm -f "$f.bak"
  done
}

if $COMPLETO; then
  echo "👥 Teams (solución de M1 · Clase 5)"
  for t in "${TEAMS[@]}"; do
    if gh api "orgs/$ORG/teams/$t" >/dev/null 2>&1; then
      echo "   = $t ya existe"
    else
      gh api -X POST "orgs/$ORG/teams" -f name="$t" -f privacy=closed >/dev/null
      echo "   + $t"
    fi
  done
fi

echo "📦 Repos ($($COMPLETO && echo completo || echo modo curso))"
for entry in "${REPOS[@]}"; do
  dir="${entry%%:*}"; repo="${entry#*:}"
  if gh repo view "$ORG/$repo" >/dev/null 2>&1; then
    echo "   = $repo ya existe (no se toca)"
    continue
  fi

  src="$WORK/$repo"
  mkdir -p "$src"
  cp -R "$HERE/repos/$dir/." "$src/"
  if $COMPLETO && [ -d "$HERE/soluciones/$dir" ]; then
    cp -R "$HERE/soluciones/$dir/." "$src/"
  fi
  find "$src" \( -name __pycache__ -o -name .pytest_cache -o -name .venv \) -prune -exec rm -rf {} +

  # pipelines lleva los scripts de despliegue del reto: una sola fuente, scripts/ en la raíz.
  if [ "$repo" = "pipelines" ]; then
    mkdir -p "$src/scripts"
    cp "$ROOT/scripts/deploy-containerapp.sh" "$ROOT/scripts/deploy-lambda.sh" "$ROOT/scripts/smoke-test.sh" "$src/scripts/"
  fi
  set_org "$src"

  git -C "$src" init -q -b main
  git -C "$src" add -A
  git -C "$src" commit -q -m "Plataforma: $repo"
  gh repo create "$ORG/$repo" --public --source "$src" --push >/dev/null
  echo "   + $repo"

  case "$repo" in
    pipelines)
      if $COMPLETO; then
        git -C "$src" tag v1
        git -C "$src" push -q origin v1
        echo "     tag v1"
      fi ;;
    template-*)
      gh api -X PATCH "repos/$ORG/$repo" -F is_template=true >/dev/null
      echo "     marcado como plantilla" ;;
    platform)
      for l in "${LABELS[@]}"; do
        gh label create "platform/$l" -R "$ORG/platform" --force >/dev/null
      done
      echo "     etiquetas platform/*" ;;
  esac

  if $COMPLETO; then
    gh api -X PUT "orgs/$ORG/teams/platform/repos/$ORG/$repo" -f permission=maintain >/dev/null
  fi
done

if $PORTAL; then
  echo "🪟 Portal (extra InnerSource): pull request al repo platform"
  if gh api "repos/$ORG/platform/branches/portal" >/dev/null 2>&1; then
    echo "   = la rama portal ya existe (no se toca)"
  else
    pdir="$WORK/platform-portal"
    gh repo clone "$ORG/platform" "$pdir" -- -q
    git -C "$pdir" switch -q -c portal
    mkdir -p "$pdir/docs"
    cp -R "$HERE/extras/portal/docs/." "$pdir/docs/"
    set_org "$pdir/docs"
    git -C "$pdir" add docs
    git -C "$pdir" commit -q -m "Portal de autoservicio en docs/ (propuesta del team web)"
    git -C "$pdir" push -q -u origin portal
    gh pr create -R "$ORG/platform" --head portal --base main \
      --title "Portal de autoservicio para la plataforma" \
      --body "$(cat "$HERE/extras/portal/PR.md")" >/dev/null
    # Pages desde main/docs: queda publicado en cuanto se fusione el PR
    gh api -X POST "repos/$ORG/platform/pages" -f "source[branch]=main" -f "source[path]=/docs" >/dev/null 2>&1 \
      || echo "   ⚠️  Al fusionar, activa Pages a mano: Settings → Pages → Deploy from a branch → main /docs"
    echo "   + PR abierto: https://github.com/$ORG/platform/pulls"
    echo "     Al fusionarlo: https://$ORG_LC.github.io/platform/"
  fi
fi

cat <<EOF

✅ Plataforma en https://github.com/$ORG

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
EOF

if $COMPLETO; then
  cat <<EOF

4. Prueba: https://github.com/$ORG/platform/issues/new?template=nuevo-servicio.yml
   Módulo 2 · Clase 3, cuando toque:
   gh variable set PRODUCTION_REVIEWERS --org $ORG --visibility all --body platform
   gh variable set POLICY_ENABLED       --org $ORG --visibility all --body true
EOF
else
  cat <<EOF

4. Lo que construyes en el curso (soluciones en plataforma/soluciones/):
   M1 · C4  pipelines/.github/workflows/build.yml y el tag v1
   M1 · C5  teams platform, pagos y web; CODEOWNERS en pipelines, platform y catalog
   M1 · C6  platform/.github/ISSUE_TEMPLATE/nuevo-servicio.yml
EOF
fi
