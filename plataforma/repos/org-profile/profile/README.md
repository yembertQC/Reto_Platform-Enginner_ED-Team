## Plataforma de __ORG__

¿Necesitas un servicio nuevo? **[Entra al portal](https://__ORG__.github.io/portal/)** o [pídelo directamente con el formulario](https://github.com/__ORG__/platform/issues/new?template=nuevo-servicio.yml): nombre, team, tecnología, nube y región. La plataforma lo valida, crea el repo, le da permisos a tu team y lo despliega. Te contesta en el mismo issue.

| Repo | Qué es | Dueño |
|---|---|---|
| [`platform`](https://github.com/__ORG__/platform) | El formulario y quien lo atiende (`platformctl`) | team `platform` |
| [`pipelines`](https://github.com/__ORG__/pipelines) | El camino a producción: `build.yml@v1` | team `platform` |
| [`template-go`](https://github.com/__ORG__/template-go) | Plantilla de servicio en Go | team `platform` |
| [`template-python`](https://github.com/__ORG__/template-python) | Plantilla de servicio en Python | team `platform` |
| [`catalog`](https://github.com/__ORG__/catalog) | Qué servicios hay y de quién son | team `platform` |
| [`portal`](https://github.com/__ORG__/portal) | La cara de la plataforma: crear, catálogo y solicitudes | team `platform` |

Los servicios son de sus teams. La plataforma es dueña del camino a producción, no del código.
