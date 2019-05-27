# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# lager is used by rabbit_common.
# Silent it by setting the higher loglevel.
config :lager,
  error_logger_redirect: false,
  handlers: [level: :critical]

# make amqp supervisors logs less verbose
config :logger, handle_otp_reports: false

import_config "#{Mix.env}.exs"
