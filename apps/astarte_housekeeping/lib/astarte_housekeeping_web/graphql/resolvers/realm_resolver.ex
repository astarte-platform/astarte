defmodule Astarte.HousekeepingWeb.GraphQL.Resolvers.RealmResolver do
  @moduledoc """
  GraphQL Resolvers for Realm management operations in Astarte Housekeeping.
  """
  alias Astarte.Housekeeping.Config
  alias Astarte.Housekeeping.Realms
  alias Astarte.Housekeeping.Realms.Realm

  def list_realms(_parent, _args, _resolution) do
    case Realms.list_realms() do
      {:ok, realms} ->
        {:ok, realms}

      {:error, reason} ->
        {:error, format_error(reason)}
    end
  end

  def get_realm(_parent, %{realm_name: realm_name}, _resolution) do
    case Realms.get_realm(realm_name) do
      {:ok, %Realm{} = realm} -> {:ok, realm}
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  def create_realm(_parent, args, _resolution) do
    async_operation = Map.get(args, :async_operation, true)

    case Realms.create_realm(args.data, async_operation: async_operation) do
      {:ok, %Realm{} = realm} -> {:ok, realm}
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  def update_realm(_parent, %{realm_name: realm_name, data: data}, _resolution) do
    update_params = normalize_update_attrs(data)

    case Realms.update_realm(realm_name, update_params) do
      {:ok, %Realm{} = realm} -> {:ok, realm}
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  def delete_realm(_parent, %{realm_name: realm_name} = args, _resolution) do
    async_operation = Map.get(args, :async_operation, true)

    case Realms.delete_realm(realm_name, async_operation: async_operation) do
      :ok -> {:ok, "Realm deleted successfully"}
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  def get_default_replication(_parent, _args, _resolution) do
    strategy = Config.astarte_keyspace_replication_strategy!()

    replication =
      case strategy do
        s when s in [:simple_strategy, "simple_strategy", "SimpleStrategy"] ->
          %{
            replication_class: "simple_strategy",
            replication_factor: Config.astarte_keyspace_replication_factor!()
          }

        s
        when s in [
               :network_topology_strategy,
               "network_topology_strategy",
               "NetworkTopologyStrategy"
             ] ->
          %{
            replication_class: "network_topology_strategy",
            datacenter_replication_factor: Config.astarte_keyspace_network_replication_map!()
          }

        _ ->
          %{
            replication_class: "network_topology_strategy",
            datacenter_replication_factor: %{}
          }
      end

    {:ok, replication}
  end

  defp normalize_update_attrs(update_attrs) when is_map(update_attrs) do
    update_attrs
    |> Map.replace_lazy(:device_registration_limit, &normalize_integer_or_nil/1)
    |> Map.replace_lazy("device_registration_limit", &normalize_integer_or_nil/1)
    |> Map.replace_lazy(:datastream_maximum_storage_retention, &normalize_integer_or_nil/1)
    |> Map.replace_lazy("datastream_maximum_storage_retention", &normalize_integer_or_nil/1)
  end

  defp normalize_integer_or_nil(value) when is_nil(value), do: :unset
  defp normalize_integer_or_nil(value), do: value

  defp format_error(:realm_not_found), do: "Realm not found"
  defp format_error(:realm_already_exists), do: "Realm already exists"
  defp format_error(:realm_deletion_disabled), do: "Realm deletion disabled"
  defp format_error(:connected_devices_present), do: "Connected devices present"
  defp format_error(reason) when is_binary(reason), do: reason

  defp format_error(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> inspect()
  end

  defp format_error(reason), do: inspect(reason)
end
