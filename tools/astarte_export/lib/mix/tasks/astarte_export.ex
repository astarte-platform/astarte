defmodule Mix.Tasks.Astarte.Export do
  use Mix.Task
  alias Astarte.Export

  require Logger

  @impl Mix.Task
  @shortdoc "export data from an existing Astarte realm"
  def run(args) do
    case args do
      [realm, file_name] ->
        Logger.info("Exporting data from realm #{realm} to file #{file_name}")

        case Application.ensure_all_started(:astarte_export) do
          {:ok, _} ->
            Export.export_realm_data(realm, file_name)

          {:error, reason} ->
            Logger.error("Cannot start applications: #{inspect(reason)}")
        end

      [realm, file_name, device_id] ->
        Logger.info(
          "Exporting data for device #{device_id} from realm #{realm} to file #{file_name}"
        )

        options = [device_id: device_id]

        case Application.ensure_all_started(:astarte_export) do
          {:ok, _} ->
            Export.export_realm_data(realm, file_name, options)

          {:error, reason} ->
            Logger.error("Cannot start applications: #{inspect(reason)}")
        end
    end
  end
end
