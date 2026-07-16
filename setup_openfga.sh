#!/bin/bash

# 1. Creazione dello Store e cattura dell'ID
echo "Creazione del nuovo Store OpenFGA..."
STORE_RESPONSE=$(curl -s -X POST http://localhost:8081/stores \
  -H "Content-Type: application/json" \
  -d '{"name": "Astarte Pairing Store"}')

# Estraiamo l'ID dallo Store
STORE_ID=$(echo $STORE_RESPONSE | jq -r .id)
echo "✅ Store ID generato: $STORE_ID"

# 2. Creazione dell'Authorization Model e cattura dell'ID
echo "Creazione dell'Authorization Model..."
MODEL_RESPONSE=$(curl -s -X POST "http://localhost:8081/stores/${STORE_ID}/authorization-models" \
  -H "Content-Type: application/json" \
  -d '{
    "schema_version": "1.1",
    "type_definitions": [
      { "type": "user" },
      {
        "type": "realm",
        "relations": {
          "device_register": { "this": {} },
          "fdo_manage": { "this": {} },
          "fdo_read": { "this": {} }
        },
        "metadata": {
          "relations": {
            "device_register": {
              "directly_related_user_types": [{ "type": "user" }]
            },
            "fdo_manage": {
              "directly_related_user_types": [{ "type": "user" }]
            },
            "fdo_read": {
              "directly_related_user_types": [{ "type": "user" }]
            }
          }
        }
      },
      {
        "type": "device",
        "relations": {
          "can_unregister": { "this": {} },
          "can_obtain_credentials": { "this": {} },
          "can_verify_credentials": { "this": {} }
        },
        "metadata": {
          "relations": {
            "can_unregister": {
              "directly_related_user_types": [{ "type": "user" }]
            },
            "can_obtain_credentials": {
              "directly_related_user_types": [{ "type": "user" }]
            },
            "can_verify_credentials": {
              "directly_related_user_types": [{ "type": "user" }]
            }
          }
        }
      }
    ]
  }')

# Estraiamo l'ID del Modello
MODEL_ID=$(echo $MODEL_RESPONSE | jq -r .authorization_model_id)
echo "✅ Authorization Model ID generato: $MODEL_ID"

# 3. Scrittura delle Tuple
echo "Scrittura delle tuple per il test_user_id..."
curl -s -X POST "http://localhost:8081/stores/${STORE_ID}/write" \
  -H "Content-Type: application/json" \
  -d '{
    "writes": {
      "tuple_keys": [
        {
          "user": "user:test_user_id",
          "relation": "device_register",
          "object": "realm:test"
        },
        {
          "user": "user:test_user_id",
          "relation": "can_unregister",
          "object": "device:f0VMRgIBAQAAAAAAAAAAAA"
        },
        {
          "user": "user:test_user_id",
          "relation": "can_obtain_credentials",
          "object": "device:f0VMRgIBAQAAAAAAAAAAAA"
        },
        {
          "user": "user:test_user_id",
          "relation": "can_verify_credentials",
          "object": "device:f0VMRgIBAQAAAAAAAAAAAA"
        }
      ]
    }
  }' > /dev/null
echo "✅ Tuple scritte con successo. Setup completato!"
