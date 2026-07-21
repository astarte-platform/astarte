defmodule Astarte.PairingWeb.GraphQL.Resolvers.AgentResolver do
  alias Astarte.Pairing.Agent
  alias Astarte.Pairing.Agent.DeviceRegistrationResponse

  @doc """
  Registers a new device and returns the credentials_secret.
  Authorization is enforced upstream by the AuthorizeFGA middleware.
  """
  def register_device(_parent, args, %{context: context}) do
    realm = Map.fetch!(context, :realm_name)
    params = %{"hw_id" => args.hw_id}

    params =
      case Map.get(args, :initial_introspection) do
        nil ->
          params

        entries ->
          intro_map =
            Map.new(entries, fn %{interface: i, major_version: major, minor_version: minor} ->
              {i, %{"major" => major, "minor" => minor}}
            end)

          Map.put(params, "initial_introspection", intro_map)
      end

    case Agent.register_device(realm, params) do
      {:ok, %DeviceRegistrationResponse{} = response} ->
        {:ok, %{credentials_secret: response.credentials_secret}}

      {:error, reason} ->
        {:error, "Failed to register the device: #{inspect(reason)}"}
    end
  end

  @doc """
  Unregisters a device.
  Authorization is enforced upstream by the AuthorizeFGA middleware.
  """
  def unregister_device(_parent, %{hw_id: hw_id}, %{context: context}) do
    realm = Map.fetch!(context, :realm_name)

    :telemetry.execute([:astarte, :pairing, :unregister_device], %{}, %{realm: realm})

    case Agent.unregister_device(realm, hw_id) do
      :ok -> {:ok, "Device unregistered successfully"}
      {:error, reason} -> {:error, "Failed to unregister the device: #{inspect(reason)}"}
    end
  end
end
