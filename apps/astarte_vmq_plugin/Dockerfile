FROM hexpm/elixir:1.20.2-erlang-28.5.0.3-debian-trixie-20260623-slim AS builder

# install build dependencies
# --allow-releaseinfo-change allows to pull from 'oldstable'
RUN apt-get update --allow-releaseinfo-change -y \
  && apt-get install -y build-essential git curl \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /build

# TODO check if it's still needed for VerneMQ 2.0.1
RUN apt-get -qq update && apt-get -qq install libsnappy-dev libssl-dev

# Let's start by building VerneMQ
RUN git clone https://github.com/vernemq/vernemq.git

RUN cd vernemq && \
  git checkout 2.2.0 && \
  make rel && \
  cd ..

RUN mix local.hex --force && \
  mix local.rebar --force && \
  mix hex.info

ENV MIX_ENV=prod

# Pass --build-arg BUILD_ENV=dev to build a dev image
ARG BUILD_ENV=prod

ENV MIX_ENV=$BUILD_ENV

# Cache deps: umbrella root + one mix.exs stub per app (single lockfile). Only
# the mix.exs files are staged so unrelated source edits do not re-fetch deps.
COPY mix.exs mix.lock VERSION ./
COPY config ./config
COPY apps/astarte_adapters/mix.exs apps/astarte_adapters/mix.exs
COPY apps/astarte_appengine_api/mix.exs apps/astarte_appengine_api/mix.exs
COPY apps/astarte_config/mix.exs apps/astarte_config/mix.exs
COPY apps/astarte_data_access/mix.exs apps/astarte_data_access/mix.exs
COPY apps/astarte_data_updater_plant/mix.exs apps/astarte_data_updater_plant/mix.exs
COPY apps/astarte_events/mix.exs apps/astarte_events/mix.exs
COPY apps/astarte_fdo_core/mix.exs apps/astarte_fdo_core/mix.exs
COPY apps/astarte_fdo/mix.exs apps/astarte_fdo/mix.exs
COPY apps/astarte_generators/mix.exs apps/astarte_generators/mix.exs
COPY apps/astarte_housekeeping/mix.exs apps/astarte_housekeeping/mix.exs
COPY apps/astarte_pairing/mix.exs apps/astarte_pairing/mix.exs
COPY apps/astarte_realm_management/mix.exs apps/astarte_realm_management/mix.exs
COPY apps/astarte_rpc/mix.exs apps/astarte_rpc/mix.exs
COPY apps/astarte_secrets/mix.exs apps/astarte_secrets/mix.exs
COPY apps/astarte_test_suite/mix.exs apps/astarte_test_suite/mix.exs
COPY apps/astarte_trigger_engine/mix.exs apps/astarte_trigger_engine/mix.exs
COPY apps/astarte_vmq_plugin/mix.exs apps/astarte_vmq_plugin/mix.exs
RUN mix do deps.get + deps.compile

# Add all the rest
COPY apps ./apps
COPY rel ./rel

# Build and release from the umbrella root (releases: defined in mix.exs)
RUN mix compile
RUN mix release astarte_vmq_plugin

# Copy the schema over
RUN cp apps/astarte_vmq_plugin/priv/astarte_vmq_plugin.schema vernemq/_build/default/rel/vernemq/share/schema/

# Copy configuration files here - mainly because we want to keep the target image as small as possible
# and avoid useless layers.
COPY apps/astarte_vmq_plugin/docker/files/vm.args vernemq/_build/default/rel/vernemq/etc/
COPY apps/astarte_vmq_plugin/docker/files/vernemq.conf vernemq/_build/default/rel/vernemq/etc/
COPY apps/astarte_vmq_plugin/docker/bin/rand_cluster_node.escript vernemq/_build/default/rel/vernemq/bin/

# Note: it is important to keep Debian versions in sync, or incompatibilities between libcrypto will happen
FROM debian:trixie-20260623-slim

# Set the locale
ENV LANG=C.UTF-8

# We have to redefine this here since it goes out of scope for each build stage
ARG BUILD_ENV=prod

# Install some VerneMQ scripts dependencies
RUN apt-get -qq update && apt-get -qq install bash procps openssl iproute2 curl jq libsnappy-dev net-tools nano

# We need SSL, curl, iproute2 and jq - and to ensure /etc/ssl/astarte
# TODO some of these might not be needed anymore
RUN apt-get -qq update && apt-get -qq install libssl3t64 curl jq iproute2 ncat && apt-get clean && mkdir -p /etc/ssl/astarte

ENV PATH="/opt/vernemq/bin:$PATH"

COPY --from=builder /build/apps/astarte_vmq_plugin/docker/bin/vernemq.sh /usr/sbin/start_vernemq
COPY --from=builder /build/apps/astarte_vmq_plugin/docker/bin/join_cluster.sh /usr/sbin/join_cluster

RUN chmod +x /usr/sbin/start_vernemq
RUN chmod +x /usr/sbin/join_cluster

# Copy our built stuff (both are self-contained with their ERTS release)
COPY --from=builder /build/vernemq/_build/default/rel/vernemq /opt/vernemq/

RUN ln -s /opt/vernemq/etc /etc/vernemq && \
    ln -s /opt/vernemq/data /var/lib/vernemq && \
    ln -s /opt/vernemq/log /var/log/vernemq

COPY --from=builder /build/_build/$BUILD_ENV/rel/astarte_vmq_plugin /opt/astarte_vmq_plugin/

# Ports
# 80  Webroot ACME verification (in case)
# 1883  MQTT
# 1885  MQTT for Reverse Proxy
# 8883  MQTT/SSL
# 8080  MQTT WebSockets
# 44053 VerneMQ Message Distribution
# 4369  EPMD - Erlang Port Mapper Daemon
# 8888  Health, API, Prometheus Metrics
# 9100 9101 9102 9103 9104 9105 9106 9107 9108 9109  Specific Distributed Erlang Port Range

EXPOSE 80 1883 1885 8883 8080 44053 4369 8888 \
       9100 9101 9102 9103 9104 9105 9106 9107 9108 9109

VOLUME ["/opt/vernemq/log", "/opt/vernemq/data", "/opt/vernemq/etc"]

HEALTHCHECK CMD vernemq ping | grep -q pong

CMD ["start_vernemq"]
