#!/bin/bash
# Arranque de la app Flask en AWS Lambda (paquete zip + AWS Lambda Web Adapter como layer).
# Lambda ejecuta este script como handler gracias a AWS_LAMBDA_EXEC_WRAPPER=/opt/bootstrap
# (lo configura scripts/deploy-lambda.sh). No se usa en Azure Functions ni en Docker.
PATH=$PATH:$LAMBDA_TASK_ROOT/bin \
  PYTHONPATH=$PYTHONPATH:/opt/python:$LAMBDA_RUNTIME_DIR \
  exec python -m gunicorn -b=:"$PORT" -w=1 app:app
