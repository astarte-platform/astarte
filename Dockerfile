FROM --platform=${BUILDPLATFORM} hexpm/elixir:1.15.7-erlang-26.1-debian-bookworm-20230612-slim as base

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

ARG BUILD_ENV=prod

ENV MIX_ENV=${BUILD_ENV}

# Cache elixir deps
ADD mix.exs mix.lock ./
RUN mix do deps.get --only ${MIX_ENV}, deps.compile

FROM deps as builder

ENV MIX_ENV=${BUILD_ENV}

# Add all the rest
ADD . .
ENTRYPOINT [ "/bin/sh", "-c" ]
# ------------------------
# Only for production
FROM builder as release

ENV MIX_ENV=${BUILD_ENV}

COPY --from=builder /src .

WORKDIR /src
RUN mix do compile, release

RUN mkdir -p /rel && \
    cp -r _build/$BUILD_ENV/rel /rel
# Check if entrypoint.sh exists,
# otherwise a default script is created
RUN if [ -f "./entrypoint.sh" ]; then \
    cp ./entrypoint.sh /rel/entrypoint.sh; \
    else \
    echo '#!/bin/bash' >> /rel/entrypoint.sh; \
    echo exec \$@ >> /rel/entrypoint.sh; \
    fi; \
    chmod +x /rel/entrypoint.sh

# Note: it is important to keep Debian versions in sync, 
# or incompatibilities between libcrypto will happen
FROM --platform=${BUILDPLATFORM} debian:bookworm-slim

# Set the locale
ENV LANG C.UTF-8

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
    ln -s ${APP_NAME}/bin/${APP_NAME} astarte-service 

USER nobody

ENTRYPOINT [ "./entrypoint.sh" ]
CMD ["./astarte-service", "start"]
