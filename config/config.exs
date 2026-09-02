import Config

config :astarte_trigger_engine, :events_consumer, Astarte.TriggerEngine.EventsConsumer

import_config "#{config_env()}.exs"
