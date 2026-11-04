defmodule Astarte.PairingWeb.GraphQL.Resolvers.AgentResolver do
  @moduledoc """
  Absinthe resolvers for agent-driven device registration.
  """

  alias Astarte.Pairing.Agent
  alias Astarte.Pairing.Agent.DeviceRegistrationResponse
  alias Astarte.PairingWeb.GraphQL.Resolvers.Introspection

  @doc """
  Registers a new device and returns the credentials_secret.
  Authorization is enforced upstream by the AuthorizeFGA middleware.
  """
  def register_device(_parent, args, %{context: context}) do
    realm = Map.fetch!(context, :realm_name)

    params =
      args
      |> Map.take([:hw_id, :initial_introspection])
      |> Map.update(:initial_introspection, %{}, &Introspection.to_map/1)

    with {:ok, %DeviceRegistrationResponse{} = response} <- Agent.register_device(realm, params) do
      {:ok, %{credentials_secret: response.credentials_secret}}
    end
  end

  @doc """
  Unregisters a device.
  Authorization is enforced upstream by the AuthorizeFGA middleware.
  """
  def unregister_device(_parent, %{hw_id: hw_id}, %{context: context}) do
    realm = Map.fetch!(context, :realm_name)

    with :ok <- Agent.unregister_device(realm, hw_id) do
      {:ok, "Device unregistered successfully"}
    end
  end
end
