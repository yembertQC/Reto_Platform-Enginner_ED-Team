# platform

El orquestador de la plataforma: convierte un issue en un servicio desplegado.

```text
issue (formulario) → issueops.yml → platformctl: parse → validate → execute → report
                                                              │
                         repo desde template-<tecnología> ◄───┘ + team, variables, CODEOWNERS, catálogo
                                         │
                         deploy.yml → pipelines/build.yml@v1 → Azure Container Apps | AWS Lambda
```

| Ruta | Qué es |
|---|---|
| `.github/ISSUE_TEMPLATE/nuevo-servicio.yml` | El formulario: nombre, team, tecnología, nube, región y para qué es. |
| `.github/workflows/issueops.yml` | Lanza `platformctl` con el token de la GitHub App. |
| `cmd/platformctl/` | `parse`, `validate`, `execute`, `report`. Solo librería estándar de Go. |
| `config/plataforma.json` | Lo que la plataforma ofrece hoy: plantillas, nubes y regiones permitidas, teams reservados. |
| `policy/repo.rego` | Las mismas reglas que `validate` en Go, como política OPA. Apagada hasta M2 · Clase 3. |

## Ofrecer algo nuevo

- **Otra región:** añádela en `config/plataforma.json` y en las opciones del formulario. En Azure tiene que existir un Container Apps Environment allí.
- **Otra tecnología:** crea `template-<tecnología>` con `deploy.yml` llamando a `pipelines`, añade la entrada en `plantillas` y en el formulario, y el lenguaje en `pipelines/build.yml`.
- **Encender OPA:** variable de organización `POLICY_ENABLED=true`. `opa test policy/ config/plataforma.json -v` prueba la política.

## La GitHub App

`platformctl` no usa el `GITHUB_TOKEN`: ese token solo sirve dentro de este repo. Usa una GitHub App instalada en la organización con estos permisos:

| Permiso | Nivel | Para qué |
|---|---|---|
| Repository · Administration | Read and write | Crear repos desde plantilla y dar acceso a teams |
| Repository · Contents | Read and write | CODEOWNERS y `catalog.yml` |
| Repository · Issues | Read and write | Comentar, etiquetar y cerrar |
| Repository · Variables | Read and write | `CLOUD_PROVIDER`, región y `SERVICE_TEAM` del repo nuevo |
| Repository · Workflows | Read and write | El repo nuevo trae `.github/workflows/deploy.yml` |
| Organization · Members | Read only | Saber si el autor es miembro y qué teams existen |

Variable de organización `PLATFORM_APP_CLIENT_ID` y secreto `PLATFORM_APP_PRIVATE_KEY`.

## En local

```bash
go test ./...   # parse y reglas, sin llamar a GitHub
```
