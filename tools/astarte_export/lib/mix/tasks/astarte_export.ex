defmodule Mix.Tasks.Astarte.Export do
  use Mix.Task
  alias Astarte.Export

  require Logger

  @impl Mix.Task
  @shortdoc "Export data from an existing Astarte realm"
  def run(args) do
    {realm, file_name, device_id, db_host_and_port} = parse_args(args)

    Logger.info("Exporting data from realm #{realm} to file #{file_name}")

    options =
      case {db_host_and_port, device_id} do
        {nil, nil} -> []
        {nil, _} -> [device_id: device_id]
        {_, nil} -> [db_host_and_port: db_host_and_port]
        {_, _} -> [db_host_and_port: db_host_and_port, device_id: device_id]
      end

    case Application.ensure_all_started(:astarte_export) do
      {:ok, _} ->
        Export.export_realm_data(realm, file_name, options)

      {:error, reason} ->
        Logger.error("Cannot start applications: #{inspect(reason)}")
    end
  end

  defp parse_args([realm, file_name | opts]) do
    {device_id, db_host_and_port} = parse_optional_args(opts)
    {realm, file_name, device_id, db_host_and_port}
  end

  defp parse_optional_args([]), do: {nil, nil}

  defp parse_optional_args(["--device_id", device_id | rest]) do
    {device_id, parse_optional_args(rest) |> elem(1)}
  end

  defp parse_optional_args(["--db_host_and_port", db_host_and_port | rest]) do
    {parse_optional_args(rest) |> elem(0), db_host_and_port}
  end

  defp parse_optional_args([_ | rest]), do: parse_optional_args(rest)
end
