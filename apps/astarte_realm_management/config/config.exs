# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
import Config

config :astarte_realm_management, ecto_repos: [Astarte.RealmManagement.Repo]

config :astarte_realm_management, Astarte.RealmManagement.Repo, []

import_config "#{config_env()}.exs"
