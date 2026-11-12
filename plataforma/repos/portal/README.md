# portal

La cara de la plataforma: una web estática en GitHub Pages (`https://<org>.github.io/portal/`) con tres vistas.

| Vista | De dónde sale |
|---|---|
| **Crear** | Cada formulario de `platform/.github/ISSUE_TEMPLATE/` es una acción de autoservicio. El portal lo pinta, valida la convención de nombres y qué regiones admite cada nube (`platform/config/plataforma.json`) y abre el issue en GitHub ya relleno. |
| **Catálogo** | `catalog/catalog.yml`, con filtros por team, tecnología y nube. |
| **Solicitudes** | Los issues de `platform` y su estado según la etiqueta `platform/*`. |

## Por qué no tiene backend

El portal no crea nada: prepara la petición y la persona la envía con su propia sesión de GitHub. Así no hay tokens en el navegador, el autor del issue es quien pidió el servicio (`platformctl` comprueba que sea miembro) y el flujo sigue siendo IssueOps: el issue queda como registro y conversación.

Un formulario nuevo en `platform/.github/ISSUE_TEMPLATE/` aparece como acción nueva sin tocar el portal.

## Límites

- Lee la API pública de GitHub sin sesión: 60 consultas por hora por IP. Cada carga usa 3.
- Los repos `platform` y `catalog` tienen que ser públicos.
- GitHub documenta que los campos de texto de un formulario se pueden rellenar por URL; si un desplegable no llega relleno, se elige en GitHub antes de enviar.

## Probar

```bash
uv run --no-project python -m http.server -d . 8000    # o cualquier servidor estático
# http://localhost:8000/?demo  → datos de ejemplo de demo.json
```

`bootstrap.sh` crea este repo, sustituye `__ORG__` en `config.js` y activa GitHub Pages desde `main`.
