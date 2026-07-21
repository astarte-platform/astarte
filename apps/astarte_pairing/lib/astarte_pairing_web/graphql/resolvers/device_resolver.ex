defmodule Astarte.PairingWeb.GraphQL.Resolvers.DeviceResolver do
  alias Astarte.Pairing.Info
  alias Astarte.Pairing.Credentials


  @doc """
  Retrieves device status information using the device credentials secret.
  """
  def get_device(_parent, %{hw_id: hw_id}, %{context: context}) do
    realm = Map.get(context, :realm_name)
    secret = Map.get(context, :device_secret)

    if is_nil(realm) or is_nil(secret) do
      {:error, "Unauthorized: Missing realm or device secret in context"}
    else
      case Info.get_device_info(realm, hw_id, secret) do
        {:ok, device_info} ->
          {:ok, format_device_response(hw_id, device_info)}

        {:error, reason} ->
          {:error, "Failed to retrieve the device: #{inspect(reason)}"}
      end
    end
  end


  @doc """
  Sends a CSR to the Astarte core to issue an MQTT client_crt.
  """
  def obtain_credentials(_parent, %{hw_id: hw_id, csr: csr}, %{context: context}) do
    realm = Map.get(context, :realm_name)
    secret = Map.get(context, :device_secret)
    device_ip = Map.get(context, :device_ip) || "127.0.0.1"

    if is_nil(realm) or is_nil(secret) do
      {:error, "Unauthorized: Missing realm or device secret in context"}
    else
      params = %{csr: csr}

      case Credentials.get_astarte_mqtt_v1(realm, hw_id, secret, device_ip, params) do
        {:ok, %{client_crt: client_crt}} ->
          {:ok, %{client_crt: client_crt}}

        {:error, reason} ->
          {:error, "Failed to generate the certificate: #{inspect(reason)}"}
      end
    end
  end

  @doc """
  Verifies the validity of a client_crt with the Astarte core.
  """
  def verify_credentials(_parent, %{hw_id: hw_id, client_crt: client_crt}, %{context: context}) do
    realm = Map.get(context, :realm_name)
    secret = Map.get(context, :device_secret)

    if is_nil(realm) or is_nil(secret) do
      {:error, "Unauthorized: Missing realm or device secret in context"}
    else
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
    end
  end

  defp format_device_response(hw_id, %Info.DeviceInfo{} = info) do
    %{
      id: hw_id,
      hw_id: hw_id,
      info: %{
        version: info.version,
        status: info.status,
        protocols: info.protocols
      }
    }
  end
end
