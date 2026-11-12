# pipelines

El golden path de la organización: un workflow reutilizable que prueba, construye y despliega cualquier servicio creado desde `template-go` o `template-python`.

## Cómo se usa

Los repos de servicio ya lo traen en `.github/workflows/deploy.yml`:

```yaml
jobs:
  deploy:
    uses: __ORG__/pipelines/.github/workflows/build.yml@v1
    secrets: inherit
    with:
      service: ${{ github.event.repository.name }}
      language: go          # o python
      environment: dev      # o production
      version: 1.0.0
```

| Input | Obligatorio | Qué es |
|---|---|---|
| `service` | sí | Nombre del servicio. El recurso desplegado se llama `<service>-<environment>`. |
| `language` | no (`go`) | `go` o `python`. |
| `environment` | no (`dev`) | `dev` o `production`. Environment de GitHub del job de deploy (production puede exigir aprobación) y sufijo del recurso: `<service>-dev` o `<service>-prod`. |
| `version` | sí | Va en el tag de la imagen: `<version>-<sha corto>`. |

La nube y el tamaño **no** son inputs: salen de las variables del repo que pone `platformctl` según lo que se pidió en el issue (`CLOUD_PROVIDER`, `CONTAINERAPP_CPU`, `CONTAINERAPP_MEMORY`, `LAMBDA_MEMORY`) o, si el repo no las tiene, de la organización y de los valores por defecto de los scripts.

`build.yml` no viene en la plantilla del curso: lo generas en M1 · Clase 4 desde `cd-go.yml` del reto. La solución está en `plataforma/soluciones/pipelines/`.

## Qué necesita la organización

| Nube | Secretos | Variables |
|---|---|---|
| Azure | `AZURE_CREDENTIALS`, `GHCR_PULL_TOKEN` | `RESOURCE_GROUP`, `CONTAINERAPP_ENV_NAME`, `GHCR_PULL_USER` |
| AWS | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | `LAMBDA_ROLE_NAME` |

`AZURE_LOCATION` o `AWS_REGION` la pone `platformctl` en cada repo.

## Versionado

Los servicios fijan `@v1`. Un cambio compatible se publica moviendo el tag `v1`; uno que rompe el contrato va en `v2` y los servicios migran cuando quieren. Ver `CONTRIBUTING.md`.

`scripts/` es una copia de `scripts/` del repo del reto que mete `bootstrap.sh` al crear este repo. Si cambia allí, se vuelve a copiar aquí.
