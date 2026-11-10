#!/usr/bin/env bash
# Crea o actualiza una función AWS Lambda a partir de una imagen de ECR y la
# expone públicamente con una Function URL (sin API Gateway).
#
# La imagen debe incluir el AWS Lambda Web Adapter (ver src/Dockerfile y
# src-go/Dockerfile): así el servidor HTTP normal (Gunicorn / net/http) corre
# dentro de Lambda sin cambiar el código.
#
# Uso: deploy-lambda.sh <function-name> <image-uri> <execution-role-name>
# Requiere credenciales AWS y región ya configuradas (aws-actions/configure-aws-credentials).
# Escribe url=<function-url> en $GITHUB_OUTPUT (o stdout fuera de Actions).
set -euo pipefail

FUNCTION_NAME="$1"
IMAGE_URI="$2"
ROLE_NAME="$3"
OUT="${GITHUB_OUTPUT:-/dev/stdout}"

ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query Role.Arn --output text)

if aws lambda get-function --function-name "$FUNCTION_NAME" >/dev/null 2>&1; then
  echo "🔄 Actualizando imagen de la Lambda $FUNCTION_NAME -> $IMAGE_URI"
  aws lambda update-function-code \
    --function-name "$FUNCTION_NAME" \
    --image-uri "$IMAGE_URI" >/dev/null
  aws lambda wait function-updated-v2 --function-name "$FUNCTION_NAME"
else
  echo "🆕 Creando Lambda $FUNCTION_NAME con $IMAGE_URI"
  aws lambda create-function \
    --function-name "$FUNCTION_NAME" \
    --package-type Image \
    --code ImageUri="$IMAGE_URI" \
    --role "$ROLE_ARN" \
    --architectures x86_64 \
    --memory-size 512 \
    --timeout 30 \
    --environment "Variables={ENVIRONMENT=production}" >/dev/null
  aws lambda wait function-active-v2 --function-name "$FUNCTION_NAME"
fi

if ! aws lambda get-function-url-config --function-name "$FUNCTION_NAME" >/dev/null 2>&1; then
  echo "🌐 Creando Function URL pública"
  aws lambda create-function-url-config \
    --function-name "$FUNCTION_NAME" \
    --auth-type NONE >/dev/null

  aws lambda add-permission \
    --function-name "$FUNCTION_NAME" \
    --statement-id FunctionURLAllowPublicAccess \
    --action lambda:InvokeFunctionUrl \
    --principal "*" \
    --function-url-auth-type NONE >/dev/null

  # Las Function URLs nuevas también necesitan lambda:InvokeFunction,
  # restringido a invocaciones que lleguen por la Function URL.
  if ! aws lambda add-permission \
      --function-name "$FUNCTION_NAME" \
      --statement-id FunctionURLAllowInvokeAction \
      --action lambda:InvokeFunction \
      --principal "*" \
      --invoked-via-function-url >/dev/null; then
    echo "::warning::No se pudo añadir lambda:InvokeFunction para la Function URL. Si la URL devuelve 403, añade ese permiso desde la consola de Lambda."
  fi
fi

FUNCTION_URL=$(aws lambda get-function-url-config \
  --function-name "$FUNCTION_NAME" \
  --query FunctionUrl --output text)
FUNCTION_URL="${FUNCTION_URL%/}"

echo "✅ Lambda desplegada: $FUNCTION_URL"
echo "url=$FUNCTION_URL" >> "$OUT"
