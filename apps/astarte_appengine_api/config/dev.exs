# Copyright 2017-2023 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

import Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with brunch.io to recompile .js and .css sources.
config :astarte_appengine_api, Astarte.AppEngine.APIWeb.Endpoint,
  http: [port: 4002],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: []

config :logger, :console,
  format: {PrettyLog.LogfmtFormatter, :format},
  metadata: [
    :method,
    :request_path,
    :status_code,
    :elapsed,
    :realm,
    :group_name,
    :device_alias,
    :device_id,
    :interface,
    :path,
    :module,
    :function,
    :request_id,
    :tag
  ]

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20
