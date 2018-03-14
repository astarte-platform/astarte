defmodule Astarte.AppEngine.API.Queries do
  alias CQEx.Query, as: DatabaseQuery
  alias CQEx.Result, as: DatabaseResult

  def fetch_public_key(client) do
    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "SELECT blobAsVarchar(value) FROM kv_store WHERE group='auth' AND key='jwt_public_key_pem'"
      )

    result =
      DatabaseQuery.call!(client, query)
      |> DatabaseResult.head()

    case result do
      ["system.blobasvarchar(value)": public_key] ->
        {:ok, public_key}

      :empty_dataset ->
        {:error, :public_key_not_found}
    end
  end
end
