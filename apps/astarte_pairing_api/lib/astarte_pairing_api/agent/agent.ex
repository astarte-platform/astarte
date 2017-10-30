defmodule Astarte.Pairing.API.Agent do
  @moduledoc """
  The Agent context.
  """

  alias Astarte.Pairing.API.Agent.APIKey
  alias Astarte.Pairing.API.Agent.APIKeyRequest
  alias Astarte.Pairing.API.RPC.AMQPClient
  alias Astarte.Pairing.API.Utils

  def generate_api_key(attrs \\ %{}) do
    changeset =
      %APIKeyRequest{}
      |> APIKeyRequest.changeset(attrs)

    if changeset.valid? do
      %APIKeyRequest{hw_id: hw_id, realm: realm} = Ecto.Changeset.apply_changes(changeset)
      case AMQPClient.generate_api_key(realm, hw_id) do
        {:ok, api_key} ->
          {:ok, %APIKey{api_key: api_key}}

        {:error, %{} = error_map} ->
          {:error, Utils.error_map_into_changeset(changeset, error_map)}

        _other ->
          {:error, :rpc_error}
      end

    else
      {:error, %{changeset | action: :create}}
    end
  end
end
