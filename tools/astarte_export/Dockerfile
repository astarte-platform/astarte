FROM hexpm/elixir:1.15.7-erlang-25.3.2.7-debian-bullseye-20231009-slim AS builder

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
COPY tools/astarte_export/mix.exs ./
COPY tools/astarte_export/mix.lock ./
COPY libs/astarte_data_access/mix.exs libraries/astarte_data_access/mix.exs
COPY libs/astarte_data_access/mix.lock libraries/astarte_data_access/mix.lock
RUN mix do deps.get, deps.compile --skip-local-deps

COPY libs ./libraries
RUN mix deps.compile

# Add all the rest
COPY tools/astarte_export .

# Build and release
RUN mix do compile, release

# Note: it is important to keep Debian versions in sync, or incompatibilities between libcrypto will happen
FROM debian:bullseye-20231009-slim

WORKDIR /app

# Set the locale
ENV LANG=C.UTF-8

# We need SSL
RUN apt-get update -y && \
    apt-get install libssl1.1 -y --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

# We have to redefine this here since it goes out of scope for each build stage
ARG BUILD_ENV=prod
COPY ./run_export.sh /app/
COPY --from=builder /app/_build/$BUILD_ENV/rel/astarte_export .

CMD ["sh", "/app/run_export.sh"]
