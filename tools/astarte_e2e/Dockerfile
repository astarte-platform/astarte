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
ENV ASTARTE_APPS_PATH=/app/astarte_apps/apps

# Cache elixir deps
COPY mix.exs astarte_apps/mix.exs
COPY mix.lock astarte_apps/mix.lock

COPY tools/astarte_e2e ./
COPY apps ./astarte_apps/apps

RUN mix deps.get --only $BUILD_ENV
RUN mix deps.compile

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
