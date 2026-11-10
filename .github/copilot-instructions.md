# Instrucciones para GitHub Copilot

Repositorio de un curso de **Ingeniería de Plataforma**: dos APIs mínimas (Python Flask en `src/`, Go en `src-go/`) desplegadas en serverless (Azure Functions, Azure Container Apps y AWS Lambda) con GitHub Actions. La documentación está en `doc/` (fuente de la wiki) y **se escribe en español**.

## Reglas

- Los despliegues usan los scripts de `scripts/` (`deploy-lambda.sh`, `deploy-containerapp.sh`, `smoke-test.sh`). Cambia la configuración de Lambda o Container Apps ahí, no en los YAML.
- En workflows: fija las actions **por SHA completo** con comentario `# vX.Y.Z`, deja `permissions: {}` a nivel de workflow y declara permisos mínimos **por job**. No uses `pull_request_target`. Pasa los datos de contexto (`${{ ... }}`) por `env`, no dentro de `run`.
- No hay registry en la nube: la imagen de Go va a GHCR (paquete público) para Container Apps, y Lambda recibe paquetes zip con el Lambda Web Adapter como layer.
- `src/app.py` no debe depender de ningún cloud; `src/function_app.py` lo envuelve para Azure Functions.
- `/` debe responder `{"message": "Hola ED Team"}` y `/health` `{"status": "healthy"}`: los verifican los tests de Go y `smoke-test.sh`.
- `src-go/main.go` contiene **vulnerabilidades intencionales** (`/search`, `/exec`, credenciales en constantes) para demostrar CodeQL. No las corrijas ni las copies salvo que se pida explícitamente.
- Nunca añadas secretos al código ni a variables; usa GitHub Secrets.
- Si cambias infraestructura, pipelines o apps, actualiza la página correspondiente de `doc/` en el mismo cambio. En `doc/`, enlaza archivos `.md` (los convierte `scripts/build-wiki.sh`) y escribe los diagramas en Mermaid con etiquetas entre comillas y `<br/>`.
- Python: usa `uv` (`uv run`, `uvx`), nunca `pip install` global.
