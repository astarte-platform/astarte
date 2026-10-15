#!/usr/bin/env bash
#
# Runs the FDO owner side of the pairing GraphQL API from start to finish:
# creates and uploads owner keys, checks which keys fit a sample ownership
# voucher, registers the voucher (which claims it on the rendezvous server and
# registers its device) and lists the result.
#
# Run init-realm test first: this script uses the generated private key to authenticate.
#
# Usage:
#   ./graph-fdo.sh              run the flow and leave the voucher registered
#   ./graph-fdo.sh --cleanup    run the flow, then remove the voucher again
#
# The flow can be repeated: a voucher left over from a previous run is removed
# before registering it again.

set -euo pipefail

cd "$(dirname "$0")"

ENV_FILE=".graphql-local.env"

# The device the voucher is registered for.
VOUCHER_HW_ID="2TBn-jNESuuHamE2Zo1anA"
VOUCHER_GUID="b1f1d8f0-3a9f-4cf8-b46b-23a94cfc66e7"
INTROSPECTION_INTERFACE="org.astarte-platform.genericsensors.Values"

# The key the sample voucher was issued for, and a second one that is not.
OWNER_KEY_NAME="fdo-owner-key"
OTHER_KEY_NAME="fdo-generated-key"

OWNER_KEY="-----BEGIN EC PRIVATE KEY-----
MHcCAQEEIPKdthyV+2F5gPIqHyiQ9Wi1Y01r66/BbvnILFWehTRToAoGCCqGSM49
AwEHoUQDQgAEGwrCWU3M3/Cxk0jMB4TmyQEaXLp+tqX42GsmeZ+7jeEWjHLFmEYH
LC/GgcMr88CXA3/i64k0iiIMRRQ3osnV/A==
-----END EC PRIVATE KEY-----"

VOUCHER="-----BEGIN OWNERSHIP VOUCHER-----
hRhlWL6GGGVQsfHY8DqfTPi0ayOpTPxm54GEggNDGR+SggJFRH8AAAGCBEMZH5KC
DEEBa3AyNTYtZGV2aWNlgwoBWFswWTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAAQb
CsJZTczf8LGTSMwHhObJARpcun62pfjYayZ5n7uN4RaMcsWYRgcsL8aBwyvzwJcD
f+LriTSKIgxFFDeiydX8gi9YINH8REeqEOOpCpH9Arx8yt1/2ZKICO5s8mo4AW2h
Gfz2ggVYIENgeEjaDkp0mbAiC/jro5IUx9j0jtTEUNLm8M74YleDgVkBHjCCARow
gcGgAwIBAgIDAeJAMAoGCCqGSM49BAMCMBYxFDASBgNVBAMMC1Rlc3QgRGV2aWNl
MB4XDTI0MDEwMTAwMDAwMFoXDTM0MDEwMTAwMDAwMFowFjEUMBIGA1UEAwwLVGVz
dCBEZXZpY2UwWTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAAQbCsJZTczf8LGTSMwH
hObJARpcun62pfjYayZ5n7uN4RaMcsWYRgcsL8aBwyvzwJcDf+LriTSKIgxFFDei
ydX8MAoGCCqGSM49BAMCA0gAMEUCIF+IuxL2kt310Im+OjbA/lNNG73qUX1CH22i
5/WGPHz8AiEAuzPBY60mRQHyetxjA4Lx+Wkdm7NWWxzdfv+6uDhVhOiB0oRDoQEm
oFichIIvWCBSpkHIqibg9oEqb9tnSTB0ABsn9mji099pWZIcvH0WdoIvWCCLI3XG
98ZneM2FDlIJC7dH8MZSxltPfu4TkN7z6GIo1vaDCgNYTaUieCAWjHLFmEYHLC/G
gcMr88CXA3/i64k0iiIMRRQ3osnV/CF4IBsKwllNzN/wsZNIzAeE5skBGly6fral
+NhrJnmfu43hIAEBAgMmWEChODtvywnaQNZqZtAi+ukIDh06ZQxYk/BZ72qtX4Qt
KgRKDMZ26gaTvdOSYOiWl+hL0gCbdyhXp5dySgYsHYEn
-----END OWNERSHIP VOUCHER-----"

cleanup=false

while (($# > 0)); do
    case "$1" in
    --cleanup) cleanup=true ;;
    -h | --help)
        sed -n '3,16p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    *)
        echo "error: unknown option $1" >&2
        exit 1
        ;;
    esac
    shift
done

info() { printf '\n==> %s\n' "$*" >&2; }
die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

ASTARTE_URL="http://api.astarte.localhost"
REALM="test"
REALM_PRIVATE_KEY="${REALM}_private.pem"

for tool in curl jq astartectl; do
    command -v "$tool" >/dev/null || die "$tool not found in PATH"
done

ASTARTECTL="${ASTARTECTL:-astartectl}"
# Fallback for older versions of astartectl that don't support -U
if ! "$ASTARTECTL" utils gen-jwt -h | grep -q "\-U"; then
    if [[ -x "$HOME/Downloads/astartectl" ]]; then
        ASTARTECTL="$HOME/Downloads/astartectl"
    else
        die "The astartectl version in your PATH does not support the -U flag. Please use a newer version."
    fi
fi

if [[ -n "${ASTARTE_TOKEN:-}" ]]; then
    TOKEN="$ASTARTE_TOKEN"
else
    TOKEN="$("$ASTARTECTL" utils gen-jwt all-realm-apis -k "$REALM_PRIVATE_KEY" -U test_user_id --roles admin -e 0)"
fi
[[ -n $TOKEN ]] || die "could not generate token"

