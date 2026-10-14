#!/usr/bin/env bash
#
# Bring up the services the Astarte test suites need, and run the same checks CI
# runs. The containers mirror the `services:` block of
# .github/workflows/astarte-apps-build-workflow.yaml, so a green run here means
# the same thing a green run there does.
#
#   ./astarte-check.sh up                 start the infrastructure and wait for it
#   ./astarte-check.sh check              run every check against what is running
#   ./astarte-check.sh all                up, then check
#   ./astarte-check.sh down [-v]          stop it (-v also drops the volumes)
#   ./astarte-check.sh status             show what is up and reachable
#
#   ./astarte-check.sh check astarte_auth astarte_pairing
#   ./astarte-check.sh check --only test astarte_pairing
#   ./astarte-check.sh up --db cassandra
#
set -euo pipefail

# ---------------------------------------------------------------- configuration

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

# Images pinned to what CI uses. Keep these in step with the workflow.
IMG_SCYLLA="scylladb/scylla:2025.2.2"
IMG_CASSANDRA="cassandra:3.11.15"
IMG_RABBITMQ="rabbitmq:3.12.0-management"
IMG_CFSSL="ispirata/docker-alpine-cfssl-autotest:astarte"
IMG_OPENBAO="openbao/openbao:2"
IMG_RENDEZVOUS="astarte/go-fdo-server:ade68cda47-20251128"
IMG_OPENFGA="openfga/openfga:latest"

PREFIX="astarte-check"
NETWORK="${PREFIX}-net"

# Ports. CFSSL is 8080 because that is what apps/astarte_pairing/config/test.exs
# falls back to; OpenFGA is 8081 because that is what the astarte_auth test
# config expects.
PORT_DB=9042
PORT_RABBITMQ=5672
PORT_RABBITMQ_MGMT=15672
PORT_CFSSL=8080
PORT_OPENBAO=8200
PORT_RENDEZVOUS=8041
PORT_OPENFGA=8081

export ASTARTE_VAULT_TOKEN="${ASTARTE_VAULT_TOKEN:-astarte_token}"
export CFSSL_API_URL="${CFSSL_API_URL:-http://localhost:${PORT_CFSSL}}"
export PAIRING_FDO_RENDEZVOUS_URL="${PAIRING_FDO_RENDEZVOUS_URL:-http://localhost:${PORT_RENDEZVOUS}}"
export CASSANDRA_NODES="${CASSANDRA_NODES:-localhost:${PORT_DB}}"
export MIX_ENV=test

DB_FLAVOUR="scylla"
WAIT_TIMEOUT=240

# ----------------------------------------------------------------- presentation

if [[ -t 1 ]]; then
  B=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GRN=$'\033[32m'
  YLW=$'\033[33m'; CYN=$'\033[36m'; R=$'\033[0m'
else
  B=""; DIM=""; RED=""; GRN=""; YLW=""; CYN=""; R=""
fi

say()  { printf '%s\n' "${B}==>${R} $*"; }
info() { printf '%s\n' "    ${DIM}$*${R}"; }
ok()   { printf '%s\n' "    ${GRN}ok${R}   $*"; }
warn() { printf '%s\n' "    ${YLW}warn${R} $*"; }
bad()  { printf '%s\n' "    ${RED}fail${R} $*"; }
die()  { printf '%s\n' "${RED}error${R} $*" >&2; exit 1; }

# -------------------------------------------------------------------- container

container_runtime() {
  if command -v docker >/dev/null 2>&1; then echo docker
  elif command -v podman >/dev/null 2>&1; then echo podman
  else die "neither docker nor podman is installed"
  fi
}

CR="$(container_runtime)"

cr_running() { [[ "$("$CR" inspect -f '{{.State.Running}}' "$1" 2>/dev/null)" == "true" ]]; }
cr_exists()  { "$CR" inspect "$1" >/dev/null 2>&1; }

ensure_network() {
  "$CR" network inspect "$NETWORK" >/dev/null 2>&1 || "$CR" network create "$NETWORK" >/dev/null
}

