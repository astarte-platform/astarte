#!/bin/sh
set -eu

OPENFGA_URL="http://openfga:8080"
SHARED_ENV="/shared/openfga.env"

echo "Waiting for OpenFGA to be ready..."
while ! curl -s -f "$OPENFGA_URL/healthz" >/dev/null; do
  sleep 2
done
echo "OpenFGA is ready."

echo "Creating Store..."
STORE_RESPONSE=$(curl -s -X POST "$OPENFGA_URL/stores" \
  -H "Content-Type: application/json" \
  -d '{"name": "Astarte Pairing Store"}')

STORE_ID=$(echo "$STORE_RESPONSE" | jq -r '.id')
echo "✅ Store ID: $STORE_ID"

echo "Creating Authorization Model..."
MODEL_RESPONSE=$(curl -s -X POST "$OPENFGA_URL/stores/$STORE_ID/authorization-models" \
  -H "Content-Type: application/json" \
  -d @/openfga-init/model.json)

MODEL_ID=$(echo "$MODEL_RESPONSE" | jq -r '.authorization_model_id')
echo "✅ Model ID: $MODEL_ID"

echo "Writing Tuples..."
curl -s -X POST "$OPENFGA_URL/stores/$STORE_ID/write" \
  -H "Content-Type: application/json" \
  -d @/openfga-init/tuples.json >/dev/null
echo "✅ Tuples written."

echo "Writing shared environment file..."
echo "export ASTARTE_OPENFGA_STORE_ID=\"$STORE_ID\"" > "$SHARED_ENV"
echo "✅ Setup complete."
