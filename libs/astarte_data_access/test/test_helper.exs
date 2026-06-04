modules = [
  Astarte.DataAccess.Config,
  Astarte.DataAccess.Realms.Realm,
  Astarte.DataAccess.Repo,
  Xandra
]

for module <- modules, do: Mimic.copy(module)

ExUnit.start(capture_log: true)
