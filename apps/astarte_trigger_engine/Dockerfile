FROM elixir:1.6.5-slim as builder

RUN apt-get -qq update
RUN apt-get -qq install git build-essential curl

RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix hex.info

WORKDIR /app
ENV MIX_ENV prod
ADD . .
RUN mix deps.get
RUN mix release --env=$MIX_ENV

# Note: it is important to keep Debian versions in sync, or incompatibilities between libcrypto will happen
FROM debian:stretch-slim
RUN apt-get -qq update

# Set the locale
ENV LANG C.UTF-8

# We need SSL
RUN apt-get -qq install libssl1.1

WORKDIR /app
COPY --from=builder /app/_build/prod/rel/astarte_trigger_engine .

CMD ["./bin/astarte_trigger_engine", "foreground"]
