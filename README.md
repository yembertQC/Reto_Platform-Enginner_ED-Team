# Reto Platform Engineering - ED Team

El **punto de partida** del curso de Platform Engineering: el *golden path* de **un solo equipo**. Los pipelines de GitHub Actions llevan dos APIs mínimas (Python Flask y Go) del `git push` a una URL pública en servicios **serverless** de Azure y AWS, con la seguridad incluida por defecto y sin clusters que administrar.

Funciona, pero todavía **no es una plataforma**: para que otro equipo lo use tendría que copiar el repo y repetir a mano toda la configuración. Convertirlo en una plataforma interna de autoservicio para muchos equipos es lo que se construye en el curso, en repos nuevos y a partir de las piezas de este.

> 📖 **Toda la documentación (con diagramas) está en [`doc/`](doc/Home.md)** y se publica automáticamente en la Wiki del repositorio. Si eres estudiante, empieza por [¿Qué es Ingeniería de Plataforma?](doc/00-Ingenieria-de-Plataforma.md) y luego el [laboratorio paso a paso](doc/08-Laboratorio-Paso-a-Paso.md).

## De este repo a una plataforma

| | Lo que este repo ya resuelve | Lo que le falta para servir a muchos equipos |
|---|------------------------------|-----------------------------------------------|
| 🛤️ **Despliegue** | `cd.yml` / `cd-go.yml`: build → release → deploy → smoke test en cada push | Un pipeline **compartido y versionado** (`workflow_call`) que los demás repos llamen en vez de copiarlo |
| 🙋 **Alta de un servicio** | El [laboratorio](doc/08-Laboratorio-Paso-a-Paso.md): secrets, variables, environment e infraestructura, paso a paso y a mano | **Autoservicio**: un repo plantilla y un formulario de issue que crea el servicio, lo pida una persona o un agente de IA |
| 👥 **Dueños** | `CODEOWNERS` con una sola persona dueña de todo | Un equipo de plataforma y equipos de producto, cada uno dueño de lo suyo |
| 🔐 **Acceso a la nube** | Tres secretos estáticos guardados en el repo | Identidad federada (**OIDC**), sin contraseñas guardadas |
| 🛡️ **Seguridad** | CI DevSecOps con SAST (CodeQL), SCA y escaneo de imagen (Grype); aprobación manual en `production` | Reglas en código que se aplican igual a todos los repos, los toque una persona o un agente |

Lo que la plataforma reutiliza tal cual: los `scripts/` idempotentes que comparten los tres CD, el cambio de nube con una variable (`CLOUD_PROVIDER=azure|aws`) y el despliegue sin registry en la nube (imagen en GHCR para Container Apps, zip para Lambda).

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
| Python | **Azure Functions** (Flex Consumption) — zip con remote build, Flask montado con `WsgiFunctionApp` | **AWS Lambda** — zip (`python3.13`) + Lambda Web Adapter como layer, Function URL |
| Go | **Azure Container Apps** — imagen desde **GitHub Container Registry (GHCR)**, escala 0-10 | **AWS Lambda** — zip con el binario `bootstrap` (`provided.al2023`) + Lambda Web Adapter como layer, Function URL |

Cada servicio entrega su propia URL HTTPS pública y escala a cero cuando no hay tráfico. **No se aprovisiona ningún registry en la nube** (ni ACR ni ECR):

