# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Qué es este repo

Reto de **Platform Engineering** (material de curso de Ingeniería de Plataforma): es la **base demo / punto de partida** del curso, no la plataforma terminada: el *golden path* de un solo equipo (el "antes", Nivel 1). La plataforma (pipeline reutilizable, repo plantilla, IssueOps, teams, OIDC/OPA) se construye en el curso en repos nuevos de una organización, a partir de piezas de este (`cd-go.yml`, `scripts/`, `src-go/`); no añadirla aquí. Dos APIs mínimas e idénticas en comportamiento (`GET /` → `{"message": "Hola ED Team"}`, `GET /health` → `{"status": "healthy"}`); el valor real está en los pipelines (CI DevSecOps con SAST/SCA/escaneo de imagen como capa de seguridad + despliegue **serverless** en Azure y AWS). Al documentar, no presentar el repo como una IDP ya hecha: decir qué resuelve ya y qué le falta para servir a muchos equipos (ver `doc/00-Ingenieria-de-Plataforma.md`, sección "¿Dónde está este repo?"); DevSecOps es solo la parte de seguridad del CI. La mayor parte del trabajo se hace en `.github/workflows/` y `scripts/`, no en el código de las apps. Documentación en español; mantener ese idioma.

| App | Azure | AWS |
|-----|-------|-----|
| `src/` Python 3.13 Flask (puerto 5000) | Azure Functions Flex Consumption (zip + remote build) | Lambda zip `python3.13` (handler `run.sh`) + Function URL |
| `src-go/` Go 1.23 (puerto 8080) | Azure Container Apps (imagen pública en GHCR) | Lambda zip `provided.al2023` (binario `bootstrap`) + Function URL |

Ya no hay Kubernetes (AKS/EKS, manifiestos, Traefik) ni registries en la nube (ACR/ECR): se eliminaron a propósito. No volver a añadirlos.

- Toda la documentación vive en `doc/` (fuente de la Wiki de GitHub): `Home.md` + páginas `00-…14-*.md` (0 = qué es Ingeniería de Plataforma, 13 = qué NO hacer, 14 = buenas prácticas de GitHub), `_Sidebar.md`, `_Footer.md`. No hay `ARCHITECTURE.md` en la raíz.

## Comandos

