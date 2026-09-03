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
ENV ASTARTE_LIBRARIES_PATH=libraries

# Cache elixir deps
COPY tools/astarte_e2e/mix.exs ./
COPY tools/astarte_e2e/mix.lock ./
COPY libs/astarte_adapters/mix.exs libraries/astarte_adapters/mix.exs
COPY libs/astarte_adapters/mix.lock libraries/astarte_adapters/mix.lock
COPY libs/astarte_core/mix.exs libraries/astarte_core/mix.exs
COPY libs/astarte_core/mix.lock libraries/astarte_core/mix.lock
COPY libs/astarte_data_access/mix.exs libraries/astarte_data_access/mix.exs
COPY libs/astarte_data_access/mix.lock libraries/astarte_data_access/mix.lock
COPY libs/astarte_events/mix.exs libraries/astarte_events/mix.exs
COPY libs/astarte_events/mix.lock libraries/astarte_events/mix.lock
COPY libs/astarte_fdo/mix.exs libraries/astarte_fdo/mix.exs
COPY libs/astarte_fdo/mix.lock libraries/astarte_fdo/mix.lock
COPY libs/astarte_fdo_core/mix.exs libraries/astarte_fdo_core/mix.exs
COPY libs/astarte_fdo_core/mix.lock libraries/astarte_fdo_core/mix.lock
COPY libs/astarte_generators/mix.exs libraries/astarte_generators/mix.exs
COPY libs/astarte_generators/mix.lock libraries/astarte_generators/mix.lock
COPY libs/astarte_rpc/mix.exs libraries/astarte_rpc/mix.exs
COPY libs/astarte_rpc/mix.lock libraries/astarte_rpc/mix.lock
COPY libs/astarte_secrets/mix.exs libraries/astarte_secrets/mix.exs
COPY libs/astarte_secrets/mix.lock libraries/astarte_secrets/mix.lock
COPY libs/astarte_test_suite/mix.exs libraries/astarte_test_suite/mix.exs
COPY libs/astarte_test_suite/mix.lock libraries/astarte_test_suite/mix.lock

# astarte_core is needed by astarte_device which is a remote dep
RUN mix do deps.get + deps.compile astarte_core + deps.compile --skip-local-deps

COPY libs ./libraries
RUN mix deps.compile

# Add all the rest
COPY tools/astarte_e2e .

# Build and release
RUN mix do compile + release

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

COPY --from=builder /app/_build/$BUILD_ENV/rel/astarte_e2e .

CMD ["./bin/astarte_e2e", "start"]
