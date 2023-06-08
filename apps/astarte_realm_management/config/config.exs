# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
import Config

# lager is used by rabbit_common.
# Silent it by setting the higher loglevel.
config :lager,
  error_logger_redirect: false,
  handlers: [level: :critical]

import_config "#{config_env}.exs"
