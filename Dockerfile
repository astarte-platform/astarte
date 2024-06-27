FROM hexpm/elixir:1.15.7-erlang-26.1-debian-bookworm-20230612-slim as base

# install build dependencies
# --allow-releaseinfo-change allows to pull from 'oldstable'
RUN apt-get update --allow-releaseinfo-change -y && \
    apt-get install -y \
    build-essential \
    git \
    openssl \
    ca-certificates \
    inotify-tools && \
    apt-get clean && \
    rm -f /var/lib/apt/lists/*_*

# Install hex
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix hex.info

WORKDIR /src

FROM base as deps
# Cache elixir deps
ADD mix.exs mix.lock ./
RUN mix do deps.get, deps.compile

FROM deps as builder
# Add all the rest
ADD . .

# ------------------------
# Only for production
FROM builder as release

ARG BUILD_ENV=prod
ENV MIX_ENV=$BUILD_ENV

COPY --from=builder /src .

WORKDIR /src
RUN mix do compile, release

RUN mkdir -p /rel && \
    cp -r _build/$BUILD_ENV/rel /rel
# Check if pre-cmd.sh exists,
# otherwise a dummy script is created
RUN if [ -f "./pre-cmd.sh" ]; then \
    cp ./pre-cmd.sh /rel/pre-cmd.sh; \
    else \
    echo "echo No pre-cmd instruction" >> /rel/pre-cmd.sh; \
    fi; \
    chmod +x /rel/pre-cmd.sh

# Note: it is important to keep Debian versions in sync, 
# or incompatibilities between libcrypto will happen
FROM debian:bookworm-slim

# Set the locale
ENV LANG C.UTF-8
ENV ASTARTE_SERVICE=astarte-service

# We need SSL
RUN apt-get -qq update -y && \
    apt-get -qq install \
    openssl \
    ca-certificates \
    && apt-get clean \
    && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

COPY --from=release --chown=nobody:nobody /rel/* .

# Symlink to the service, to make a single entry point 
# for all the apps
RUN APP_NAME=$(ls | head -n 1) && \
    ln -s ${APP_NAME}/bin/${APP_NAME} ${ASTARTE_SERVICE} 

USER nobody
CMD ./pre-cmd.sh && ./${ASTARTE_SERVICE} start
