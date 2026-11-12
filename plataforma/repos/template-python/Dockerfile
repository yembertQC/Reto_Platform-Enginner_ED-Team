FROM python:3.13-slim

# Imagen para Azure Container Apps (la publica pipelines/build.yml en GHCR) y para docker run local.
# En AWS Lambda no se usa: el pipeline sube un zip con app.py, sus dependencias y run.sh.

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

RUN addgroup --gid 1000 appgroup && \
    adduser --uid 1000 --gid 1000 --disabled-password --gecos "" appuser

USER appuser

ENV PORT=8080
EXPOSE 8080

CMD ["sh", "-c", "exec gunicorn --bind 0.0.0.0:${PORT} app:app"]
