
# Reto DevSecOps - ED Team

Dos APIs (Python Flask y Go) con pipeline DevSecOps completo sobre GitHub Actions: análisis de seguridad estático y de contenedor, y despliegue automatizado en servicios **serverless** de Azure y AWS (sin clusters que administrar).

> 📖 **Toda la documentación (con diagramas) está en [`doc/`](doc/Home.md)** y se publica automáticamente en la Wiki del repositorio. Si eres estudiante, empieza por [doc/Home.md](doc/Home.md) y el [laboratorio paso a paso](doc/08-Laboratorio-Paso-a-Paso.md).

## APIs

Ambas APIs exponen los mismos endpoints:

| Endpoint | Respuesta |
|----------|-----------|
| `GET /` | `{"message": "Hola ED Team"}` |
| `GET /health` | `{"status": "healthy"}` |

| App | Lenguaje | Puerto local | Directorio |
|-----|----------|--------------|------------|
| Python (Flask + Gunicorn) | Python 3.13 | 5000 | `src/` |
| Go (net/http) | Go 1.23 | 8080 | `src-go/` |

## Dónde corre cada app

| App | Azure | AWS |
|-----|-------|-----|
| Python | **Azure Functions** (Flex Consumption) — Flask montado con `WsgiFunctionApp` | **AWS Lambda** — imagen de contenedor + Lambda Web Adapter, Function URL |
| Go | **Azure Container Apps** — imagen desde ACR, escala 0-10 | **AWS Lambda** — imagen de contenedor + Lambda Web Adapter, Function URL |

