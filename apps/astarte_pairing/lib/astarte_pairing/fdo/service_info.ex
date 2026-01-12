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
  import Astarte.Pairing.FDO.Types.ServiceInfo

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

  # Case when the device yielded during Owner Service Info chunk transmission
  # by sending an empty ServiceInfo map.
  def build_owner_service_info(
        realm_name,
        session,
        %DeviceServiceInfo{
          is_more_service_info: false,
          service_info: service_info
        }
      )
      when is_empty(service_info) do
    send_next_owner_chunk(session, realm_name)
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
    with {:ok, session} <-
           Session.add_device_service_info(session, realm_name, service_info) do
      encoded_device_id = generate_encoded_device_id(session.device_service_info)
      build_and_send_owner_service_info(session, realm_name, encoded_device_id)
    end
  end

  defp send_next_owner_chunk(session, realm_name) do
    with {:ok, _session, service_info_chunk} <-
           Session.next_owner_service_info_chunk(session, realm_name) do
      {:ok, service_info_chunk}
    end
  end

  defp generate_encoded_device_id(device_service_info) do
    device_service_info
    |> generate_device_id()
    |> Device.encode_device_id()
  end

  defp build_and_send_owner_service_info(session, realm_name, encoded_device_id) do
    with {:ok, credentials_secret} <-
           Engine.register_device(realm_name, encoded_device_id) do
      owner_service_info =
        OwnerServiceInfo.build(realm_name, credentials_secret, encoded_device_id)

      service_info_chunks =
        to_chunks(
          owner_service_info.service_info,
          session.max_owner_service_info_size
        )
        |> chunks_to_owner_service_info()

      {:ok, session} =
        Session.add_owner_service_info(
          session,
          realm_name,
          service_info_chunks
        )

      send_next_owner_chunk(session, realm_name)
    end
  end

  defp chunks_to_owner_service_info(chunks) do
    # SAFETY: we always have at least one service info message
    init_owner_service_info_length = Enum.count(chunks) - 1

    init_owner_service_info =
      Enum.map(1..init_owner_service_info_length//1, fn _ ->
        %OwnerServiceInfo{is_more_service_info: true, is_done: false, service_info: nil}
      end)

    last_owner_service_info = %OwnerServiceInfo{
      is_more_service_info: false,
      is_done: true,
      service_info: nil
    }

    owner_service_info = Enum.concat(init_owner_service_info, [last_owner_service_info])

    Enum.zip(owner_service_info, chunks)
    |> Enum.map(fn {owner_service_info, chunk} ->
      OwnerServiceInfo.encode_with_service_info_chunk(owner_service_info, chunk)
    end)
  end

  defp generate_device_id(%{{"devmod", "sn"} => %{value: sn}}), do: UUID.uuid5(:oid, sn, :raw)
  defp generate_device_id(_), do: Device.random_device_id()
end
