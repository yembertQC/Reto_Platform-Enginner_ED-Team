"""Punto de entrada de Azure Functions.

Monta la app Flask de app.py sin modificarla, usando el adaptador WSGI de Azure
Functions. Todas las rutas (/, /health) se sirven desde una única función HTTP
con ruta catch-all; host.json elimina el prefijo /api para que las URLs sean
las mismas que en local, en Docker y en AWS Lambda.
"""
import azure.functions as func

from app import app as flask_app

app = func.WsgiFunctionApp(
    app=flask_app.wsgi_app,
    http_auth_level=func.AuthLevel.ANONYMOUS,
)
