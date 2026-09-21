import Config

config :astarte_secrets, :dek_cache_ttl_seconds, 5 * 60

import_config "#{config_env()}.exs"
