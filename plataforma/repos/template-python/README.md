# Servicio Python

Creado por la plataforma desde `template-python`. El team dueño está en `.github/CODEOWNERS` y en el catálogo de la organización.

## Qué trae

| Archivo | Para qué |
|---|---|
| `app.py` | Flask con `GET /` y `GET /health`. Escucha en `$PORT` (8080 por defecto). |
| `test_app.py` | Tests que corre el pipeline antes de construir nada. |
| `requirements.txt` | Dependencias de la app; `requirements-dev.txt` añade pytest. |
| `Dockerfile` | Imagen con Gunicorn para Azure Container Apps y para probar en local. |
| `run.sh` | Arranque en AWS Lambda. No se toca. |
| `.github/workflows/deploy.yml` | Llama a `pipelines/build.yml@v1`. No hace falta tocarlo. |

## En local

```bash
uv run --with-requirements requirements.txt python app.py         # http://localhost:8080
uv run --with-requirements requirements-dev.txt pytest -q          # lo mismo que corre el pipeline
docker build -t servicio . && docker run -p 8080:8080 servicio
```

## Cómo se despliega

Cada push a `main` construye, prueba y despliega. Un pull request solo construye y prueba. La nube y la región salen de las variables del repo (`CLOUD_PROVIDER`, `AZURE_LOCATION` o `AWS_REGION`), que puso la plataforma al crearlo: el equipo no gestiona credenciales.

El contrato con la plataforma es corto: el servicio escucha en `$PORT` y responde `200` en `/health`. Si lo cumples, el resto puede cambiar.
