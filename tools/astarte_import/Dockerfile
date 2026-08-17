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
ENV MIX_ENV=$BUILD_ENV
ENV ASTARTE_LIBRARIES_PATH=libraries/apps

# Cache elixir deps
COPY tools/astarte_import/mix.exs ./
COPY tools/astarte_import/mix.lock ./
COPY mix.lock libraries/mix.lock
COPY apps/astarte_adapters/mix.exs libraries/apps/astarte_adapters/mix.exs
COPY apps/astarte_data_access/mix.exs libraries/apps/astarte_data_access/mix.exs
COPY apps/astarte_events/mix.exs libraries/apps/astarte_events/mix.exs
COPY apps/astarte_fdo/mix.exs libraries/apps/astarte_fdo/mix.exs
COPY apps/astarte_fdo_core/mix.exs libraries/apps/astarte_fdo_core/mix.exs
COPY apps/astarte_generators/mix.exs libraries/apps/astarte_generators/mix.exs
COPY apps/astarte_rpc/mix.exs libraries/apps/astarte_rpc/mix.exs
COPY apps/astarte_secrets/mix.exs libraries/apps/astarte_secrets/mix.exs
COPY apps/astarte_test_suite/mix.exs libraries/apps/astarte_test_suite/mix.exs
RUN mix do deps.get + deps.compile --skip-local-deps

COPY apps/astarte_adapters libraries/apps/astarte_adapters
COPY apps/astarte_data_access libraries/apps/astarte_data_access
COPY apps/astarte_events libraries/apps/astarte_events
COPY apps/astarte_fdo libraries/apps/astarte_fdo
COPY apps/astarte_fdo_core libraries/apps/astarte_fdo_core
COPY apps/astarte_generators libraries/apps/astarte_generators
COPY apps/astarte_rpc libraries/apps/astarte_rpc
COPY apps/astarte_secrets libraries/apps/astarte_secrets
COPY apps/astarte_test_suite libraries/apps/astarte_test_suite
RUN mix deps.compile

# Add all the rest
COPY tools/astarte_import .

# Build and release
RUN mix do compile + release

# Note: it is important to keep Debian versions in sync, or incompatibilities between libcrypto will happen
FROM debian:trixie-20260623-slim

WORKDIR /app

# Set the locale
ENV LANG=C.UTF-8

# We need SSL
RUN apt-get update -y && \
    apt-get install openssl ca-certificates -y --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

# We have to redefine this here since it goes out of scope for each build stage
ARG BUILD_ENV=prod

WORKDIR /app
COPY --from=builder /app/_build/prod/rel/astarte_import .

CMD ["sh", "-c", "./bin/astarte_import start ${REALM} ${XML_FILE}"]
