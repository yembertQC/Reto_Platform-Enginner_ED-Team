"""Servicio creado desde la plantilla template-python de la plataforma.

Contrato del golden path: escucha en $PORT (8080 por defecto) y responde GET /health.
"""
import os

from flask import Flask, jsonify

app = Flask(__name__)


@app.route("/")
def hello():
    return jsonify({"message": "Hola ED Team"})


@app.route("/health")
def health():
    return jsonify({"status": "healthy"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)), debug=False)