# run_container <name> <image> [run options...] [-- container command...]
#
# The image has to sit between the run options and the container's own command,
# so `--` separates the two halves.
run_container() {
  local name="$1" image="$2"; shift 2
  local full="${PREFIX}-${name}"

  local opts=() cmd=() past_sep=0
  for arg in "$@"; do
    if (( ! past_sep )) && [[ "$arg" == "--" ]]; then
      past_sep=1
      continue
    fi
    if (( past_sep )); then cmd+=("$arg"); else opts+=("$arg"); fi
  done

  if cr_running "$full"; then
    ok "$name already running"
    return 0
  fi
  if cr_exists "$full"; then
    info "restarting $name"
    "$CR" start "$full" >/dev/null
    ok "$name restarted"
    return 0
  fi

  info "starting $name ($image)"
  local out
  if ! out="$("$CR" run -d --name "$full" --network "$NETWORK" --restart unless-stopped \
      ${opts[@]+"${opts[@]}"} "$image" ${cmd[@]+"${cmd[@]}"} 2>&1)"; then
    bad "could not start $name"
    printf '%s\n' "$out" | sed 's/^/      /'
    return 1
  fi
  ok "$name started"
}

# ------------------------------------------------------------------------ waits

# wait_for <label> <command...> — polls until the command succeeds
wait_for() {
  local label="$1"; shift
  local waited=0
  printf '    %swait%s %s' "$DIM" "$R" "$label"
  while ! "$@" >/dev/null 2>&1; do
    if (( waited >= WAIT_TIMEOUT )); then
      printf '\r'
      bad "$label did not come up within ${WAIT_TIMEOUT}s"
      return 1
    fi
    sleep 2
    waited=$((waited + 2))
    printf '.'
  done
  printf '\r'
  ok "$label reachable${waited:+ ${DIM}(${waited}s)${R}}"
}

tcp_open() {
  local port="$1"
  (exec 3<>"/dev/tcp/127.0.0.1/${port}") 2>/dev/null
}

http_ok() { curl -fsS -o /dev/null --max-time 3 "$1"; }

db_ready() {
  "$CR" exec "${PREFIX}-database" cqlsh -e "SELECT release_version FROM system.local;"
}

openbao_ready() {
  "$CR" exec "${PREFIX}-openbao" bao status -address="http://127.0.0.1:8200"
}

# -------------------------------------------------------------------------- up

