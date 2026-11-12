#!/bin/bash
# Arranque en AWS Lambda (zip + AWS Lambda Web Adapter como layer).
# Lambda lo ejecuta como handler gracias a AWS_LAMBDA_EXEC_WRAPPER=/opt/bootstrap,
# que configura scripts/deploy-lambda.sh del repo pipelines. En Azure no se usa.
PATH=$PATH:$LAMBDA_TASK_ROOT/bin \
  PYTHONPATH=$PYTHONPATH:/opt/python:$LAMBDA_RUNTIME_DIR \
  exec python -m gunicorn -b=:"$PORT" -w=1 app:app
