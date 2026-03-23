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

ExUnit.start(capture_log: true)
