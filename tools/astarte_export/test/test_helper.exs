ExUnit.start()
{:ok, _} = Application.ensure_all_started(:astarte_export)
:ok = Astarte.Export.Cluster.ensure_registered()
