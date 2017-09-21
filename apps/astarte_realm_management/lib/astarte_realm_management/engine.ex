defmodule Astarte.RealmManagement.Engine do
  require Logger
  alias CQEx.Client, as: DatabaseClient

  def install_interface(realm_name, interface_json, opts \\ []) do
    {connection_status, connection_result} = DatabaseClient.new(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: realm_name])

    if String.contains?(String.downcase(interface_json), ["drop", "insert", "delete", "update", "keyspace", "table"]) do
      Logger.warn "Found possible CQL command in JSON interface: #{inspect interface_json}"
    end

    interface_result = Astarte.Core.InterfaceDocument.from_json(interface_json)

    cond do
      interface_result == :error ->
        Logger.warn "Received invalid interface JSON: #{inspect interface_json}"
        {:error, :invalid_interface_document}

      {connection_status, connection_result} == {:error, :shutdown} ->
        {:error, :realm_not_found}

      Astarte.RealmManagement.Queries.is_interface_major_available?(connection_result, elem(interface_result, 1).descriptor.name, elem(interface_result, 1).descriptor.major_version) == true ->
        {:error, :already_installed_interface}

      true ->
        {:ok, interface_document} = interface_result

        if (opts[:async]) do
          Task.start_link(Astarte.RealmManagement.Queries, :install_new_interface, [connection_result, interface_document])
          {:ok, :started}
        else
          Astarte.RealmManagement.Queries.install_new_interface(connection_result, interface_document)
        end
    end
  end

  def update_interface(realm_name, interface_json, opts \\ []) do
    {connection_status, connection_result} = DatabaseClient.new(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: realm_name])

    if String.contains?(String.downcase(interface_json), ["drop", "insert", "delete", "update", "keyspace", "table"]) do
      Logger.warn "Found possible CQL command in JSON interface: #{inspect interface_json}"
    end

    interface_result = Astarte.Core.InterfaceDocument.from_json(interface_json)

    cond do
      interface_result == :error ->
        Logger.warn "Received invalid interface JSON: #{inspect interface_json}"
        {:error, :invalid_interface_document}

      {connection_status, connection_result} == {:error, :shutdown} ->
        {:error, :realm_not_found}

      Astarte.RealmManagement.Queries.is_interface_major_available?(connection_result, elem(interface_result, 1).descriptor.name, elem(interface_result, 1).descriptor.major_version) != true ->
        {:error, :interface_major_version_does_not_exist}

      true ->
        {:ok, interface_document} = interface_result

        if (opts[:async]) do
          Task.start_link(Astarte.RealmManagement.Queries, :update_interface, [connection_result, interface_document])
          {:ok, :started}
        else
          Astarte.RealmManagement.Queries.update_interface(connection_result, interface_document)
        end
    end
  end

  def delete_interface(realm_name, interface_name, interface_major_version, opts \\ []) do
    client = DatabaseClient.new!(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: realm_name])

    cond do
      Astarte.RealmManagement.Queries.is_interface_major_available?(client, interface_name, interface_major_version) == false ->
        {:error, :interface_major_version_does_not_exist}

      true ->
        if (opts[:async]) do
          Task.start_link(Astarte.RealmManagement.Queries, :delete_interface, [client, interface_name, interface_major_version])
          {:ok, :started}
        else
          Astarte.RealmManagement.Queries.delete_interface(client, interface_name, interface_major_version)
        end
    end
  end

  def interface_source(realm_name, interface_name, interface_major_version) do
    case DatabaseClient.new(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: realm_name]) do
      {:error, :shutdown} ->
        {:error, :realm_not_found}

      {:ok, client} ->
        Astarte.RealmManagement.Queries.interface_source(client, interface_name, interface_major_version)
    end
  end

  def list_interface_versions(realm_name, interface_name) do
    case DatabaseClient.new(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: realm_name]) do
      {:error, :shutdown} ->
        {:error, :realm_not_found}

      {:ok, client} ->
        result = Astarte.RealmManagement.Queries.interface_available_versions(client, interface_name)

        if result != [] do
          {:ok, result}
        else
          {:error, :interface_not_found}
        end
    end
  end

  def get_interfaces_list(realm_name) do
    case DatabaseClient.new(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: realm_name]) do
      {:error, :shutdown} ->
        {:error, :realm_not_found}

      {:ok, client} ->
        result = Astarte.RealmManagement.Queries.get_interfaces_list(client)
        {:ok, result}
    end
  end

end
