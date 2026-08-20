defmodule Astarte.PairingWeb.GraphQL.Resolvers.DeviceResolver do
  @moduledoc """
  Absinthe resolvers for device-facing GraphQL fields: retrieving device
  status and obtaining MQTT credentials.
  """

  alias Astarte.Pairing.Credentials
  alias Astarte.Pairing.Info

  @doc """
  Retrieves device status information using the device credentials secret.
  """
  def get_device(_parent, %{hw_id: hw_id}, %{context: context}) do
    with_device_context(context, fn realm, secret ->
      case Info.get_device_info(realm, hw_id, secret) do
        {:ok, device_info} ->
          {:ok, format_device_response(hw_id, device_info)}

        {:error, reason} ->
          {:error, "Failed to retrieve the device: #{inspect(reason)}"}
      end
    end)
  end

  @doc """
  Requests an MQTT client certificate for the device by submitting its CSR
  to Astarte's CA.
  """
  def obtain_credentials(_parent, %{hw_id: hw_id, csr: csr}, %{context: context}) do
    with_device_context(context, fn realm, secret ->
      device_ip = Map.get(context, :device_ip, "127.0.0.1")
      params = %{csr: csr}

      case Credentials.get_astarte_mqtt_v1(realm, hw_id, secret, device_ip, params) do
        {:ok, %{client_crt: client_crt}} ->
          {:ok, %{client_crt: client_crt}}

        {:error, reason} ->
          {:error, "Failed to generate the certificate: #{inspect(reason)}"}
      end
    end)
  end

  @doc """
  Checks whether a device's MQTT client certificate is still valid.
  """
  def verify_credentials(_parent, %{hw_id: hw_id, client_crt: client_crt}, %{context: context}) do
    with_device_context(context, fn realm, secret ->
      params = %{client_crt: client_crt}

      case Credentials.verify_astarte_mqtt_v1(realm, hw_id, secret, params) do
        {:ok, status} ->
          {:ok,
           %{
             valid: status.valid,
             timestamp: status.timestamp,
             until: status.until,
             cause: if(status.cause, do: to_string(status.cause), else: nil),
             details: status.details
           }}

        {:error, reason} ->
          {:error, "Failed to verify the certificate: #{inspect(reason)}"}
      end
    end)
  end

  # These endpoints authenticate the caller via the device's own credentials
  # secret (not an Agent JWT), so this check isn't handled by AuthorizeFGA.
  defp with_device_context(context, fun) do
    realm = Map.get(context, :realm_name)
    secret = Map.get(context, :device_secret)

    if is_nil(realm) or is_nil(secret) do
      {:error, "Unauthorized: Missing realm or device secret in context"}
    else
      fun.(realm, secret)
    end
  end

  defp format_device_response(hw_id, %Info.DeviceInfo{} = info) do
    %{
      hw_id: hw_id,
      info: %{
        version: info.version,
        status: info.status,
        protocols: info.protocols
      }
    }
  end
end
