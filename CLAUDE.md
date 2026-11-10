# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Qué es este repo

Reto DevSecOps (material de curso de plataforma): dos APIs mínimas e idénticas en comportamiento (`GET /` → `{"message": "Hola ED Team"}`, `GET /health` → `{"status": "healthy"}`) cuyo valor real está en los pipelines de GitHub Actions (SAST/SCA/escaneo de imagen + despliegue **serverless** en Azure y AWS). La mayor parte del trabajo se hace en `.github/workflows/` y `scripts/`, no en el código de las apps. Documentación en español; mantener ese idioma.

| App | Azure | AWS |
|-----|-------|-----|
| `src/` Python 3.13 Flask (puerto 5000) | Azure Functions Flex Consumption (zip + remote build) | Lambda con imagen de contenedor + Function URL |
| `src-go/` Go 1.23 (puerto 8080) | Azure Container Apps (imagen en ACR) | Lambda con imagen de contenedor + Function URL |

Ya no hay Kubernetes (AKS/EKS, manifiestos, Traefik): se eliminaron al pasar a serverless.

- Toda la documentación vive en `doc/` (fuente de la Wiki de GitHub): `Home.md` + páginas `00-…14-*.md` (0 = qué es Ingeniería de Plataforma, 13 = qué NO hacer, 14 = buenas prácticas de GitHub), `_Sidebar.md`, `_Footer.md`. No hay `ARCHITECTURE.md` en la raíz.

## Comandos

```bash
# Go
cd src-go && go run main.go                          # http://localhost:8080
cd src-go && go test -v -race ./...                  # lo mismo que corre CI
cd src-go && go test -v -run TestHealthHandler ./... # un solo test

# Python (usar uv, no pip global)
cd src && uv run --with-requirements requirements.txt python app.py   # http://localhost:5000

# Docker (las mismas imágenes que van a Lambda / Container Apps)
docker build -t ed-team-app src/      && docker run -p 5000:5000 ed-team-app
docker build -t ed-team-app-go src-go/ && docker run -p 8080:8080 ed-team-app-go

# Lint de workflows y scripts (sin instalar nada global)
uvx --from actionlint-py actionlint .github/workflows/*.yml
uvx --from shellcheck-py shellcheck scripts/*.sh

# Generar la wiki en local y validar enlaces de doc/
bash scripts/build-wiki.sh doc build/wiki https://github.com/<owner>/<repo>/blob/main
```

No hay tests para la app Python ni linter de código configurado.

## Arquitectura (lo que no es obvio leyendo un solo archivo)

- **Selección de cloud**: `cd.yml` y `cd-go.yml` despliegan a un único cloud según la variable de repo `CLOUD_PROVIDER` (`azure`|`aws`); los pasos están duplicados con `if: env.CLOUD_PROVIDER == ...`. Al tocar un paso de un cloud, revisar su gemelo. `cd-go-multicloud.yml` (manual) despliega Go en ambos con una sola imagen construida en GHCR y promovida por digest.
- **Lógica de despliegue en `scripts/`**: `deploy-lambda.sh`, `deploy-containerapp.sh` y `smoke-test.sh` los llaman los tres CD. Son idempotentes (create la primera vez, update después) y escriben `url=` en `$GITHUB_OUTPUT`. Cambios de configuración de Lambda/Container App (memoria, réplicas, puerto) van ahí, no en los YAML.
- **Una imagen para todo**: ambos Dockerfiles copian el AWS Lambda Web Adapter a `/opt/extensions/` con `AWS_LWA_PORT` = puerto de la app y `AWS_LWA_READINESS_CHECK_PATH=/health`. Fuera de Lambda es inerte. Si cambia el puerto de una app, actualizar `AWS_LWA_PORT`, `EXPOSE`/`CMD` y el puerto que se pasa a `deploy-containerapp.sh`.
- **Builds para Lambda**: siempre `--platform linux/amd64 --provenance=false --sbom=false` (o `platforms`/`provenance`/`sbom` en `build-push-action`). Lambda rechaza índices OCI con attestations.
- **Python en Azure Functions**: `src/function_app.py` envuelve `app.py` con `func.WsgiFunctionApp` (ruta catch-all, auth anónima) y `host.json` pone `routePrefix: ""` para que no haya `/api`. `app.py` debe seguir sin dependencias de Azure (también corre con Gunicorn en Lambda). `azure-functions` 2.x exige Python ≥ 3.13; si se baja `FUNCTION_PYTHON_VERSION` hay que bajar a la línea 1.x.
- **Qué crea cada workflow**: `infraestructure.yml` crea lo que no depende de una imagen (ACR, Container Apps Environment, Storage + Function App; repos ECR + rol IAM `<ECR_REPOSITORY_NAME>-lambda-role`). La Container App (`<CONTAINER_NAME>-go`) y las Lambdas (`<ECR_REPOSITORY_NAME>` y `<ECR_REPOSITORY_NAME>-go`) las crea el primer CD. Los nombres se derivan de las variables; si se renombra algo, revisar infra, los tres CD y el destroy.
- **Docs como wiki**: `wiki.yml` valida (enlaces con `scripts/build-wiki.sh`, diagramas con `@mermaid-js/mermaid-cli`) y publica `doc/*.md` en `<repo>.wiki.git`. En `doc/` los enlaces se escriben como archivos (`02-Arquitectura.md`, `../src/app.py`, `archivo.json`) y `build-wiki.sh` los reescribe para la wiki (sin `.md` / URLs absolutas `blob/main`), sin tocar código entre backticks. Nombres de página sin tildes ni espacios; una página nueva se añade también a `_Sidebar.md` y a la tabla de `Home.md`. Mermaid: etiquetas entre comillas, `<br/>` para saltos, `classDef` con `color:#1a1a1a`.
- **Workflows endurecidos (GitHub Well-Architected)**: toda action va fijada por SHA completo con comentario `# vX.Y.Z` (Dependabot los actualiza); `permissions: {}` a nivel de workflow y permisos mínimos por job; releases con `gh release create --generate-notes` (categorías en `.github/release.yml`), con los datos de contexto pasados por `env`. Al añadir una action, resolver su SHA (`gh api repos/<owner>/<repo>/git/ref/tags/<tag>`) y seguir este patrón. `.github/CODEOWNERS` usa `@yembertQC`; los rulesets de `.github/rulesets/` se importan a mano en Settings.
- **Triggers**: `cd.yml` solo con `src/**`, `cd-go.yml` solo con `src-go/**`; ambos admiten `workflow_dispatch`. Cambios en `scripts/` o en los workflows no despliegan solos.

## Licencia

MIT (`LICENSE` en la raíz) para todo el proyecto, código y documentación. © Yembert Jesus Quintero Cortez.

## Cuidado

- `src-go/main.go` contiene a propósito credenciales hardcodeadas y endpoints con SQL injection (`/search`) y command injection (`/exec`) para que CodeQL los detecte (documentado en `doc/10-Seguridad.md`). No "arreglarlos" ni eliminarlos salvo que se pida. Quedan expuestos en las URLs públicas.
- `src-go/test.txt` es un archivo de relleno que se edita solo para disparar los workflows de Go.
- Los Dockerfiles contienen `pip install` (dentro de la imagen); un hook local bloquea comandos Bash que contengan ese texto, así que editarlos con Edit/Write, no con heredocs.