- La imagen de Go se publica en GHCR con el `GITHUB_TOKEN` del workflow y Container Apps la descarga sin credenciales. Para eso el paquete tiene que ser **público**: los paquetes de GHCR nacen privados, así que tras el primer CD de Go hay que cambiarlo una vez en *Package settings → Change visibility → Public*. Si no, el CD se detiene con un aviso y el enlace al paquete.
- Lambda recibe paquetes zip, y el [AWS Lambda Web Adapter](https://github.com/aws/aws-lambda-web-adapter) va como *layer*: el servidor HTTP normal (Gunicorn / `net/http`) corre en Lambda sin cambiar el código.

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
  cd-go-multicloud.yml    # CD Go Multi-Cloud — build único (imagen + zip) → Container Apps + Lambda en paralelo (manual)
  infraestructure.yml     # Infraestructura — create/destroy por cloud (manual)
  infra-multicloud.yml    # Infraestructura Multi-Cloud — dispara Azure + AWS a la vez (manual)
  wiki.yml                # Publica doc/ en la Wiki de GitHub (valida enlaces y diagramas)
scripts/
  deploy-lambda.sh        # Crea/actualiza una Lambda (zip + layer del Web Adapter) + Function URL
  deploy-containerapp.sh  # Crea/actualiza una Azure Container App con una imagen pública de GHCR
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
  run.sh                  # Arranque de Gunicorn dentro de AWS Lambda (handler del zip)
  Dockerfile              # Imagen Python 3.13 + Gunicorn (ejecución local y escaneo del CI)
src-go/
  main.go                 # Aplicación Go
  main_test.go            # Tests unitarios
  Dockerfile              # Imagen multi-stage Go 1.23 (Container Apps y local)
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
- **aws** — empaqueta `app.py`, `run.sh` y las dependencias en un zip y crea/actualiza la Lambda (`python3.13`) con su Function URL.
- Release `v<YYYYMMDD>-<sha-short>`.

### CD Go — `cd-go.yml`
Push a `main` con cambios en `src-go/` (o manual).

```
build (go test -race) → release → deploy (environment: production) + smoke test
```

- **azure** — imagen `ghcr.io/<owner>/<CONTAINER_NAME>-go` en GHCR → Azure Container App `<CONTAINER_NAME>-go`.
- **aws** — binario `bootstrap` en un zip → Lambda `<LAMBDA_NAME>-go` con Function URL.
- Release `go-v<YYYYMMDD>-<sha-short>`.

### CD Go Multi-Cloud — `cd-go-multicloud.yml`
Ejecución **manual**. Construye **una sola vez** la imagen (en GHCR) y el zip de Lambda, y despliega en paralelo: Container Apps por digest y Lambda desde el zip.

```
build_once (imagen GHCR + zip) ──┬── deploy_azure (Container Apps, imagen@digest)
                                 ├── deploy_aws   (Lambda, zip)
                                 └── release (tag go-mc-v<YYYYMMDD>-<sha-short>)
```

### Infraestructura — `infraestructure.yml`
Ejecución **manual**. Seleccionar proveedor (`azure` / `aws`) y acción (`create` / `destroy`).

| Cloud | create | destroy |
|-------|--------|---------|
| Azure | Container Apps Environment, Storage Account y Function App (Flex Consumption, Python) | Borra todo lo anterior y la Container App. Conserva el Resource Group |
| AWS | Rol IAM de ejecución para Lambda | Borra Lambdas, Function URLs, log groups y rol IAM |

Las Container Apps y las Lambdas se crean en el primer despliegue del CD, porque necesitan el artefacto ya construido. Las imágenes de GHCR no se borran con `destroy`: se gestionan desde la pestaña **Packages** de GitHub.

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

> `GITHUB_TOKEN` se genera automáticamente; con él se publica la imagen en GHCR, sin credenciales de registry adicionales.

### Variables de repositorio

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `CLOUD_PROVIDER` | Proveedor destino de `cd.yml` / `cd-go.yml` | `azure` / `aws` |
| `RESOURCE_GROUP` | Resource Group existente | `rg-edteam-platform` |
| `AZURE_LOCATION` | Región de Azure | `eastus` |
| `CONTAINER_NAME` | Nombre base; la Container App Go y su paquete de GHCR son `<CONTAINER_NAME>-go` | `ed-team-app` |
| `CONTAINERAPP_ENV_NAME` | Container Apps Environment | `cae-edteam` |
| `FUNCTION_APP_NAME` | Function App de Python (único global) | `func-edteam-app` |
| `STORAGE_ACCOUNT_NAME` | Storage de la Function App (único global) | `stedteamfunc` |
| `FUNCTION_PYTHON_VERSION` | Opcional, por defecto `3.13` | `3.13` |
| `AWS_REGION` | Región de AWS | `us-east-1` |
| `LAMBDA_NAME` | Nombre base: Lambda Python `<LAMBDA_NAME>`, Lambda Go `<LAMBDA_NAME>-go`, rol IAM `<LAMBDA_NAME>-lambda-role` | `ed-team-app` |

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
