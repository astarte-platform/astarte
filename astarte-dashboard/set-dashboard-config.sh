#!/bin/sh
# This script dynamically configures the Astarte Dashboard at startup.
# It merges environment variables with the configuration JSON, ensuring that
# environment variables take precedence only when explicitly set.

CONFIG_DIR="/usr/share/nginx/html/user-config"
MOUNTED_CONFIG="$CONFIG_DIR/config.json"
TEMPLATE_FILE="/usr/share/nginx/html/config.json.template"
RUNTIME_CONFIG="/tmp/runtime-config.json"

# Check if a user-provided config.json is mounted
if [ -f "$MOUNTED_CONFIG" ]; then
    echo "User-mounted config.json found. Conditionally merging with DASHBOARD_ environment variables..."
    
    # Use jq to safely override specific keys ONLY if the environment variables are not empty.
    # This preserves the user's mounted config defaults.
    jq --arg api "$DASHBOARD_ASTARTE_API_URL" \
       --arg auth "$DASHBOARD_DEFAULT_AUTH" \
       --arg auth_type "$DASHBOARD_AUTH_TYPE" \
       --arg sidebar "$DASHBOARD_SHOW_SIDEBAR" \
       --arg flow "$DASHBOARD_ENABLE_FLOW_PREVIEW" \
       '(if $api != "" then .astarte_api_url = $api else . end) |
        (if $auth != "" then .default_auth = $auth else . end) |
        (if $auth_type != "" then (.auth[0] = (.auth[0] // {}) | .auth[0].type = $auth_type) else . end) |
        (if $sidebar == "false" then (.ui = (.ui // {}) | .ui.hideSidebar = true) elif $sidebar == "true" then (.ui = (.ui // {}) | .ui.hideSidebar = false) else . end) |
        (if $flow == "true" then .enable_flow_preview = true elif $flow == "false" then .enable_flow_preview = false else . end)' \
       "$MOUNTED_CONFIG" > "$RUNTIME_CONFIG"
else
    echo "No user-mounted config.json found. Generating from template using jq..."
    
    # Apply defaults directly in the variable expansion to avoid overwriting mounted configs earlier.
    # Avoid envsubst to prevent JSON injection vulnerabilities.
    jq --arg api "${DASHBOARD_ASTARTE_API_URL:-http://api.astarte.localhost}" \
       --arg auth "${DASHBOARD_DEFAULT_AUTH:-token}" \
       --arg auth_type "${DASHBOARD_AUTH_TYPE:-token}" \
       --arg sidebar "${DASHBOARD_SHOW_SIDEBAR:-true}" \
       --arg flow "${DASHBOARD_ENABLE_FLOW_PREVIEW:-false}" \
       '.astarte_api_url = $api |
        .default_auth = $auth |
        .auth[0] = (.auth[0] // {}) |
        .auth[0].type = $auth_type |
        .ui = (.ui // {}) |
        .ui.hideSidebar = ($sidebar == "false") |
        .enable_flow_preview = ($flow == "true")' \
       "$TEMPLATE_FILE" > "$RUNTIME_CONFIG"
fi

echo "Runtime configuration ready at $RUNTIME_CONFIG"
