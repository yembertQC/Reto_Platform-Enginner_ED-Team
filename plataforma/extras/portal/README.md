# Extra · El portal, una contribución InnerSource

El Módulo 1 termina en "autoservicio sin portal": un formulario de issue ya es autoservicio. Este extra muestra el paso siguiente y, a la vez, el modelo InnerSource de M1 · Clase 5: **un equipo de producto (el team `web`) le propone a la plataforma una cara web con un pull request**, siguiendo el `CONTRIBUTING`, y el team `platform` lo revisa porque es `CODEOWNER`.

```bash
bash plataforma/bootstrap.sh <org> --completo --portal   # abre el PR en <org>/platform
```

El PR añade `docs/` al repo `platform`. Al fusionarlo, GitHub Pages lo publica en `https://<org>.github.io/platform/`. El texto del PR está en `PR.md`.

## Qué hace

| Vista | De dónde sale |
|---|---|
| **Crear** | Cada formulario de `platform/.github/ISSUE_TEMPLATE/` es una acción. Pinta el formulario, desactiva lo que la plataforma rechazaría según `config/plataforma.json` (región de otra nube, tamaño no permitido) y abre el issue en GitHub ya relleno. |
| **Catálogo** | `catalog/catalog.yml`, con filtros por team, tecnología y nube. |
| **Solicitudes** | Los issues de `platform` y su estado según la etiqueta `platform/*`. |

Un formulario nuevo en `ISSUE_TEMPLATE/` aparece como acción nueva sin tocar el portal.

## Por qué no tiene backend

El portal no crea nada: prepara la petición y la persona la envía con su propia sesión de GitHub. No hay tokens en el navegador, el autor del issue es quien pidió el servicio y la plataforma sigue siendo IssueOps: el portal es solo una cara.

## Límites

- Lee la API pública de GitHub sin sesión: 60 consultas por hora por IP; cada carga usa 3.
- `platform` y `catalog` tienen que ser públicos.
- GitHub documenta que los campos de texto se pueden rellenar por URL; si un desplegable llega vacío, se elige en GitHub antes de enviar.

## Probar sin organización

```bash
uv run --no-project python -m http.server -d plataforma/extras/portal/docs 8000
# http://localhost:8000/?demo → datos de ejemplo de demo.json
```

`demo.json` se regenera desde los archivos reales (formulario de `soluciones/` y `config/plataforma.json`).
