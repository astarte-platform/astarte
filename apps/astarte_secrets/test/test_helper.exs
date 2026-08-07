modules = [
  :hackney,
  Astarte.DataAccess.Config,
  Astarte.Secrets,
  Astarte.Secrets.Client,
  Astarte.Secrets.Config,
  Astarte.Secrets.Core
]

for module <- modules, do: Mimic.copy(module)

Astarte.Secrets.Config.init()

# fix flakiness due to async tests
Astarte.Secrets.Core.create_nested_namespace(["fdo_owner_keys", "default_instance"])
Astarte.Secrets.Core.create_nested_namespace(["fdo_owner_keys", "instance"])

ExUnit.start(capture_log: true)
