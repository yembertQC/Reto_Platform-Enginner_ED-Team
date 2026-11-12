# plataforma/

Lo que se entrega a una organización de GitHub para que tenga su plataforma interna: pedir un servicio con un issue y tenerlo desplegado sin tocar la nube.

El resto de este repo (la raíz) es el reto: el "antes", un solo equipo desplegando su golden path. Esta carpeta es la **plantilla del curso**, el "después", y no se despliega desde aquí.

```bash
gh auth login                                        # como owner de la organización
bash plataforma/bootstrap.sh <tu-org>                # M1 · Clase 3: lo que viene hecho
bash plataforma/bootstrap.sh <tu-org> --completo     # con las soluciones del curso ya puestas
bash plataforma/bootstrap.sh <tu-org> --completo --portal   # + el extra InnerSource
```

## Tres carpetas

| Carpeta | Qué es |
|---|---|
| `repos/` | Lo que viene hecho. Cada subcarpeta es uno de los **seis repos** de la organización. |
| `soluciones/` | Lo que construye el alumno, con la misma estructura de carpetas. `--completo` lo copia encima de `repos/`. |
| `extras/portal/` | El portal de autoservicio, propuesto como pull request al repo `platform` (InnerSource). |

## Los seis repos

| Carpeta | Repo | Viene hecho | Lo construyes tú (y está en `soluciones/`) |
|---|---|---|---|
| `org-profile/` | `.github` | Portada de la organización | — |
| `pipelines/` | `pipelines` | README, CONTRIBUTING, `scripts/` (los copia `bootstrap.sh` desde la raíz) | `build.yml` reutilizable y el tag `v1` (M1 · C4); `CODEOWNERS` (M1 · C5) |
| `template-go/` | `template-go` | Plantilla Go con `deploy.yml` de ocho líneas | — |
| `template-python/` | `template-python` | Plantilla Python con `deploy.yml` de ocho líneas | — |
| `platform/` | `platform` | `issueops.yml`, `platformctl`, `config/plataforma.json`, `policy/repo.rego` apagada | `CODEOWNERS` (M1 · C5); el formulario (M1 · C6) |
| `catalog/` | `catalog` | `catalog.yml` vacío | `CODEOWNERS` (M1 · C5) |

Fuera de los archivos: los teams `platform`, `pagos` y `web` (M1 · C5, `--completo` los crea) y, en M2 · Clase 3, las variables `PRODUCTION_REVIEWERS=platform` (production exige aprobación) y `POLICY_ENABLED=true` (la regla OPA decide).

## Una petición, de principio a fin

1. Alguien (persona o agente de IA) abre un issue en `platform` con el formulario: nombre, team, tecnología (`go`/`python`), nube (`azure`/`aws`), región, ambiente (`dev`/`production`) y tamaño (`pequeño`/`mediano`/`grande`).
2. `platformctl` valida con `config/plataforma.json`: autor miembro, nombre con la convención (3 a 27 caracteres), team existente, región permitida para esa nube, tamaño permitido (`grande` no), repo inexistente.
3. Crea el repo desde `template-<tecnología>`, da `write` al team y le pone variables: nube, región, ambiente, CPU y memoria. Si el ambiente es `production` y existe `PRODUCTION_REVIEWERS`, crea el environment con aprobación obligatoria.
4. Escribe `CODEOWNERS` (ese commit dispara el despliegue; cancela el del commit inicial, que llegó antes que las variables), añade la fila al catálogo, contesta en el issue y lo cierra.
5. `deploy.yml` llama a `pipelines/build.yml@v1`: Container Apps en Azure (imagen privada en GHCR) o Lambda con Function URL en AWS, como `<nombre>-dev` o `<nombre>-prod`.

## Qué no hace `bootstrap.sh`

Credenciales y decisiones de la organización: secretos de nube, el token de solo lectura de GHCR, la GitHub App de la plataforma y la infraestructura compartida (resource group y Container Apps Environment en Azure; rol de ejecución de Lambda en AWS). Al terminar imprime los comandos que faltan.

## Probar sin GitHub

```bash
(cd plataforma/repos/platform && go test ./...)
(cd plataforma/repos/template-go && go test -race ./...)
(cd plataforma/repos/template-python && uv run --no-project --with-requirements requirements-dev.txt python -m pytest -q)
uvx --from actionlint-py actionlint plataforma/repos/*/.github/workflows/*.yml plataforma/soluciones/*/.github/workflows/*.yml
uv run --no-project python -m http.server -d plataforma/extras/portal/docs 8000   # http://localhost:8000/?demo
```
