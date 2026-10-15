#!/usr/bin/env bash
#
# Test and apply Astarte's OpenFGA authorization model.
#
#   ./astarte-fga.sh test            run the model's assertions offline (no server needed)
#   ./astarte-fga.sh apply           create a store on the running OpenFGA, load model + tuples
#   ./astarte-fga.sh probe           re-run key assertions against the live server
#   ./astarte-fga.sh all             test, apply, probe
#   ./astarte-fga.sh check U R O     one ad-hoc live check
#   ./astarte-fga.sh store-id        print the store id of the applied store
#   ./astarte-fga.sh clean           delete the store
#
# `test` is the one that matters for "does the model mean what we intended": it
# evaluates the model offline against the assertions in
# libs/astarte_auth/priv/authorization_model.fga.yaml, so it needs neither an
# OpenFGA server nor an Astarte cluster. `apply` and `probe` additionally prove
# the server path works, and leave a store id you can feed to pairing.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

PRIV_DIR="libs/astarte_auth/priv"
MODEL="authorization_model.fga"
TESTS="authorization_model.fga.yaml"
ENV_FILE=".astarte-fga.env"
FGA_IMAGE="openfga/cli:latest"

# The URL and store id env vars are the ones astarte_auth reads.
OPENFGA_URL="${ASTARTE_OPENFGA_URL:-http://localhost:8081}"

if [[ -t 1 ]]; then
  B=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GRN=$'\033[32m'; R=$'\033[0m'
else
  B=""; DIM=""; RED=""; GRN=""; R=""
fi

say()  { printf '%s\n' "${B}==>${R} $*"; }
info() { printf '%s\n' "    ${DIM}$*${R}"; }
ok()   { printf '%s\n' "    ${GRN}ok${R}   $*"; }
bad()  { printf '%s\n' "    ${RED}fail${R} $*"; }
die()  { printf '%s\n' "${RED}error${R} $*" >&2; exit 1; }

[[ -f "${PRIV_DIR}/${MODEL}" ]] || die "${PRIV_DIR}/${MODEL} not found"

# ------------------------------------------------------------------ fga runner

# Prefer a locally installed fga; otherwise run the official CLI image. The
# container needs the host network to reach an OpenFGA on localhost.
if command -v fga >/dev/null 2>&1; then
  fga_cli() { (cd "${REPO_ROOT}/${PRIV_DIR}" && fga "$@"); }
elif command -v docker >/dev/null 2>&1; then
  fga_cli() {
    docker run --rm --network host \
      -v "${REPO_ROOT}/${PRIV_DIR}:/w" -w /w "$FGA_IMAGE" "$@"
  }
else
  die "needs either the fga CLI or docker (for ${FGA_IMAGE})"
fi

server_up() { curl -fsS -o /dev/null --max-time 3 "${OPENFGA_URL}/healthz"; }

require_server() {
  server_up || die "no OpenFGA at ${OPENFGA_URL} — start one with ./astarte-check.sh up"
}

store_id() {
  [[ -f "$ENV_FILE" ]] || return 1
  # shellcheck disable=SC1090
  (source "$ENV_FILE" && printf '%s' "${ASTARTE_OPENFGA_STORE_ID:-}")
}

require_store() {
  local id
  id="$(store_id || true)"
  [[ -n "$id" ]] || die "no store applied yet — run: $0 apply"
  printf '%s' "$id"
}

# --------------------------------------------------------------------- test

cmd_test() {
  say "Validating the model"
  local out
  out="$(fga_cli model validate --file "$MODEL" 2>&1)" ||
    { bad "model does not compile"; printf '%s\n' "$out" | sed 's/^/      /'; return 1; }
  info "$out"

  say "Running the model's assertions ${DIM}(offline)${R}"
  if fga_cli model test --tests "$TESTS"; then
    ok "model behaves as intended"
    return 0
  fi
  bad "the model does not behave as its assertions require"
  return 1
}

# --------------------------------------------------------------------- apply

