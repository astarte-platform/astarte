FROM elixir:1.11.4 as builder

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
FROM debian:buster-slim

WORKDIR /app

RUN apt-get -qq update

# Set the locale
ENV LANG C.UTF-8

# We need SSL
RUN apt-get -qq install libssl1.1

# We have to redefine this here since it goes out of scope for each build stage
ARG BUILD_ENV=prod

COPY --from=builder /app/_build/$BUILD_ENV/rel/astarte_housekeeping .
COPY --from=builder /app/entrypoint.sh .

ENTRYPOINT ["/bin/bash", "entrypoint.sh"]
CMD ["start"]