cmd_up() {
  ensure_network

  local db_image="$IMG_SCYLLA"
  [[ "$DB_FLAVOUR" == "cassandra" ]] && db_image="$IMG_CASSANDRA"

  say "Starting test infrastructure (${DB_FLAVOUR}, via ${CR})"

  run_container database "$db_image" -p "${PORT_DB}:9042"
  run_container rabbitmq "$IMG_RABBITMQ" \
    -p "${PORT_RABBITMQ}:5672" -p "${PORT_RABBITMQ_MGMT}:15672"
  run_container cfssl "$IMG_CFSSL" -p "${PORT_CFSSL}:8080"
  run_container openbao "$IMG_OPENBAO" -p "${PORT_OPENBAO}:8200" \
    -e "BAO_DEV_ROOT_TOKEN_ID=${ASTARTE_VAULT_TOKEN}" \
    -e "BAO_DEV_LISTEN_ADDRESS=0.0.0.0:8200"
  # The image's entrypoint takes these arguments, exactly as the workflow's
  # `command:` passes them.
  run_container rendezvous "$IMG_RENDEZVOUS" -p "${PORT_RENDEZVOUS}:8041" \
    --tmpfs /var/lib/fdo \
    -- --log-level=debug rendezvous 0.0.0.0:8041 \
    --db-type sqlite --db-dsn "file:/var/lib/fdo/rendezvous.db"
  run_container openfga "$IMG_OPENFGA" -p "${PORT_OPENFGA}:8080" \
    -e OPENFGA_DATASTORE_ENGINE=memory \
    -e OPENFGA_PLAYGROUND_ENABLED=true \
    -- run

  say "Waiting for readiness"
  local failed=()
  wait_for "RabbitMQ"       tcp_open "$PORT_RABBITMQ"  || failed+=(rabbitmq)
  wait_for "CFSSL"          tcp_open "$PORT_CFSSL"     || failed+=(cfssl)
  wait_for "FDO rendezvous" tcp_open "$PORT_RENDEZVOUS" || failed+=(rendezvous)
  wait_for "OpenFGA"        http_ok "http://localhost:${PORT_OPENFGA}/healthz" || failed+=(openfga)
  wait_for "OpenBao"        openbao_ready              || failed+=(openbao)
  wait_for "${DB_FLAVOUR}"  db_ready                   || failed+=(database)

  if (( ${#failed[@]} )); then
    say "These did not come up — last log lines:"
    for c in "${failed[@]}"; do
      printf '%s\n' "    ${B}${c}${R}"
      "$CR" logs --tail 15 "${PREFIX}-${c}" 2>&1 | sed 's/^/      /'
    done
    die "infrastructure is not ready"
  fi

  say "Infrastructure up"
  cmd_env
}

cmd_env() {
  cat <<EOF
    ${DIM}ASTARTE_VAULT_TOKEN=${ASTARTE_VAULT_TOKEN}
    CFSSL_API_URL=${CFSSL_API_URL}
    PAIRING_FDO_RENDEZVOUS_URL=${PAIRING_FDO_RENDEZVOUS_URL}
    CASSANDRA_NODES=${CASSANDRA_NODES}${R}
EOF
}

# ------------------------------------------------------------------------ down

cmd_down() {
  local drop_volumes=0
  [[ "${1:-}" == "-v" || "${1:-}" == "--volumes" ]] && drop_volumes=1

  local rm_opts=(-f)
  (( drop_volumes )) && rm_opts+=(-v)

  say "Stopping test infrastructure"
  for c in database rabbitmq cfssl openbao rendezvous openfga; do
    local full="${PREFIX}-${c}"
    if cr_exists "$full"; then
      "$CR" rm "${rm_opts[@]}" "$full" >/dev/null
      ok "removed $c"
    fi
  done
  "$CR" network rm "$NETWORK" >/dev/null 2>&1 && ok "removed network" || true
}

# ---------------------------------------------------------------------- status

cmd_status() {
  say "Infrastructure"
  local -A ports=(
    [database]=$PORT_DB [rabbitmq]=$PORT_RABBITMQ [cfssl]=$PORT_CFSSL
    [openbao]=$PORT_OPENBAO [rendezvous]=$PORT_RENDEZVOUS [openfga]=$PORT_OPENFGA
  )
  for c in database rabbitmq cfssl openbao rendezvous openfga; do
    if ! cr_running "${PREFIX}-${c}"; then
      bad "$(printf '%-11s' "$c") not running"
    elif tcp_open "${ports[$c]}"; then
      ok "$(printf '%-11s' "$c") port ${ports[$c]}"
    else
      warn "$(printf '%-11s' "$c") running, port ${ports[$c]} not answering yet"
    fi
  done

  say "Layout"
  if is_umbrella; then
    info "Mix umbrella — checks run from the repository root"
  else
    info "independent Mix projects — checks run per project directory"
  fi
}

# ---------------------------------------------------------------------- checks

# This branch exists in two layouts: a Mix umbrella with a root mix.exs and
# every app under apps/, and independent Mix projects with libraries under
# libs/. Detect which one we are in rather than assuming.
is_umbrella() {
  [[ -f "${REPO_ROOT}/mix.exs" ]] && grep -q 'apps_path:' "${REPO_ROOT}/mix.exs"
}

# project_dir <name> — where a given app or library lives, "" if absent
project_dir() {
  local name="$1"
  for candidate in "apps/${name}" "libs/${name}" "tools/${name}"; do
    [[ -f "${REPO_ROOT}/${candidate}/mix.exs" ]] && { echo "$candidate"; return 0; }
  done
  echo ""
}

DEFAULT_PROJECTS=(astarte_auth astarte_pairing)
STEPS=(deps compile format credo dialyzer test)

FAILURES=()

# run_step <label> <dir> <command...>
run_step() {
  local label="$1" dir="$2"; shift 2
  local log
  log="$(mktemp "/tmp/astarte-check-XXXXXX.log")"

  printf '    %s%-9s%s %s ' "$DIM" "$label" "$R" "${dir:-.}"
  if (cd "${REPO_ROOT}/${dir:-.}" && "$@") >"$log" 2>&1; then
    printf '%s\n' "${GRN}ok${R}"
    rm -f "$log"
    return 0
  fi

  printf '%s\n' "${RED}FAILED${R}"
  FAILURES+=("${label} in ${dir:-.}")
  printf '%s\n' "${DIM}--- last 25 lines of output ---${R}"
  tail -25 "$log" | sed 's/^/      /'
  printf '%s\n' "${DIM}--- full log: ${log} ---${R}"
  return 1
}

check_project() {
  local name="$1" dir="$2"

  say "Checking ${CYN}${name}${R} ${DIM}(${dir:-umbrella root})${R}"

  for step in "${STEPS[@]}"; do
    case "$step" in
      deps)
        # CI fetches dependencies before every job. Note that on this branch a
        # plain `mix deps.get` also bumps amqp, decimal and protobuf, so it can
        # leave mix.lock dirty — that happens with or without local changes.
        run_step deps "$dir" mix deps.get || true ;;
      compile)
        run_step compile "$dir" mix compile --warnings-as-errors || true ;;
      format)
        run_step format "$dir" mix format --check-formatted || true ;;
      credo)
        run_step credo "$dir" mix credo --strict || true ;;
      dialyzer)
        run_step dialyzer "$dir" mix dialyzer || true ;;
      test)
        run_step test "$dir" mix test --exclude wip || true ;;
    esac
  done
}

