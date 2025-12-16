#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.Pairing.FDO.ServiceInfo do
  alias Astarte.Pairing.FDO.OwnerOnboarding.DeviceServiceInfo
  alias Astarte.Pairing.FDO.OwnerOnboarding.OwnerServiceInfo
  alias Astarte.Pairing.FDO.OwnerOnboarding.Session
  alias Astarte.Core.Device
  alias Astarte.Pairing.Engine

  # If device has more data to send, save recevied part to the session
  # and respond with empty OwnerService Info
  def build_owner_service_info(
        realm_name,
        session,
        %DeviceServiceInfo{
          is_more_service_info: true,
          service_info: service_info
        }
      ) do
    Session.add_device_service_info(session, realm_name, service_info)
    resp = OwnerServiceInfo.empty()
    {:ok, resp}
  end

  # Device has no more data to send, this function appends recevied part to the previous recevied
  # parts of service info and proceed sending OwnerService info
  def build_owner_service_info(
        realm_name,
        session,
        %DeviceServiceInfo{
          is_more_service_info: false,
          service_info: service_info
        }
      ) do
    # TODO: make use of other device service info
    {:ok, session} = Session.add_device_service_info(session, realm_name, service_info)

    encoded_device_id =
      session.device_service_info
      |> generate_device_id()
      |> Device.encode_device_id()

    with {:ok, credentials_secret} <- Engine.register_device(realm_name, encoded_device_id) do
      response =
        OwnerServiceInfo.build(realm_name, credentials_secret, encoded_device_id)
        |> OwnerServiceInfo.encode()

      {:ok, response}
    end
  end

  def build_owner_service_info(_realm_name, _session_key, _) do
    {:error, :message_body_error}
  end

  defp generate_device_id(%{{"devmod", "sn"} => %{value: sn}}), do: UUID.uuid5(:oid, sn, :raw)
  defp generate_device_id(_), do: Device.random_device_id()
end
