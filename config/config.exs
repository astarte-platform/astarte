# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config

for app <- [
      :astarte_appengine_api,
      :astarte_data_updater_plant,
      :astarte_housekeeping,
      :astarte_pairing,
      :astarte_realm_management,
      :astarte_trigger_engine
    ] do
  import_config "../apps/#{app}/config/config.exs"
end
