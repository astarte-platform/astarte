FROM elixir:1.6.5-slim as builder

RUN apt-get -qq update
RUN apt-get -qq install git build-essential

RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix hex.info


WORKDIR /build
ARG BUILD_BRANCH=master
ENV MIX_ENV prod


RUN git clone https://github.com/astarte-platform/astarte_appengine_api.git -b $BUILD_BRANCH \
    && cd astarte_appengine_api \
    && mix deps.get \
    && mix release --env=$MIX_ENV

RUN git clone https://github.com/astarte-platform/astarte_data_updater_plant.git -b $BUILD_BRANCH \
    && cd astarte_data_updater_plant \
    && mix deps.get \
    && mix release --env=$MIX_ENV

RUN git clone https://github.com/astarte-platform/astarte_housekeeping.git -b $BUILD_BRANCH \
    && cd astarte_housekeeping \
    && mix deps.get \
    && mix release --env=$MIX_ENV

RUN git clone https://github.com/astarte-platform/astarte_housekeeping_api.git -b $BUILD_BRANCH \
    && cd astarte_housekeeping_api \
    && mix deps.get \
    && mix release --env=$MIX_ENV

RUN git clone https://github.com/astarte-platform/astarte_pairing.git -b $BUILD_BRANCH \
    && cd astarte_pairing \
    && mix deps.get \
    && mix release --env=$MIX_ENV

RUN git clone https://github.com/astarte-platform/astarte_pairing_api.git -b $BUILD_BRANCH \
    && cd  astarte_pairing_api \
    && mix deps.get \
    && mix release --env=$MIX_ENV

RUN git clone https://github.com/astarte-platform/astarte_realm_management.git -b $BUILD_BRANCH \
    && cd  astarte_realm_management \
    && mix deps.get \
    && mix release --env=$MIX_ENV

RUN git clone https://github.com/astarte-platform/astarte_realm_management_api.git -b $BUILD_BRANCH \
    && cd  astarte_realm_management_api \
    && mix deps.get \
    && mix release --env=$MIX_ENV

RUN git clone https://github.com/astarte-platform/astarte_trigger_engine.git -b $BUILD_BRANCH \
    && cd  astarte_trigger_engine \
    && mix deps.get \
    && mix release --env=$MIX_ENV

# Note: it is important to keep Debian versions in sync, or incompatibilities between libcrypto will happen
FROM debian:stretch-slim
RUN apt-get -qq update

# Set the locale
ENV LANG C.UTF-8

# We need SSL
RUN apt-get -qq install libssl1.1 supervisor

WORKDIR /app
COPY --from=builder /build/astarte_appengine_api/_build/prod/rel/astarte_appengine_api astarte_appengine_api
COPY --from=builder /build/astarte_data_updater_plant/_build/prod/rel/astarte_data_updater_plant astarte_data_updater_plant
COPY --from=builder /build/astarte_housekeeping/_build/prod/rel/astarte_housekeeping astarte_housekeeping
COPY --from=builder /build/astarte_housekeeping_api/_build/prod/rel/astarte_housekeeping_api astarte_housekeeping_api
COPY --from=builder /build/astarte_pairing/_build/prod/rel/astarte_pairing astarte_pairing
COPY --from=builder /build/astarte_pairing_api/_build/prod/rel/astarte_pairing_api astarte_pairing_api
COPY --from=builder /build/astarte_realm_management/_build/prod/rel/astarte_realm_management astarte_realm_management
COPY --from=builder /build/astarte_realm_management_api/_build/prod/rel/astarte_realm_management_api astarte_realm_management_api
COPY --from=builder /build/astarte_trigger_engine/_build/prod/rel/astarte_trigger_engine astarte_trigger_engine

ADD supervisor.conf /etc/supervisor.conf

# astarte_realm_management_api
EXPOSE 4000
# astarte_housekeeping_api
EXPOSE 4001
# astarte_appengine_api
EXPOSE 4002
# astarte_pairing_api
EXPOSE 4003

CMD supervisord -c /etc/supervisor.conf
