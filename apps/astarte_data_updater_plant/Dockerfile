FROM hexpm/elixir:1.15.7-erlang-26.1-debian-bookworm-20230612-slim AS builder

# install build dependencies
# --allow-releaseinfo-change allows to pull from 'oldstable'
RUN apt-get update --allow-releaseinfo-change -y && apt-get install -y build-essential git \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

# Install hex
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix hex.info

# Pass --build-arg BUILD_ENV=dev to build a dev image
ARG BUILD_ENV=prod

ENV MIX_ENV=$BUILD_ENV

# Cache elixir deps
ADD mix.exs mix.lock ./
RUN mix do deps.get, deps.compile

# Add all the rest
ADD . .

# Build and release
RUN mix do compile, release

# Note: it is important to keep Debian versions in sync, or incompatibilities between libcrypto will happen
FROM debian:bookworm-slim

WORKDIR /app

RUN chown -R nobody /app

RUN apt-get -qq update

# Set the locale
ENV LANG=C.UTF-8

# We need SSL
RUN apt-get -qq install openssl ca-certificates

# We have to redefine this here since it goes out of scope for each build stage
ARG BUILD_ENV=prod

COPY --from=builder /app/_build/$BUILD_ENV/rel/astarte_data_updater_plant .

# Change to non-root user
USER nobody

CMD ["./bin/astarte_data_updater_plant", "start"]
