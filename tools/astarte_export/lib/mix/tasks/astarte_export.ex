defmodule Mix.Tasks.Astarte.Export do
  use Mix.Task
  alias Astarte.Export

  require Logger

  @impl Mix.Task
  @shortdoc "export data from an existing Astarte realm"
  def run([realm, filename]) do
    case Application.ensure_all_started(:astarte_export) do
      {:ok, _} ->
        Export.export_realm_data(realm, filename)

      {:error, reason} ->
        Logger.error("Cannot start applications: #{inspect(reason)}")
    end
  end
end
