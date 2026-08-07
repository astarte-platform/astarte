FROM hexpm/elixir:1.20.2-erlang-28.5.0.3-debian-trixie-20260623-slim AS builder

# install build dependencies
# --allow-releaseinfo-change allows to pull from 'oldstable'
RUN apt-get update --allow-releaseinfo-change -y && \
    apt-get install -y build-essential git --no-install-recommends && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install hex
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix hex.info

# Pass --build-arg BUILD_ENV=dev to build a dev image
ARG BUILD_ENV=prod
ARG SERVICE

ENV MIX_ENV=$BUILD_ENV

# Cache deps: umbrella root + one mix.exs stub per app (single lockfile). Only
# the mix.exs files are staged so unrelated source edits do not re-fetch deps.
COPY mix.exs mix.lock VERSION ./
COPY config ./config
COPY apps/astarte_adapters/mix.exs apps/astarte_adapters/mix.exs
COPY apps/astarte_appengine_api/mix.exs apps/astarte_appengine_api/mix.exs
COPY apps/astarte_config/mix.exs apps/astarte_config/mix.exs
COPY apps/astarte_data_access/mix.exs apps/astarte_data_access/mix.exs
COPY apps/astarte_data_updater_plant/mix.exs apps/astarte_data_updater_plant/mix.exs
COPY apps/astarte_events/mix.exs apps/astarte_events/mix.exs
COPY apps/astarte_fdo_core/mix.exs apps/astarte_fdo_core/mix.exs
COPY apps/astarte_fdo/mix.exs apps/astarte_fdo/mix.exs
COPY apps/astarte_generators/mix.exs apps/astarte_generators/mix.exs
COPY apps/astarte_housekeeping/mix.exs apps/astarte_housekeeping/mix.exs
COPY apps/astarte_pairing/mix.exs apps/astarte_pairing/mix.exs
COPY apps/astarte_realm_management/mix.exs apps/astarte_realm_management/mix.exs
COPY apps/astarte_rpc/mix.exs apps/astarte_rpc/mix.exs
COPY apps/astarte_secrets/mix.exs apps/astarte_secrets/mix.exs
COPY apps/astarte_test_suite/mix.exs apps/astarte_test_suite/mix.exs
COPY apps/astarte_trigger_engine/mix.exs apps/astarte_trigger_engine/mix.exs
COPY apps/astarte_vmq_plugin/mix.exs apps/astarte_vmq_plugin/mix.exs
RUN mix do deps.get + deps.compile

# Add all the rest
COPY apps ./apps
COPY rel ./rel

# Build and release from the umbrella root (releases: defined in mix.exs)
RUN mix compile
RUN mix release $SERVICE

# Note: it is important to keep Debian versions in sync, or incompatibilities between libcrypto will happen
FROM debian:trixie-20260623-slim

WORKDIR /app

RUN chown -R nobody:nogroup /app

# Set the locale
ENV LANG=C.UTF-8

# We need SSL
RUN apt-get update -y && \
    apt-get install openssl ca-certificates -y --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

# We have to redefine this here since it goes out of scope for each build stage
ARG BUILD_ENV=prod
ARG SERVICE

ENV SERVICE_CMD="./bin/$SERVICE start"

COPY --from=builder --chown=nobody:nogroup /app/_build/$BUILD_ENV/rel/$SERVICE .

# Change to non-root user
USER nobody

HEALTHCHECK CMD "./bin/healthcheck"

CMD $SERVICE_CMD
