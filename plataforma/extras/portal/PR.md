## Qué propone el team web

Un portal de autoservicio para la plataforma, en `docs/` y publicado con GitHub Pages. No cambia nada de lo que ya funciona: es una cara nueva sobre el mismo IssueOps.

- **Crear:** cada formulario de `.github/ISSUE_TEMPLATE/` aparece como una acción. El portal lo pinta, valida la convención de nombres, las regiones de cada nube y los tamaños permitidos (`config/plataforma.json`) y abre el issue ya relleno. Quien envía el issue sigue siendo la persona, con su sesión de GitHub.
- **Catálogo:** `catalog/catalog.yml` con filtros por team, tecnología y nube.
- **Solicitudes:** los issues de este repo y su estado según la etiqueta `platform/*`.

Sin backend ni tokens: lee la API pública de GitHub (3 consultas por carga).

## Por qué un PR y no un repo nuevo

Seguimos el `CONTRIBUTING`: el código de la plataforma es del team `platform` y cualquier equipo puede proponer cambios. Este PR espera su revisión por `CODEOWNERS`.

## Cómo probarlo antes de fusionar

```bash
gh pr checkout <número> && python3 -m http.server -d docs 8000
# http://localhost:8000/?demo → datos de ejemplo
```

Al fusionar, el portal queda en `https://<org>.github.io/platform/`.
