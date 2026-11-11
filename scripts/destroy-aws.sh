#!/usr/bin/env bash
# Borra la infraestructura serverless de AWS del curso:
#   Lambdas <lambda-name> (Python) y <lambda-name>-go (Go), con sus Function URLs
#   → sus log groups de CloudWatch → el rol IAM de ejecución.
# Es idempotente: lo que ya no existe se salta, así que se puede relanzar sin miedo.
#
# Uso: destroy-aws.sh <lambda-name> <execution-role-name>
#   ej. destroy-aws.sh ed-team-app ed-team-app-lambda-role
# Requiere credenciales AWS y región ya configuradas (aws-actions/configure-aws-credentials).
# Escribe el resultado en $GITHUB_STEP_SUMMARY si existe.
set -euo pipefail

if [ "$#" -ne 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
  echo "Uso: $0 <lambda-name> <execution-role-name>" >&2
  exit 2
fi

LAMBDA_NAME="$1"
ROLE_NAME="$2"

SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/null}"
report() { echo "$1"; echo "| $2 | \`$3\` | $4 |" >> "$SUMMARY"; }

{
  echo ""
  echo "## 🗑️ AWS · limpieza de la infraestructura"
  echo ""
  echo "| Recurso | Nombre | Resultado |"
  echo "|---------|--------|-----------|"
} >> "$SUMMARY"

for NAME in "$LAMBDA_NAME" "$LAMBDA_NAME-go"; do
  # Lambda (su Function URL y sus permisos se borran con la función)
  if aws lambda get-function --function-name "$NAME" > /dev/null 2>&1; then
    aws lambda delete-function --function-name "$NAME"
    report "🗑️ Lambda borrada: $NAME" "Lambda + Function URL" "$NAME" "🗑️ Borrada"
  else
    report "- Lambda $NAME: no existe" "Lambda + Function URL" "$NAME" "No existía"
  fi

  # Log group de CloudWatch: si no existe se salta; cualquier otro error (permisos) hace fallar el job
  LOG_GROUP="/aws/lambda/$NAME"
  if OUT=$(aws logs delete-log-group --log-group-name "$LOG_GROUP" 2>&1); then
    report "🗑️ Log group borrado: $LOG_GROUP" "Log group" "$LOG_GROUP" "🗑️ Borrado"
  elif grep -q ResourceNotFoundException <<< "$OUT"; then
    report "- Log group $LOG_GROUP: no existe" "Log group" "$LOG_GROUP" "No existía"
  else
    echo "$OUT" >&2
    exit 1
  fi
done

# Rol IAM: antes de borrarlo hay que quitarle las políticas gestionadas y las inline
if aws iam get-role --role-name "$ROLE_NAME" > /dev/null 2>&1; then
  for POLICY_ARN in $(aws iam list-attached-role-policies --role-name "$ROLE_NAME" \
      --query "AttachedPolicies[].PolicyArn" --output text); do
    aws iam detach-role-policy --role-name "$ROLE_NAME" --policy-arn "$POLICY_ARN"
  done
  for POLICY_NAME in $(aws iam list-role-policies --role-name "$ROLE_NAME" \
      --query "PolicyNames[]" --output text); do
    aws iam delete-role-policy --role-name "$ROLE_NAME" --policy-name "$POLICY_NAME"
  done
  aws iam delete-role --role-name "$ROLE_NAME"
  report "🗑️ Rol IAM borrado: $ROLE_NAME" "Rol IAM" "$ROLE_NAME" "🗑️ Borrado"
else
  report "- Rol IAM $ROLE_NAME: no existe" "Rol IAM" "$ROLE_NAME" "No existía"
fi

echo "✅ Limpieza de AWS terminada"
