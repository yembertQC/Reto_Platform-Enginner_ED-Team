#!/usr/bin/env bash
# Crea o actualiza una función AWS Lambda a partir de un paquete zip y la expone
# públicamente con una Function URL (sin API Gateway ni registry de contenedores).
#
# El AWS Lambda Web Adapter se añade como layer: así el servidor HTTP normal
# (Gunicorn / net/http) corre dentro de Lambda sin cambiar el código.
#   - Go:     runtime provided.al2023, el zip contiene el binario "bootstrap".
#   - Python: runtime python3.x, el zip contiene app.py, sus dependencias y run.sh;
#             AWS_LAMBDA_EXEC_WRAPPER=/opt/bootstrap hace que el adapter arranque run.sh.
#
# Uso: deploy-lambda.sh <function-name> <zip-file> <execution-role-name> <runtime> <handler> <port>
#   ej. deploy-lambda.sh ed-team-app-go lambda-go.zip ed-team-app-lambda-role provided.al2023 bootstrap 8080
#   ej. deploy-lambda.sh ed-team-app lambda-python.zip ed-team-app-lambda-role python3.13 run.sh 5000
# Requiere credenciales AWS y región ya configuradas (aws-actions/configure-aws-credentials).
# LWA_LAYER_VERSION (opcional, por defecto 30) fija la versión de la layer LambdaAdapterLayerX86.
# Escribe url=<function-url> en $GITHUB_OUTPUT (o stdout fuera de Actions).
set -euo pipefail

FUNCTION_NAME="$1"
ZIP_FILE="$2"
ROLE_NAME="$3"
RUNTIME="$4"
HANDLER="$5"
PORT="$6"
OUT="${GITHUB_OUTPUT:-/dev/stdout}"

REGION="${AWS_REGION:-$(aws configure get region)}"
LWA_LAYER_ARN="arn:aws:lambda:${REGION}:753240598075:layer:LambdaAdapterLayerX86:${LWA_LAYER_VERSION:-30}"

[ -f "$ZIP_FILE" ] || { echo "❌ No existe el paquete $ZIP_FILE"; exit 1; }

if ! aws lambda get-layer-version-by-arn --arn "$LWA_LAYER_ARN" >/dev/null 2>&1; then
  echo "❌ No se encuentra la layer del Lambda Web Adapter: $LWA_LAYER_ARN"
  echo "   Revisa la versión vigente en https://github.com/aws/aws-lambda-web-adapter y pásala en LWA_LAYER_VERSION."
  exit 1
fi

# Variables del adapter: puerto de la app y ruta de readiness.
ENV_VARS="ENVIRONMENT=production,PORT=$PORT,AWS_LWA_PORT=$PORT,AWS_LWA_READINESS_CHECK_PATH=/health"
# En runtimes gestionados (python3.x) el handler es un script: el wrapper del adapter lo arranca.
# En provided.al2023 el propio binario "bootstrap" es el servidor y no hace falta.
if [[ "$RUNTIME" != provided* ]]; then
  ENV_VARS="$ENV_VARS,AWS_LAMBDA_EXEC_WRAPPER=/opt/bootstrap"
fi

ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query Role.Arn --output text)

# Una Lambda creada antes como imagen de contenedor no se puede pasar a zip: se recrea.
PACKAGE_TYPE=$(aws lambda get-function --function-name "$FUNCTION_NAME" \
  --query Configuration.PackageType --output text 2>/dev/null || echo "none")
if [ "$PACKAGE_TYPE" = "Image" ]; then
  echo "♻️ $FUNCTION_NAME era una Lambda de imagen: se elimina para recrearla como zip"
  aws lambda delete-function --function-name "$FUNCTION_NAME"
  PACKAGE_TYPE="none"
fi

if [ "$PACKAGE_TYPE" = "Zip" ]; then
  echo "🔄 Actualizando código de la Lambda $FUNCTION_NAME con $ZIP_FILE"
  aws lambda update-function-code \
    --function-name "$FUNCTION_NAME" \
    --zip-file "fileb://$ZIP_FILE" >/dev/null
  aws lambda wait function-updated-v2 --function-name "$FUNCTION_NAME"
  aws lambda update-function-configuration \
    --function-name "$FUNCTION_NAME" \
    --runtime "$RUNTIME" \
    --handler "$HANDLER" \
    --layers "$LWA_LAYER_ARN" \
    --environment "Variables={$ENV_VARS}" >/dev/null
  aws lambda wait function-updated-v2 --function-name "$FUNCTION_NAME"
else
  echo "🆕 Creando Lambda $FUNCTION_NAME ($RUNTIME) con $ZIP_FILE"
  aws lambda create-function \
    --function-name "$FUNCTION_NAME" \
    --package-type Zip \
    --zip-file "fileb://$ZIP_FILE" \
    --runtime "$RUNTIME" \
    --handler "$HANDLER" \
    --layers "$LWA_LAYER_ARN" \
    --role "$ROLE_ARN" \
    --architectures x86_64 \
    --memory-size 512 \
    --timeout 30 \
    --environment "Variables={$ENV_VARS}" >/dev/null
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