Cada servicio entrega su propia URL HTTPS pública y escala a cero cuando no hay tráfico. Los Dockerfiles incluyen el [AWS Lambda Web Adapter](https://github.com/aws/aws-lambda-web-adapter), así la misma imagen funciona en Lambda, en Container Apps y en local sin cambiar el código.

## Estructura del proyecto

```
.github/
  CODEOWNERS · dependabot.yml · SECURITY.md · CONTRIBUTING.md · CODE_OF_CONDUCT.md · SUPPORT.md
  pull_request_template.md · ISSUE_TEMPLATE/ · release.yml · copilot-instructions.md
  rulesets/               # Protección de main y de tags (para importar en Settings → Rules)
.github/workflows/
  ci.yml                  # CI Python — SAST, SCA, escaneo de imagen
  ci-go.yml               # CI Go — tests, SAST, SCA, escaneo de imagen
  cd.yml                  # CD Python — Azure Functions o Lambda (según CLOUD_PROVIDER)
  cd-go.yml               # CD Go — Container Apps o Lambda (según CLOUD_PROVIDER)
  cd-go-multicloud.yml    # CD Go Multi-Cloud — build único → Container Apps + Lambda en paralelo (manual)
  infraestructure.yml     # Infraestructura — create/destroy por cloud (manual)
  infra-multicloud.yml    # Infraestructura Multi-Cloud — dispara Azure + AWS a la vez (manual)
  wiki.yml                # Publica doc/ en la Wiki de GitHub (valida enlaces y diagramas)
scripts/
  deploy-lambda.sh        # Crea/actualiza una Lambda (imagen ECR) + Function URL
  deploy-containerapp.sh  # Crea/actualiza una Azure Container App
  smoke-test.sh           # Verifica /health y / de una URL pública con reintentos
  build-wiki.sh           # Genera la wiki desde doc/ y valida enlaces
doc/
  Home.md, 00-…14-*.md             # Wiki del curso (fuente; se publica con wiki.yml)
  _Sidebar.md, _Footer.md          # Menú y pie de la wiki
  azure-credentials-example.json   # Ejemplo del secret AZURE_CREDENTIALS
  azure-variables-example.json     # Ejemplo de variables para Azure
  aws-variables-example.json       # Ejemplo de variables para AWS
src/
  app.py                  # Aplicación Flask
  function_app.py         # Entrada de Azure Functions (envuelve app.py vía WSGI)
  host.json               # Config de Functions (sin prefijo /api)
  requirements.txt        # Flask, Gunicorn, azure-functions
  Dockerfile              # Imagen Python 3.13 + Gunicorn + Lambda Web Adapter
src-go/
  main.go                 # Aplicación Go
  main_test.go            # Tests unitarios
  Dockerfile              # Imagen multi-stage Go 1.23 + Lambda Web Adapter
```

## Pipelines

### CI Python — `ci.yml` / CI Go — `ci-go.yml`
Se ejecutan en push y PR a `main` cuando hay cambios en `src/` o `src-go/` respectivamente.

| Job | Herramienta | Cuándo |
|-----|-------------|--------|
| Test (solo Go) | `go test -v -race ./...` | siempre |
| SAST | CodeQL (queries `security-extended`) | siempre |
| SCA | `dependency-review-action` | solo PRs |
| Container Security | Anchore/Grype → SARIF a GitHub Security | siempre |

### CD Python — `cd.yml`
Push a `main` con cambios en `src/` (o manual). Cloud destino según `CLOUD_PROVIDER`.

```
build → release → deploy (environment: production) + smoke test
```

- **azure** — empaqueta `src/` en un zip y lo despliega en la Function App con remote build.
- **aws** — construye `src/Dockerfile`, lo publica en ECR y crea/actualiza la Lambda con su Function URL.
- Release `v<YYYYMMDD>-<sha-short>`.

### CD Go — `cd-go.yml`
Push a `main` con cambios en `src-go/` (o manual).

```
buildImage (go test -race) → release → deploy (environment: production) + smoke test
```

- **azure** — imagen en ACR → Azure Container App `<CONTAINER_NAME>-go`.
- **aws** — imagen en ECR → Lambda `<ECR_REPOSITORY_NAME>-go` con Function URL.
- Release `go-v<YYYYMMDD>-<sha-short>`.

### CD Go Multi-Cloud — `cd-go-multicloud.yml`
Ejecución **manual**. Construye la imagen **una sola vez** en GHCR, la promueve por digest a ACR y ECR, y despliega en paralelo en Container Apps y Lambda.

```
build_once (GHCR) ──┬── promote_azure (ACR) ── deploy_azure (Container Apps)
                    ├── promote_aws   (ECR) ── deploy_aws   (Lambda)
                    └── release (tag go-mc-v<YYYYMMDD>-<sha-short>)
```

### Infraestructura — `infraestructure.yml`
Ejecución **manual**. Seleccionar proveedor (`azure` / `aws`) y acción (`create` / `destroy`).

| Cloud | create | destroy |
|-------|--------|---------|
| Azure | ACR, Container Apps Environment, Storage Account y Function App (Flex Consumption, Python) | Borra todo lo anterior y la Container App. Conserva el Resource Group |
| AWS | Repos ECR (Python y Go) y rol IAM de ejecución para Lambda | Borra Lambdas, Function URLs, log groups, repos ECR y rol IAM |

Las Container Apps y las Lambdas se crean en el primer despliegue del CD, porque necesitan una imagen ya publicada.

### Infraestructura Multi-Cloud — `infra-multicloud.yml`
Ejecución **manual**. Dispara `infraestructure.yml` simultáneamente para Azure y AWS.

### Wiki — `wiki.yml`
Push a `main` con cambios en `doc/` (o manual). Valida enlaces y diagramas Mermaid (también en PRs) y publica `doc/` en la Wiki del repositorio. Requiere tener la Wiki activada y una primera página creada a mano. Detalle en [doc/11-Publicar-la-Wiki.md](doc/11-Publicar-la-Wiki.md).

## Configuración

Configura todo en **GitHub → Settings → Secrets and variables → Actions**. Guía completa paso a paso (secrets, variables, permisos y environments): [doc/07-Configuracion-GitHub.md](doc/07-Configuracion-GitHub.md)

### Secrets

| Secret | Proveedor | Descripción |
|--------|-----------|-------------|
| `AZURE_CREDENTIALS` | Azure | JSON del Service Principal (ver `doc/azure-credentials-example.json`) |
| `AWS_ACCESS_KEY_ID` | AWS | Access Key ID de IAM |
| `AWS_SECRET_ACCESS_KEY` | AWS | Secret Access Key de IAM |

> `GITHUB_TOKEN` se genera automáticamente.

### Variables de repositorio

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `CLOUD_PROVIDER` | Proveedor destino de `cd.yml` / `cd-go.yml` | `azure` / `aws` |
| `RESOURCE_GROUP` | Resource Group existente | `rg-edteam-devsecops` |
| `AZURE_LOCATION` | Región de Azure | `eastus` |
| `REGISTRY_NAME` | Nombre del ACR (sin `.azurecr.io`) | `acredteamdevsecops` |
| `CONTAINER_NAME` | Nombre base; la Container App Go es `<CONTAINER_NAME>-go` | `ed-team-app` |
| `CONTAINERAPP_ENV_NAME` | Container Apps Environment | `cae-edteam` |
| `FUNCTION_APP_NAME` | Function App de Python (único global) | `func-edteam-app` |
| `STORAGE_ACCOUNT_NAME` | Storage de la Function App (único global) | `stedteamfunc` |
| `FUNCTION_PYTHON_VERSION` | Opcional, por defecto `3.13` | `3.13` |
| `AWS_REGION` | Región de AWS | `us-east-1` |
| `ECR_REPOSITORY_NAME` | Base para repos ECR, Lambdas y rol IAM | `ed-team-app` |

### Environments de GitHub

- `production` (obligatorio, lo usan los jobs `deploy` de `cd.yml` y `cd-go.yml`): permitir solo `main` y al menos 1 revisor.
- `desarrollo` (opcional).

## Ejecución local

### Python

```bash
cd src
uv run --with-requirements requirements.txt python app.py
# http://localhost:5000

# Como Azure Function (requiere Azure Functions Core Tools)
func start
```

### Go

```bash
cd src-go
go run main.go
# http://localhost:8080

go test -v -race ./...
```

### Docker

```bash
# Python
docker build -t ed-team-app src/
docker run -p 5000:5000 ed-team-app

# Go
docker build -t ed-team-app-go src-go/
docker run -p 8080:8080 ed-team-app-go
```

## Licencia

Todo el proyecto (código y documentación, incluida la wiki) está bajo la licencia [MIT](LICENSE). © 2026 Yembert Jesus Quintero Cortez

> ⚠️ `src-go/main.go` contiene **vulnerabilidades intencionales** con fines educativos. El código se entrega "tal cual" (sin garantías): no lo uses en producción.