cmd_check() {
  local projects=("$@")
  (( ${#projects[@]} == 0 )) && projects=("${DEFAULT_PROJECTS[@]}")

  say "Preflight"
  command -v mix >/dev/null 2>&1 || die "mix is not on PATH — check .tool-versions / asdf"
  info "$(elixir --version | tail -1)"
  cmd_status >/dev/null
  for c in database openbao cfssl rendezvous; do
    cr_running "${PREFIX}-${c}" ||
      warn "${PREFIX}-${c} is not running — tests that need it will fail (run: $0 up)"
  done

  if is_umbrella; then
    # One Mix project: run the checks once at the root, which covers every app.
    say "Umbrella layout — running the checks once at the root"
    check_project "umbrella" ""
  else
    for name in "${projects[@]}"; do
      local dir
      dir="$(project_dir "$name")"
      if [[ -z "$dir" ]]; then
        warn "no mix.exs found for ${name} — skipping"
        FAILURES+=("${name} not found")
        continue
      fi
      check_project "$name" "$dir"
    done
  fi

  echo
  if (( ${#FAILURES[@]} == 0 )); then
    say "${GRN}Everything passed${R}"
    return 0
  fi
  say "${RED}${#FAILURES[@]} check(s) failed${R}"
  for f in "${FAILURES[@]}"; do bad "$f"; done
  return 1
}

# ------------------------------------------------------------------- arguments

usage() {
  sed -n '3,20p' "${BASH_SOURCE[0]}" | sed 's/^#\s\?//'
  exit "${1:-0}"
}

COMMAND=""
ARGS=()

while (( $# )); do
  case "$1" in
    up|down|check|all|status|env) COMMAND="$1"; shift ;;
    --db) DB_FLAVOUR="$2"; shift 2 ;;
    --only) STEPS=("$2"); shift 2 ;;
    --skip) mapfile -t STEPS < <(printf '%s\n' "${STEPS[@]}" | grep -vx "$2"); shift 2 ;;
    --timeout) WAIT_TIMEOUT="$2"; shift 2 ;;
    -h|--help) usage 0 ;;
    *) ARGS+=("$1"); shift ;;
  esac
done

[[ "$DB_FLAVOUR" == "scylla" || "$DB_FLAVOUR" == "cassandra" ]] ||
  die "--db must be scylla or cassandra"

case "$COMMAND" in
  up)     cmd_up ;;
  down)   cmd_down ${ARGS[@]+"${ARGS[@]}"} ;;
  status) cmd_status ;;
  env)    cmd_env ;;
  check)  cmd_check ${ARGS[@]+"${ARGS[@]}"} ;;
  all)    cmd_up && echo && cmd_check ${ARGS[@]+"${ARGS[@]}"} ;;
  "")     usage 1 ;;
  *)      die "unknown command: $COMMAND" ;;
esac
