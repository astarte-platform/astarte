Code.require_file("astarte/database_test.exs", __DIR__)

:ok = Astarte.Import.Cluster.ensure_registered()

Astarte.DatabaseTestdata.initialize_database()

ExUnit.start()
