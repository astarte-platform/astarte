#!/bin/sh
set -eu

OPENFGA_URL="http://openfga:8080"
STORE_NAME="$ASTARTE_OPENFGA_STORE_NAME"

# services look the store up by name, create it only once
EXISTING_STORE_ID=$(fga store list --api-url "$OPENFGA_URL" |
  jq -r --arg name "$STORE_NAME" '.stores[] | select(.name == $name) | .id')

if [ -n "$EXISTING_STORE_ID" ]; then
  echo "Store \"$STORE_NAME\" already exists: $EXISTING_STORE_ID"
  exit 0
fi

echo "Creating store \"$STORE_NAME\""
STORE_RESPONSE=$(fga store create --api-url "$OPENFGA_URL" \
  --name "$STORE_NAME" \
  --model /model/authorization_model.fga)

STORE_ID=$(echo "$STORE_RESPONSE" | jq -r '.store.id')
echo "Store id: $STORE_ID"

MODEL_ID=$(echo "$STORE_RESPONSE" | jq -r '.model.authorization_model_id')
echo "✅ Model ID: $MODEL_ID"
