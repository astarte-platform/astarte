FROM hexpm/elixir:1.20.2-erlang-28.5.0.3-debian-trixie-20260623-slim AS builder

# install build dependencies
# --allow-releaseinfo-change allows to pull from 'oldstable'
RUN apt-get update --allow-releaseinfo-change -y && \
    apt-get install -y build-essential git

WORKDIR /app

# Install hex
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix hex.info

# Pass --build-arg BUILD_ENV=dev to build a dev image
ARG BUILD_ENV=prod

ENV MIX_ENV=$BUILD_ENV

# Cache elixir deps
COPY mix.exs mix.lock ./
RUN mix do deps.get + deps.compile

# Add all the rest
COPY . .

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

COPY --from=builder /app/_build/$BUILD_ENV/rel/astarte_device_fleet_simulator .

CMD ["./bin/astarte_device_fleet_simulator", "start"]