# graphql '<query>' ['<variables json>']: prints the raw JSON response.
graphql() {
    local vars="${2:-}"
    [[ -n $vars ]] || vars='{}'
    jq -n --arg q "$1" --argjson v "$vars" '{query: $q, variables: $v}' |
        curl -s --max-time 60 "$ASTARTE_URL/pairing/v1/graphql" \
            -H "Authorization: Bearer $TOKEN" \
            -H "astarte-realm: $REALM" \
            -H "Content-Type: application/json" \
            -d @-
}

# The first error message of a response, or nothing if it succeeded.
error_of() { jq -r '.errors[0].message // empty' <<<"$1"; }

# Runs a call that must succeed, prints its data and keeps it in $response.
must_succeed() {
    response="$(graphql "$@")"
    [[ -n $response ]] || die "no response from $ASTARTE_URL, is the stack up?"
    local error
    error="$(error_of "$response")"
    [[ -z $error ]] || die "$error"
    jq .data <<<"$response" >&2
}

# Runs a call that must be refused with a message containing $1.
must_fail_with() {
    local expected="$1" error
    shift
    response="$(graphql "$@")"
    error="$(error_of "$response")"
    [[ $error == *"$expected"* ]] || die "expected an error containing \"$expected\", got: ${error:-success}"
    printf 'refused as expected: %s\n' "$error" >&2
}

delete_voucher() {
    response="$(graphql 'mutation($guid: String!) { deleteOwnershipVoucher(guid: $guid) }' "$(jq -n --arg guid "$VOUCHER_GUID" '{guid: $guid}')")"
    if [[ -z "$(error_of "$response")" ]]; then
        echo "204"
    else
        echo "500"
    fi
}

voucher_registered() {
    graphql '{ listOwnershipVouchers { guid } }' |
        jq -e --arg guid "$VOUCHER_GUID" '.data.listOwnershipVouchers // [] | any(.guid == $guid)' >/dev/null
}

voucher_vars="$(jq -n --arg v "$VOUCHER" '{v: $v}')"

register_voucher='mutation($v: String!, $key: String!) {
  registerOwnershipVoucher(
    ownershipVoucher: $v, keyName: $key, keyAlgorithm: ES256
  ) { guid publicKey }
}'

register_vars() {
    jq -n --arg v "$VOUCHER" --arg key "$1" \
        '{v: $v, key: $key}'
}

info "checking the GraphQL API answers and the token is accepted"
must_succeed '{ listOwnershipVouchers { guid status } }'

if voucher_registered; then
    info "removing the voucher left by a previous run"
    [[ $(delete_voucher) == 204 ]] || die "could not remove voucher $VOUCHER_GUID"
fi

info "creating owner key $OTHER_KEY_NAME in the secrets store"
must_succeed 'mutation($name: String!) { createOrUploadOwnerKey(action: "create", keyName: $name, keyAlgorithm: ES256) }' \
    "$(jq -n --arg name "$OTHER_KEY_NAME" '{name: $name}')"

info "uploading the voucher's owner key as $OWNER_KEY_NAME"
response="$(graphql 'mutation($name: String!, $k: String!) { createOrUploadOwnerKey(action: "upload", keyName: $name, keyData: $k) }' \
    "$(jq -n --arg name "$OWNER_KEY_NAME" --arg k "$OWNER_KEY" '{name: $name, k: $k}')")"
case "$(error_of "$response")" in
"") echo "uploaded" >&2 ;;
*key_already_imported*) echo "already uploaded by a previous run" >&2 ;;
*) die "$(error_of "$response")" ;;
esac

info "listing owner keys"
must_succeed '{ listOwnerKeys { es256 es384 rs256 rs384 } }'
for name in "$OWNER_KEY_NAME" "$OTHER_KEY_NAME"; do
    jq -e --arg name "$name" '.data.listOwnerKeys.es256 | index($name)' <<<"$response" >/dev/null ||
        die "$name is missing from the owner keys"
done

info "reading owner key $OWNER_KEY_NAME"
must_succeed 'query($name: String!) { getOwnerKey(keyAlgorithm: ES256, keyName: $name) { keyName publicKey } }' \
    "$(jq -n --arg name "$OWNER_KEY_NAME" '{name: $name}')"

info "finding the owner keys that fit the voucher"
must_succeed 'query($v: String!) { ownerKeysForVoucher(ownershipVoucher: $v) { es256 es384 rs256 rs384 } }' "$voucher_vars"

info "registering the voucher with $OTHER_KEY_NAME, which it was not issued for"
must_fail_with "does not match the public key" "$register_voucher" "$(register_vars "$OTHER_KEY_NAME")"

info "registering the voucher with $OWNER_KEY_NAME (claims it on the rendezvous server and registers device $VOUCHER_HW_ID)"
must_succeed "$register_voucher" "$(register_vars "$OWNER_KEY_NAME")"
[[ $(jq -r .data.registerOwnershipVoucher.guid <<<"$response") == "$VOUCHER_GUID" ]] ||
    die "the registered voucher has an unexpected guid"

info "listing ownership vouchers"
must_succeed '{ listOwnershipVouchers { guid status outputGuid } }'
voucher_registered || die "voucher $VOUCHER_GUID is missing from the list"

info "registering the same voucher a second time"
must_succeed "$register_voucher" "$(register_vars "$OWNER_KEY_NAME")"

if $cleanup; then
    info "removing the voucher"
    [[ $(delete_voucher) == 204 ]] || die "could not remove voucher $VOUCHER_GUID"
    must_succeed '{ listOwnershipVouchers { guid status } }'
    printf '\nFDO flow completed, voucher removed again.\n' >&2
else
    cat >&2 <<EOF

FDO flow completed. Voucher $VOUCHER_GUID is registered for
device $VOUCHER_HW_ID and waiting for the device to onboard.
Run this script with --cleanup, or again as it is, to remove it.
EOF
fi
