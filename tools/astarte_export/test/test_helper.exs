Code.require_file("database_test.exs", __DIR__)

:ok = Astarte.Export.Cluster.ensure_registered()

Astarte.DatabaseTestdata.initialize_database()

ExUnit.start()