cmd_apply() {
  require_server
  say "Loading model and tuples into ${OPENFGA_URL}"

  local out
  # The import progress bar writes a lot of carriage returns; keep the last
  # line, which carries the JSON result.
  out="$(fga_cli --api-url "$OPENFGA_URL" store import --file "$TESTS" 2>&1 | tr '\r' '\n' | tail -1)"

  local id
  id="$(printf '%s' "$out" | sed -n 's/.*"store":{[^}]*"id":"\([^"]*\)".*/\1/p')"
  [[ -n "$id" ]] || { bad "could not read the store id from the import result"; printf '%s\n' "$out" | sed 's/^/      /'; return 1; }

  cat > "$ENV_FILE" <<EOF
# Written by ./astarte-fga.sh apply — source this before running a service.
export ASTARTE_OPENFGA_URL="${OPENFGA_URL}"
export ASTARTE_OPENFGA_STORE_ID="${id}"
EOF

  ok "store ${B}${id}${R}"
  info "wrote ${ENV_FILE} — use it with: source ${ENV_FILE}"
}

# --------------------------------------------------------------------- check

live_check() {
  local id="$1" user="$2" relation="$3" object="$4"
  curl -s --max-time 5 -X POST "${OPENFGA_URL}/stores/${id}/check" \
    -H 'Content-Type: application/json' \
    -d "{\"tuple_key\":{\"user\":\"${user}\",\"relation\":\"${relation}\",\"object\":\"${object}\"}}" |
    grep -q '"allowed":true' && echo allowed || echo denied
}

cmd_check() {
  (( $# == 3 )) || die "usage: $0 check <user> <relation> <object>"
  require_server
  local id
  id="$(require_store)"
  printf '%s\n' "$(live_check "$id" "$1" "$2" "$3")"
}

# --------------------------------------------------------------------- probe

# The assertions worth re-checking against a real server: the three deliberate
# asymmetries, device-group and per-interface scoping, team nesting, and realm
# isolation. Format: expected|user|relation|object
PROBES=(
  "allowed|user:testrealm/alice|can_update_realm_config|realm:testrealm"
  "denied |user:testrealm/carol|can_update_realm_config|realm:testrealm"
  "denied |user:testrealm/dave|can_update_realm_config|realm:testrealm"
  "allowed|user:testrealm/alice|can_delete|device:testrealm/dev1"
  "denied |user:testrealm/dave|can_delete|device:testrealm/dev1"
  "allowed|user:testrealm/dave|can_unregister|device:testrealm/dev1"
  "denied |user:testrealm/alice|can_update_realm|realm:testrealm"
  "allowed|user:_cluster/root|can_delete_realm|realm:testrealm"
  "allowed|user:testrealm/bob|can_write_data|device:testrealm/dev1"
  "denied |user:testrealm/bob|can_write_data|device:testrealm/dev2"
  "denied |user:testrealm/bob|can_write_data|interface:testrealm/com.my.Commands"
  "allowed|user:testrealm/frank|can_write_data|interface:testrealm/com.my.Commands"
  "denied |user:testrealm/frank|can_write_data|interface:testrealm/com.my.Telemetry"
  "denied |user:testrealm/frank|can_write_data|device:testrealm/dev1"
  "allowed|user:testrealm/carol|can_read_data|device:testrealm/dev1"
  "denied |user:testrealm/carol|can_write_data|device:testrealm/dev1"
  "allowed|user:testrealm/erin|can_read_fdo|realm:testrealm"
  "denied |user:testrealm/erin|can_manage_fdo|realm:testrealm"
  "denied |user:testrealm/alice|can_read|device:otherrealm/dev1"
  "denied |user:testrealm/mallory|can_read_realm|realm:testrealm"
)

cmd_probe() {
  require_server
  local id
  id="$(require_store)"

  say "Checking the live store ${DIM}${id}${R}"
  local failures=0
  for probe in "${PROBES[@]}"; do
    IFS='|' read -r expected user relation object <<<"$probe"
    expected="${expected// /}"
    local got
    got="$(live_check "$id" "$user" "$relation" "$object")"
    if [[ "$got" == "$expected" ]]; then
      ok "$(printf '%-8s %-26s %-24s %s' "$got" "$relation" "${user#user:}" "$object")"
    else
      bad "$(printf '%-8s %-26s %-24s %s  (expected %s)' "$got" "$relation" "${user#user:}" "$object" "$expected")"
      failures=$((failures + 1))
    fi
  done

  echo
  if (( failures == 0 )); then
    say "${GRN}All ${#PROBES[@]} live checks match the model${R}"
    return 0
  fi
  say "${RED}${failures} of ${#PROBES[@]} live checks disagree with the model${R}"
  return 1
}

# ---------------------------------------------------------------- store admin

cmd_store_id() { require_store; echo; }

cmd_clean() {
  require_server
  local id
  id="$(store_id || true)"
  if [[ -z "$id" ]]; then
    info "no store recorded in ${ENV_FILE}; nothing to delete"
  else
    curl -fsS -X DELETE "${OPENFGA_URL}/stores/${id}" >/dev/null 2>&1 &&
      ok "deleted store ${id}" || bad "could not delete store ${id}"
  fi
  rm -f "$ENV_FILE"
  ok "removed ${ENV_FILE}"
}

# ------------------------------------------------------------------ arguments

usage() { sed -n '3,18p' "${BASH_SOURCE[0]}" | sed 's/^#\s\?//'; exit "${1:-0}"; }

case "${1:-}" in
  test)     cmd_test ;;
  apply)    cmd_apply ;;
  probe)    cmd_probe ;;
  check)    shift; cmd_check "$@" ;;
  store-id) cmd_store_id ;;
  clean)    cmd_clean ;;
  all)      cmd_test && echo && cmd_apply && echo && cmd_probe ;;
  -h|--help|"") usage 0 ;;
  *)        die "unknown command: $1" ;;
esac
