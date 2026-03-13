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

defmodule Astarte.FDO.ServiceInfo do
  @moduledoc """
  Provides functions for building and handling ServiceInfo structures in the FDO protocol,
  including splitting large ServiceInfo maps into smaller chunks
  that fit within a specified maximum chunk size.
  This is used during the FDO onboarding process to ensure that ServiceInfo data
  can be transmitted in manageable pieces.
  """

  alias Astarte.FDO.Core.ServiceInfo

  alias Astarte.FDO.Core.OwnerOnboarding.DeviceServiceInfo
  alias Astarte.FDO.Core.OwnerOnboarding.OwnerServiceInfo
  alias Astarte.FDO.Core.OwnerOnboarding.Session

  import Astarte.FDO.Core.ServiceInfo

  # If device has more data to send, save received part to the session
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

  # Device has no more data to send, this function appends received part to the previous received
  # parts of service info and proceed sending OwnerService info
  def build_owner_service_info(
        realm_name,
        session,
        %DeviceServiceInfo{
          is_more_service_info: false,
          service_info: service_info
        },
        encoded_device_id,
        credentials_secret
      ) do
    with {:ok, session} <-
           Session.add_device_service_info(session, realm_name, service_info) do
      build_and_send_owner_service_info(
        session,
        realm_name,
        encoded_device_id,
        credentials_secret
      )
    end
  end

  defp send_next_owner_chunk(session, realm_name) do
    with {:ok, _session, service_info_chunk} <-
           Session.next_owner_service_info_chunk(session, realm_name) do
      {:ok, service_info_chunk}
    end
  end

  defp build_and_send_owner_service_info(
         session,
         realm_name,
         encoded_device_id,
         credentials_secret
       ) do
    owner_service_info =
      OwnerServiceInfo.build(realm_name, credentials_secret, encoded_device_id)

    service_info_chunks =
      ServiceInfo.to_chunks(
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
end