```bash
# Go
cd src-go && go run main.go                          # http://localhost:8080
cd src-go && go test -v -race ./...                  # lo mismo que corre CI
cd src-go && go test -v -run TestHealthHandler ./... # un solo test

# Python (usar uv, no pip global)
cd src && uv run --with-requirements requirements.txt python app.py   # http://localhost:5000

# Docker (la imagen de Go es la que va a Container Apps; la de Python es solo local/CI)
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

- **Selección de cloud**: `cd.yml` y `cd-go.yml` despliegan a un único cloud según la variable de repo `CLOUD_PROVIDER` (`azure`|`aws`); los pasos están duplicados con `if: env.CLOUD_PROVIDER == ...`. Al tocar un paso de un cloud, revisar su gemelo. `cd-go-multicloud.yml` (manual) construye una vez (imagen en GHCR + zip) y despliega Go en ambos: Container Apps por digest, Lambda desde el zip.
- **Lógica de despliegue en `scripts/`**: `deploy-lambda.sh`, `deploy-containerapp.sh` y `smoke-test.sh` los llaman los tres CD; `destroy-azure.sh` y `destroy-aws.sh`, el `destroy` de `infraestructure.yml` y `destroy-all.yml` (borrado de todo con confirmación `ELIMINAR`; conserva el RG y GHCR). Son idempotentes (create la primera vez, update después) y escriben `url=` en `$GITHUB_OUTPUT`. Cambios de configuración de Lambda/Container App (memoria, réplicas, puerto) van ahí, no en los YAML.
- **Sin registry en la nube**: la imagen de Go se publica en GHCR (`ghcr.io/<owner en minúsculas>/<CONTAINER_NAME>-go:<sha>`, con `GITHUB_TOKEN` y `packages: write`) y Container Apps la descarga **anónimamente**: el paquete debe ser público (nace privado; se cambia una vez a mano). `deploy-containerapp.sh` lo comprueba antes de desplegar y falla con el enlace al paquete. No borrar imágenes de GHCR en los workflows: Container Apps las vuelve a descargar al escalar desde cero.
- **Lambda con zip + layer**: `deploy-lambda.sh <nombre> <zip> <rol> <runtime> <handler> <puerto>` adjunta la layer del AWS Lambda Web Adapter (`LambdaAdapterLayerX86`, versión en `LWA_LAYER_VERSION`, por defecto 30) y fija `PORT`/`AWS_LWA_PORT`/`AWS_LWA_READINESS_CHECK_PATH=/health`; en runtimes gestionados añade `AWS_LAMBDA_EXEC_WRAPPER=/opt/bootstrap`. Go: binario `bootstrap` (`CGO_ENABLED=0 GOOS=linux GOARCH=amd64`). Python: `pip --target` con `--platform manylinux2014_x86_64` + `app.py` + `src/run.sh` (excluido del zip de Azure Functions y de `.funcignore`). Si una Lambda existía como imagen, el script la recrea como zip (cambia su Function URL). Si cambia el puerto de una app, actualizar `EXPOSE`/`CMD`, `run.sh`/`main.go` y el puerto que se pasa a los dos scripts.
- **Imagen de Go**: `--platform linux/amd64 --provenance=false --sbom=false` (un solo manifiesto linux/amd64) y la etiqueta `org.opencontainers.image.source` para enlazar el paquete con el repo. Los Dockerfiles ya no llevan el Lambda Web Adapter; `src/Dockerfile` solo sirve para local y para el escaneo del CI.
- **Python en Azure Functions**: `src/function_app.py` envuelve `app.py` con `func.WsgiFunctionApp` (ruta catch-all, auth anónima) y `host.json` pone `routePrefix: ""` para que no haya `/api`. `app.py` debe seguir sin dependencias de Azure (también corre con Gunicorn en Lambda vía `run.sh`). `azure-functions` 2.x exige Python ≥ 3.13; si se baja `FUNCTION_PYTHON_VERSION` hay que bajar a la línea 1.x.
- **Qué crea cada workflow**: `infraestructure.yml` crea lo que no depende del artefacto (Container Apps Environment, Storage + Function App; rol IAM `<LAMBDA_NAME>-lambda-role`). La Container App (`<CONTAINER_NAME>-go`) y las Lambdas (`<LAMBDA_NAME>` y `<LAMBDA_NAME>-go`) las crea el primer CD. Los nombres se derivan de las variables; si se renombra algo, revisar infra, los tres CD, `destroy-all.yml` y los scripts `destroy-*.sh`.
- **Docs como wiki**: `wiki.yml` valida (enlaces con `scripts/build-wiki.sh`, diagramas con `@mermaid-js/mermaid-cli`) y publica `doc/*.md` en `<repo>.wiki.git`. En `doc/` los enlaces se escriben como archivos (`02-Arquitectura.md`, `../src/app.py`, `archivo.json`) y `build-wiki.sh` los reescribe para la wiki (sin `.md` / URLs absolutas `blob/main`), sin tocar código entre backticks. Nombres de página sin tildes ni espacios; una página nueva se añade también a `_Sidebar.md` y a la tabla de `Home.md`. Mermaid: etiquetas entre comillas, `<br/>` para saltos, `classDef` con `color:#1a1a1a`.
- **Workflows endurecidos (GitHub Well-Architected)**: toda action va fijada por SHA completo con comentario `# vX.Y.Z` (Dependabot los actualiza); `permissions: {}` a nivel de workflow y permisos mínimos por job; releases con `gh release create --generate-notes` (categorías en `.github/release.yml`), con los datos de contexto pasados por `env`. Al añadir una action, resolver su SHA (`gh api repos/<owner>/<repo>/git/ref/tags/<tag>`) y seguir este patrón. `.github/CODEOWNERS` usa `@yembertQC`; los rulesets de `.github/rulesets/` se importan a mano en Settings.
- **Triggers**: `cd.yml` solo con `src/**`, `cd-go.yml` solo con `src-go/**`; ambos admiten `workflow_dispatch`. Cambios en `scripts/` o en los workflows no despliegan solos.

## Licencia

MIT (`LICENSE` en la raíz) para todo el proyecto, código y documentación. © Yembert Jesus Quintero Cortez.

## Cuidado

- `src-go/main.go` contiene a propósito credenciales hardcodeadas y endpoints con SQL injection (`/search`) y command injection (`/exec`) para que CodeQL los detecte (documentado en `doc/10-Seguridad.md`). No "arreglarlos" ni eliminarlos salvo que se pida. Quedan expuestos en las URLs públicas.
- `src-go/test.txt` es un archivo de relleno que se edita solo para disparar los workflows de Go.
- Los Dockerfiles contienen `pip install` (dentro de la imagen); un hook local bloquea comandos Bash que contengan ese texto, así que editarlos con Edit/Write, no con heredocs.
