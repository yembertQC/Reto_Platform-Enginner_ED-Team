#!/usr/bin/env bash
# Valida un despliegue: /health debe contener "healthy" y / debe contener "Hola ED Team".
# Reintenta porque los servicios serverless pueden tardar en el primer arranque (cold start).
#
# Uso: smoke-test.sh <base-url> [intentos]
set -euo pipefail

BASE_URL="${1%/}"
ATTEMPTS="${2:-20}"

for i in $(seq 1 "$ATTEMPTS"); do
  HEALTH=$(curl -sS -m 30 "$BASE_URL/health" 2>&1 || true)
  if [[ "$HEALTH" == *healthy* ]]; then
    echo "✅ $BASE_URL/health -> $HEALTH"
    ROOT=$(curl -sS -m 30 "$BASE_URL/" 2>&1 || true)
    if [[ "$ROOT" == *"Hola ED Team"* ]]; then
      echo "✅ $BASE_URL/ -> $ROOT"
      exit 0
    fi
    echo "❌ $BASE_URL/ respondió algo inesperado: $ROOT"
    exit 1
  fi
  echo "⏳ Intento $i/$ATTEMPTS: $BASE_URL/health aún no responde (${HEALTH:0:200})"
  sleep 10
done

echo "❌ $BASE_URL/health no respondió 'healthy' tras $ATTEMPTS intentos"
exit 1
