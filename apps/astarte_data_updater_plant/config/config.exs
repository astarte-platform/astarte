# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :astarte_data_updater_plant, :queue_name,
  "vmq_all"

import_config "#{Mix.env}.exs"
