#
# This file is part of Astarte.
#
# Copyright 2017 - 2025 SECO Mind Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

defmodule Astarte.Pairing.Engine do
  @moduledoc """
  This module performs the pairing operations requested via RPC.
  """

  alias Astarte.Core.Device
  alias Astarte.Pairing.CertVerifier
  alias Astarte.Pairing.CFSSLCredentials
  alias Astarte.Pairing.Config
  alias Astarte.Pairing.CredentialsSecret
  alias Astarte.Pairing.Queries

  require Logger

  @version Mix.Project.config()[:version]

  defdelegate get_agent_public_key_pems(realm_name), to: Queries

  def get_credentials(
        :astarte_mqtt_v1,
        %{csr: csr},
        realm,
        hardware_id,
        credentials_secret,
        device_ip
      ) do
    Logger.debug(
      "get_credentials request for device #{inspect(hardware_id)} in realm #{inspect(realm)}"
    )

    :telemetry.execute([:astarte, :pairing, :get_credentials], %{}, %{realm: realm})

    with {:ok, device_id} <- Device.decode_device_id(hardware_id, allow_extended_id: true),
         {:ok, ip_tuple} <- parse_ip(device_ip),
         {:ok, device} <- Queries.fetch_device(realm, device_id),
         {:authorized?, true} <-
           {:authorized?, CredentialsSecret.verify(credentials_secret, device.credentials_secret)},
         {:credentials_inhibited?, false} <-
           {:credentials_inhibited?, device.inhibit_credentials_request},
         _ <- CFSSLCredentials.revoke(device.cert_serial, device.cert_aki),
         encoded_device_id <- Device.encode_device_id(device_id),
         {:ok, %{cert: cert, aki: _aki, serial: _serial} = cert_data} <-
           CFSSLCredentials.get_certificate(csr, realm, encoded_device_id),
         {:ok, _device} <-
           Queries.update_device_after_credentials_request(
             realm,
             device,
             cert_data,
             ip_tuple,
             device.first_credentials_request
           ) do
      {:ok, %{client_crt: cert}}
    else
      {:authorized?, false} ->
        {:error, :forbidden}

      {:credentials_inhibited?, true} ->
        {:error, :credentials_request_inhibited}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_credentials(
        protocol,
        credentials_params,
        _realm,
        _hw_id,
        _credentials_secret,
        _device_ip
      ) do
    Logger.warning(
      "get_credentials: unknown protocol #{inspect(protocol)} with params #{inspect(credentials_params)}"
    )

    {:error, :unknown_protocol}
  end

  def get_info(realm, hardware_id, credentials_secret) do
    Logger.debug("get_info request for device #{inspect(hardware_id)} in realm #{inspect(realm)}")

    with {:ok, device_id} <- Device.decode_device_id(hardware_id, allow_extended_id: true),
         {:ok, device} <- Queries.fetch_device(realm, device_id),
         {:authorized?, true} <-
           {:authorized?, CredentialsSecret.verify(credentials_secret, device.credentials_secret)} do
      device_status = device_status_string(device)
      protocols = get_protocol_info()

      {:ok, %{version: @version, device_status: device_status, protocols: protocols}}
    else
      {:authorized?, false} ->
        {:error, :forbidden}

      {:credentials_inhibited?, true} ->
        {:error, :credentials_request_inhibited}

      {:error, :shutdown} ->
        {:error, :realm_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def register_device(realm, hardware_id, opts \\ []) do
    Logger.debug(
      "register_device request for device #{inspect(hardware_id)} in realm #{inspect(realm)}"
    )

    :telemetry.execute([:astarte, :pairing, :register_new_device], %{}, %{realm: realm})

    with {:ok, device_id} <- Device.decode_device_id(hardware_id, allow_extended_id: true),
         :ok <- verify_can_register_device(realm, device_id),
         credentials_secret <- CredentialsSecret.generate(),
         secret_hash <- CredentialsSecret.hash(credentials_secret),
         {:ok, _device} <-
           Queries.register_device(realm, device_id, hardware_id, secret_hash, opts) do
      {:ok, credentials_secret}
    else
      {:error, :shutdown} ->
        {:error, :realm_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp verify_can_register_device(realm_name, device_id) do
    try do
      if Queries.check_already_registered_device(realm_name, device_id) do
        # An already existing device should always be able to retrieve a new credentials secret
        :ok
      else
        verify_can_register_new_device(realm_name)
      end
    rescue
      err ->
        # Consider a failing database as a negative answer
        _ =
          Logger.warning(
            "Failed to verify if unconfirmed device #{Device.encode_device_id(device_id)} exists, reason: #{Exception.message(err)}",
            realm: realm_name
          )

        verify_can_register_new_device(realm_name)
    end
  end

  defp verify_can_register_new_device(realm_name) do
    with {:ok, registration_limit} <- Queries.fetch_device_registration_limit(realm_name),
         {:ok, registered_devices_count} <- Queries.fetch_registered_devices_count(realm_name) do
      if registration_limit != nil and registered_devices_count >= registration_limit do
        _ =
          Logger.warning("Cannot register device: reached device registration limit",
            realm: realm_name,
            tag: "device_registration_limit_reached"
          )

        {:error, :device_registration_limit_reached}
      else
        :ok
      end
    end
  end

  def unregister_device(realm, encoded_device_id) do
    Logger.debug(
      "unregister_device request for device #{inspect(encoded_device_id)} " <>
        "in realm #{inspect(realm)}"
    )

    with {:ok, device_id} <- Device.decode_device_id(encoded_device_id),
         :ok <- Queries.unregister_device(realm, device_id) do
      :ok
    end
  end

  def verify_credentials(:astarte_mqtt_v1, %{client_crt: client_crt}, realm, hardware_id, secret) do
    Logger.debug(
      "verify_credentials request for device #{inspect(hardware_id)} in realm #{inspect(realm)}"
    )

    with {:ok, device_id} <- Device.decode_device_id(hardware_id, allow_extended_id: true),
         {:ok, device} <- Queries.fetch_device(realm, device_id),
         {:authorized?, true} <-
           {:authorized?, CredentialsSecret.verify(secret, device.credentials_secret)} do
      CertVerifier.verify(client_crt, Config.ca_cert!())
    else
      {:authorized?, false} ->
        {:error, :forbidden}

      {:credentials_inhibited?, true} ->
        {:error, :credentials_request_inhibited}

      {:error, :shutdown} ->
        {:error, :realm_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def verify_credentials(protocol, credentials_map, _realm, _hw_id, _secret) do
    Logger.warning(
      "verify_credentials: unknown protocol #{inspect(protocol)} with params #{inspect(credentials_map)}"
    )

    {:error, :unknown_protocol}
  end

  defp device_status_string(device) do
    # The device is pending until the first credendtial request
    cond do
      device.inhibit_credentials_request -> "inhibited"
      device.first_credentials_request -> "confirmed"
      true -> "pending"
    end
  end

  defp get_protocol_info do
    # TODO: this should be made modular when we support more protocols
    %{
      astarte_mqtt_v1: %{
        broker_url: Config.broker_url!()
      }
    }
  end

  defp parse_ip(ip_string) do
    case to_charlist(ip_string) |> :inet.parse_address() do
      {:ok, ip_tuple} -> {:ok, ip_tuple}
      {:error, _} -> {:error, :invalid_ip}
    end
  end
end
