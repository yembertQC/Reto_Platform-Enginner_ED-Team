FROM python:3.13-slim

# Imagen para ejecutar la app en local y para el escaneo de seguridad del CI.
# Ningún despliegue la usa: Azure Functions recibe un zip con remote build y
# AWS Lambda un zip con las dependencias y run.sh.

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

RUN addgroup --gid 1000 appgroup && \
    adduser --uid 1000 --gid 1000 --disabled-password --gecos "" appuser

USER appuser

EXPOSE 5000

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]
