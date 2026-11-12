# plataforma/

Lo que se entrega a una organización de GitHub para que tenga su plataforma interna: pedir un servicio con un issue y tenerlo desplegado sin tocar la nube.

El resto de este repo (la raíz) es el reto: el "antes", un solo equipo desplegando a mano su golden path. Esta carpeta es el "después" y no se despliega desde aquí.

```bash
gh auth login                           # como owner de la organización
bash plataforma/bootstrap.sh <tu-org>   # crea teams y los siete repos; idempotente
```

| Carpeta | Repo en la org | Qué es |
|---|---|---|
| `repos/org-profile/` | `.github` | Portada de la organización con el enlace al formulario |
| `repos/pipelines/` | `pipelines` | `build.yml@v1`: tests, artefacto y despliegue para Go y Python, en Azure o AWS. `bootstrap.sh` le añade `scripts/` de la raíz |
| `repos/template-go/` | `template-go` | Plantilla de servicio en Go (marcada como template) |
| `repos/template-python/` | `template-python` | Plantilla de servicio en Python (marcada como template) |
| `repos/platform/` | `platform` | El orquestador: formulario, `issueops.yml`, `platformctl`, configuración y política OPA |
| `repos/catalog/` | `catalog` | `catalog.yml`: qué servicios hay y de quién son |
| `repos/portal/` | `portal` | La cara de la IDP en GitHub Pages: acciones de autoservicio (los formularios de `platform`), catálogo y solicitudes. Sin backend: abre el issue ya relleno |

## Una petición, de principio a fin

1. Alguien abre un issue en `platform` con el formulario: nombre, team, tecnología (`go`/`python`), nube (`azure`/`aws`) y región.
2. `platformctl` valida: autor miembro, nombre con la convención, team existente, región permitida para esa nube, repo inexistente.
3. Crea el repo desde `template-<tecnología>`, da `write` al team, pone `CLOUD_PROVIDER`, la región y `SERVICE_TEAM` como variables del repo y escribe `CODEOWNERS`.
4. Añade la fila al catálogo, contesta en el issue y lo cierra.
5. El commit de `CODEOWNERS` dispara `deploy.yml`, que llama a `pipelines/build.yml@v1`: Container Apps en Azure (imagen privada en GHCR) o Lambda con Function URL en AWS.

## Qué no hace `bootstrap.sh`

Credenciales y decisiones de la organización: secretos de nube, el token de solo lectura de GHCR, la GitHub App de la plataforma y la infraestructura compartida (resource group y Container Apps Environment en Azure; rol de ejecución de Lambda en AWS). Al terminar imprime los comandos que faltan.

## Probar sin GitHub

```bash
(cd plataforma/repos/platform && go test ./...)
(cd plataforma/repos/template-go && go test -race ./...)
(cd plataforma/repos/template-python && uv run --no-project --with-requirements requirements-dev.txt python -m pytest -q)
uvx --from actionlint-py actionlint plataforma/repos/*/.github/workflows/*.yml
```
