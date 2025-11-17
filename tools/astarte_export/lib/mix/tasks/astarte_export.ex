defmodule Mix.Tasks.Astarte.Export do
  use Mix.Task
  alias Astarte.Export

  require Logger

  @impl Mix.Task
  @shortdoc "export data from an existing Astarte realm"
  def run([realm, filename]) do
    with {:ok, _} <- Application.ensure_all_started(:astarte_export),
         :ok <- Astarte.Export.Cluster.ensure_registered() do
      Export.export_realm_data(realm, filename)
    else
      {:error, reason} ->
        Logger.error("Cannot start applications: #{inspect(reason)}")
    end
  end
end
