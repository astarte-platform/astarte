FROM hexpm/elixir:1.15.7-erlang-26.1-debian-bookworm-20230612-slim AS builder

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
COPY apps/astarte_realm_management/mix.exs ./
COPY apps/astarte_realm_management/mix.lock ./
COPY libs/astarte_data_access/mix.exs libraries/astarte_data_access/mix.exs
COPY libs/astarte_data_access/mix.lock libraries/astarte_data_access/mix.lock
COPY libs/astarte_events/mix.exs libraries/astarte_events/mix.exs
COPY libs/astarte_events/mix.lock libraries/astarte_events/mix.lock
RUN mix do deps.get, deps.compile --skip-local-deps

COPY libs ./libraries
RUN mix deps.compile

# Add all the rest
COPY apps/astarte_realm_management .

# Build and release
RUN mix do compile, release

# Note: it is important to keep Debian versions in sync, or incompatibilities between libcrypto will happen
FROM debian:bookworm-20230612-slim

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

COPY --from=builder --chown=nobody:nogroup /app/_build/$BUILD_ENV/rel/astarte_realm_management .

# Change to non-root user
USER nobody

CMD ["./bin/astarte_realm_management", "start"]
