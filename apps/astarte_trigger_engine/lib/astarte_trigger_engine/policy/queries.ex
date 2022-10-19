defmodule Astarte.TriggerEngine.Policy.Queries do
  require Logger

  alias Astarte.Core.Triggers.Policy
  alias Astarte.Core.Realm

  def retrieve_policy_data(realm_name, policy_name) do
    with :ok <- validate_realm_name(realm_name),
         :ok <- validate_policy_name(policy_name),
         {:ok, policy} <-
           Xandra.Cluster.run(:xandra, fn conn ->
             do_retrieve_policy_data(conn, realm_name, policy_name)
           end) do
      {:ok, policy}
    else
      {:error, reason} ->
        _ =
          Logger.warn("Cannot retrieve policy data: #{inspect(reason)}.",
            tag: "policy_retrieve_failed"
          )

        {:error, reason}
    end
  end

  defp do_retrieve_policy_data(conn, realm_name, policy_name) do
    retrieve_statement =
      "SELECT value FROM #{realm_name}.kv_store WHERE group='trigger_policy' AND key=:policy_name;"

    with {:ok, prepared} <-
           Xandra.prepare(conn, retrieve_statement),
         {:ok, %Xandra.Page{} = page} <-
           Xandra.execute(conn, prepared, %{"policy_name" => policy_name}),
         [%{"value" => policy}] <- Enum.to_list(page) do
      {:ok, policy}
    else
      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warn("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warn("Database connection error: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
    end
  end

  defp validate_realm_name(realm_name) do
    if Realm.valid_name?(realm_name) do
      :ok
    else
      _ =
        Logger.warn("Invalid realm name.",
          tag: "invalid_realm_name",
          realm: realm_name
        )

      {:error, :realm_not_allowed}
    end
  end

  defp validate_policy_name(policy_name) do
    if Policy.valid_name?(policy_name) do
      :ok
    else
      _ =
        Logger.warn("Invalid policy name.",
          tag: "invalid_policy_name",
          policy: policy_name
        )

      {:error, :policy_not_allowed}
    end
  end
end
